import contextlib
import importlib.util
import io
import json
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "monitor.py"
SPEC = importlib.util.spec_from_file_location("weekly_web_monitor", SCRIPT)
assert SPEC and SPEC.loader
monitor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(monitor)


class FixtureHandler(BaseHTTPRequestHandler):
    body = b"<html><body><h1>Version one</h1></body></html>"
    content_type = "text/html; charset=utf-8"

    def do_GET(self):
        if self.path != "/page":
            self.send_response(404)
            self.end_headers()
            return
        self.send_response(200)
        self.send_header("Content-Type", self.content_type)
        self.send_header("Content-Length", str(len(self.body)))
        self.end_headers()
        self.wfile.write(self.body)

    def log_message(self, format, *args):
        del format, args


class MonitorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.thread.join(timeout=5)
        cls.server.server_close()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.workspace = Path(self.temp.name)
        (self.workspace / "config").mkdir()
        (self.workspace / "reports").mkdir()
        url = "http://127.0.0.1:{}/page".format(self.server.server_port)
        (self.workspace / "config" / "targets.tsv").write_text("fixture\t{}\n".format(url), encoding="utf-8")
        FixtureHandler.body = b"<html><body><h1>Version one</h1></body></html>"

    def tearDown(self):
        self.temp.cleanup()

    def run_main(self, arguments):
        stdout = io.StringIO()
        stderr = io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            code = monitor.main(arguments)
        return code, stdout.getvalue(), stderr.getvalue()

    def check(self, timestamp):
        return self.run_main(
            [
                "check",
                "--workspace",
                str(self.workspace),
                "--now",
                timestamp,
            ]
        )

    def target_log(self, run_id):
        return json.loads((self.workspace / "reports" / "runs" / (run_id + "-fixture.json")).read_text(encoding="utf-8"))

    def test_classification_diff_and_human_gate(self):
        code, _, _ = self.check("2026-07-01T09:00:00Z")
        self.assertEqual(code, 0)
        initial = self.target_log("20260701T090000Z")
        self.assertEqual(initial["classification"], "initial")
        self.assertIsNone(initial["baseline_run_id"])
        self.assertEqual(list((self.workspace / "reports" / "pending").glob("*.md")), [])

        FixtureHandler.body = b"<html><body><div><strong>Version one</strong></div></body></html>"
        code, _, _ = self.check("2026-07-08T09:00:00Z")
        self.assertEqual(code, 0)
        technical = self.target_log("20260708T090000Z")
        self.assertEqual(technical["classification"], "technical")
        self.assertEqual(technical["baseline_run_id"], "20260701T090000Z")
        self.assertFalse((self.workspace / "reports" / "pending" / "20260708T090000Z.md").exists())

        FixtureHandler.body = b"<html><body><h1>Version two is live</h1></body></html>"
        code, _, _ = self.check("2026-07-15T09:00:00Z")
        self.assertEqual(code, 0)
        changed = self.target_log("20260715T090000Z")
        self.assertEqual(changed["classification"], "significant")
        self.assertEqual(changed["baseline_run_id"], "20260708T090000Z")
        self.assertTrue((self.workspace / changed["diff"]).is_file())
        self.assertTrue((self.workspace / "reports" / "pending" / "20260715T090000Z.md").is_file())
        self.assertFalse((self.workspace / "reports" / "approvals" / "20260715T090000Z.json").exists())

        wrong, _, _ = self.run_main(
            [
                "approve",
                "--workspace",
                str(self.workspace),
                "--run-id",
                "20260715T090000Z",
                "--confirmed-by",
                "test-user",
                "--destination",
                "test-channel",
                "--confirm",
                "NO",
                "--now",
                "2026-07-15T09:05:00Z",
            ]
        )
        self.assertEqual(wrong, 2)
        self.assertFalse((self.workspace / "reports" / "approvals" / "20260715T090000Z.json").exists())

        approved, _, _ = self.run_main(
            [
                "approve",
                "--workspace",
                str(self.workspace),
                "--run-id",
                "20260715T090000Z",
                "--confirmed-by",
                "test-user",
                "--destination",
                "test-channel",
                "--confirm",
                "INVIA",
                "--now",
                "2026-07-15T09:05:00Z",
            ]
        )
        self.assertEqual(approved, 0)
        approval = json.loads(
            (self.workspace / "reports" / "approvals" / "20260715T090000Z.json").read_text(encoding="utf-8")
        )
        self.assertEqual(approval["scope"], "single_run_single_destination")

        recorded, _, _ = self.run_main(
            [
                "record-notification",
                "--workspace",
                str(self.workspace),
                "--run-id",
                "20260715T090000Z",
                "--result",
                "sent",
                "--provider",
                "fixture-provider",
                "--receipt",
                "fixture-receipt",
                "--now",
                "2026-07-15T09:06:00Z",
            ]
        )
        self.assertEqual(recorded, 0)
        self.assertTrue((self.workspace / "reports" / "notifications" / "20260715T090000Z.json").is_file())

    def test_weekly_interval_is_logged_and_enforced(self):
        code, _, _ = self.check("2026-07-01T09:00:00Z")
        self.assertEqual(code, 0)
        code, _, stderr = self.check("2026-07-07T09:00:00Z")
        self.assertEqual(code, 3)
        self.assertIn("weekly_interval_not_elapsed", stderr)
        skipped = json.loads(
            (self.workspace / "reports" / "runs" / "20260707T090000Z-skipped.json").read_text(encoding="utf-8")
        )
        self.assertEqual(skipped["status"], "skipped")

    def test_secret_bearing_url_is_rejected(self):
        (self.workspace / "config" / "targets.tsv").write_text(
            "unsafe\thttps://example.test/path?api_key=x\n", encoding="utf-8"
        )
        code, _, stderr = self.check("2026-07-01T09:00:00Z")
        self.assertEqual(code, 2)
        self.assertIn("potenzialmente segreto", stderr)


if __name__ == "__main__":
    unittest.main()
