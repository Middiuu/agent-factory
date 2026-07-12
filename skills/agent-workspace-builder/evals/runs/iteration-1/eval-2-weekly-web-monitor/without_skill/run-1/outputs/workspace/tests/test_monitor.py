from __future__ import annotations

import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

from weekly_web_monitor.config import ConfigError, Settings, Target, load_settings
from weekly_web_monitor.fetch import FetchResult
from weekly_web_monitor.monitor import confirm_change, is_due, run_monitor
from weekly_web_monitor.store import StateStore


NOW = datetime(2026, 1, 5, 9, 0, tzinfo=timezone.utc)


def settings() -> Settings:
    return Settings(
        interval_days=7,
        timeout_seconds=5,
        max_response_bytes=4096,
        user_agent="test-monitor",
        targets=(Target(id="docs", url="https://example.test/docs"),),
    )


class SequenceFetcher:
    def __init__(self, *bodies: str):
        self.bodies = list(bodies)

    def __call__(self, target: Target, config: Settings) -> FetchResult:
        return FetchResult(self.bodies.pop(0), 200, "text/html")


class MonitorTests(unittest.TestCase):
    def test_change_is_gated_until_exact_approval(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            store = StateStore(root)
            fetcher = SequenceFetcher("first\n", "second\n")

            initial = run_monitor(settings(), store, fetcher=fetcher, now=NOW)
            self.assertEqual(initial.status, "completed")
            self.assertEqual(store.pending(), [])
            self.assertFalse((root / "outbox").exists())

            changed = run_monitor(
                settings(),
                store,
                fetcher=fetcher,
                now=NOW + timedelta(days=7),
            )
            self.assertEqual(changed.changed, 1)
            pending = store.pending()
            self.assertEqual(len(pending), 1)
            change_id = pending[0]["id"]
            self.assertTrue((root / pending[0]["diff"]).exists())
            self.assertFalse((root / "outbox" / f"{change_id}.json").exists())

            with self.assertRaises(ValueError):
                confirm_change(store, change_id, "wrong", now=NOW + timedelta(days=7))
            self.assertFalse((root / "outbox" / f"{change_id}.json").exists())

            approved = confirm_change(
                store, change_id, change_id, now=NOW + timedelta(days=7)
            )
            self.assertEqual(approved["delivery"], "local_outbox")
            self.assertTrue((root / "outbox" / f"{change_id}.json").exists())
            self.assertEqual(store.pending(), [])

    def test_run_before_week_is_skipped_without_fetch(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory))
            fetcher = SequenceFetcher("baseline")
            run_monitor(settings(), store, fetcher=fetcher, now=NOW)
            result = run_monitor(
                settings(),
                store,
                fetcher=fetcher,
                now=NOW + timedelta(days=6, hours=23),
            )
            self.assertEqual(result.status, "skipped")
            self.assertEqual(fetcher.bodies, [])
            self.assertFalse(is_due(settings(), store, NOW + timedelta(days=6)))
            self.assertTrue(is_due(settings(), store, NOW + timedelta(days=7)))

    def test_failed_target_does_not_advance_cadence(self) -> None:
        def failing(target: Target, config: Settings) -> FetchResult:
            raise RuntimeError("offline")

        with tempfile.TemporaryDirectory() as directory:
            store = StateStore(Path(directory))
            result = run_monitor(settings(), store, fetcher=failing, now=NOW)
            self.assertEqual(result.status, "completed_with_errors")
            self.assertEqual(result.errors, 1)
            self.assertTrue(is_due(settings(), store, NOW + timedelta(minutes=1)))


class ConfigTests(unittest.TestCase):
    def _load(self, value: dict[str, object]) -> Settings:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "config.json"
            path.write_text(json.dumps(value), encoding="utf-8")
            return load_settings(path)

    def test_rejects_credentials_in_url(self) -> None:
        with self.assertRaises(ConfigError):
            self._load(
                {
                    "interval_days": 7,
                    "targets": [
                        {"id": "private", "url": "https://user:secret@example.test/"}
                    ],
                }
            )

    def test_rejects_subweekly_interval(self) -> None:
        with self.assertRaises(ConfigError):
            self._load(
                {
                    "interval_days": 6,
                    "targets": [{"id": "docs", "url": "https://example.test/"}],
                }
            )


if __name__ == "__main__":
    unittest.main()
