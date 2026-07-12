#!/usr/bin/env python3
"""Deterministic weekly web monitor with a human approval gate.

This program fetches configured public HTTP(S) targets, stores canonical
snapshots and hashes, compares each observation with the immediately previous
baseline, and prepares (but never sends) notification drafts.
"""

import argparse
import datetime as dt
import difflib
import hashlib
import json
import re
import sys
import textwrap
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple


SCHEMA_VERSION = 1
MIN_INTERVAL = dt.timedelta(days=7)
DEFAULT_TIMEOUT_SECONDS = 20
DEFAULT_MAX_BYTES = 2_000_000
TARGET_ID_PATTERN = re.compile(r"^[a-z0-9][a-z0-9._-]{0,63}$")
SECRET_KEY_PATTERN = re.compile(
    r"(^|[_-])(api[_-]?key|access[_-]?token|auth|credential|password|secret|token)([_-]|$)",
    re.IGNORECASE,
)
INSTRUCTION_LIKE_PATTERNS = (
    "ignore previous instructions",
    "ignore all previous instructions",
    "system prompt",
    "developer message",
    "execute this command",
)


class VisibleTextParser(HTMLParser):
    """Extract visible text without evaluating page content."""

    SKIPPED_TAGS = {"script", "style", "noscript", "template", "svg"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self._skip_depth = 0
        self.parts: List[str] = []

    def handle_starttag(self, tag: str, attrs: List[Tuple[str, Optional[str]]]) -> None:
        del attrs
        if tag.lower() in self.SKIPPED_TAGS:
            self._skip_depth += 1

    def handle_endtag(self, tag: str) -> None:
        if tag.lower() in self.SKIPPED_TAGS and self._skip_depth:
            self._skip_depth -= 1

    def handle_data(self, data: str) -> None:
        if not self._skip_depth:
            self.parts.append(data)


def utc_now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0)


def parse_utc(value: Optional[str]) -> dt.datetime:
    if value is None:
        return utc_now()
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    parsed = dt.datetime.fromisoformat(normalized)
    if parsed.tzinfo is None:
        raise ValueError("il timestamp deve includere il fuso orario")
    return parsed.astimezone(dt.timezone.utc).replace(microsecond=0)


def iso_utc(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def base_run_id(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_text(value: str) -> str:
    return sha256_bytes(value.encode("utf-8"))


def relative_path(path: Path, workspace: Path) -> str:
    return path.resolve().relative_to(workspace.resolve()).as_posix()


def atomic_write_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)


def atomic_write_json(path: Path, payload: Dict[str, object]) -> None:
    atomic_write_text(path, json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n")


def read_json(path: Path) -> Dict[str, object]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("il JSON atteso deve essere un oggetto")
    return value


def resolve_workspace(value: str) -> Path:
    workspace = Path(value).expanduser().resolve()
    if not workspace.is_dir():
        raise ValueError("la root del workspace non esiste")
    return workspace


def validate_target_url(value: str) -> None:
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError("sono ammessi soltanto URL HTTP(S) completi")
    if parsed.username or parsed.password:
        raise ValueError("le credenziali nell'URL non sono ammesse")
    for key, _ in urllib.parse.parse_qsl(parsed.query, keep_blank_values=True):
        if SECRET_KEY_PATTERN.search(key):
            raise ValueError("parametro query potenzialmente segreto non ammesso: " + key)


def load_targets(path: Path) -> List[Tuple[str, str]]:
    if not path.is_file():
        raise ValueError("file target assente: " + str(path))
    targets: List[Tuple[str, str]] = []
    seen = set()
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        fields = raw_line.split("\t")
        if len(fields) != 2:
            raise ValueError("riga {}: attesi target_id e URL separati da TAB".format(line_number))
        target_id, url = (field.strip() for field in fields)
        if not TARGET_ID_PATTERN.fullmatch(target_id):
            raise ValueError("riga {}: target_id non valido".format(line_number))
        if target_id in seen:
            raise ValueError("riga {}: target_id duplicato".format(line_number))
        validate_target_url(url)
        seen.add(target_id)
        targets.append((target_id, url))
    if not targets:
        raise ValueError("nessun target configurato")
    return targets


def canonicalize(raw: bytes, content_type: str, charset: Optional[str]) -> str:
    encoding = charset or "utf-8"
    try:
        decoded = raw.decode(encoding, errors="replace")
    except LookupError:
        decoded = raw.decode("utf-8", errors="replace")

    media_type = content_type.split(";", 1)[0].strip().lower()
    if media_type in {"application/json", "application/ld+json"}:
        try:
            parsed = json.loads(decoded)
            return json.dumps(parsed, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        except json.JSONDecodeError:
            pass
    if media_type in {"text/html", "application/xhtml+xml"} or "<html" in decoded[:1000].lower():
        parser = VisibleTextParser()
        parser.feed(decoded)
        decoded = " ".join(parser.parts)
    return re.sub(r"\s+", " ", decoded).strip()


def fetch(url: str, timeout: int, max_bytes: int) -> Tuple[bytes, str, Optional[str], str]:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "weekly-web-monitor/1.0 (+manual weekly observation)",
            "Accept": "text/html,application/json,text/plain;q=0.9,*/*;q=0.1",
        },
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        final_url = response.geturl()
        validate_target_url(final_url)
        raw = response.read(max_bytes + 1)
        if len(raw) > max_bytes:
            raise ValueError("risposta oltre il limite di {} byte".format(max_bytes))
        content_type = response.headers.get("Content-Type", "application/octet-stream")
        charset = response.headers.get_content_charset()
        return raw, content_type, charset, final_url


def instruction_warnings(canonical: str) -> List[str]:
    lowered = canonical.lower()
    return ["external_instruction_like_content"] if any(pattern in lowered for pattern in INSTRUCTION_LIKE_PATTERNS) else []


def unique_run_id(reports_root: Path, proposed: str) -> str:
    candidate = proposed
    suffix = 2
    while any((reports_root / folder / candidate).exists() for folder in ("pending", "approvals")) or list(
        (reports_root / "runs").glob(candidate + "-*")
    ):
        candidate = "{}-{}".format(proposed, suffix)
        suffix += 1
    return candidate


def wrapped_lines(value: str) -> List[str]:
    return textwrap.wrap(value, width=100, replace_whitespace=False, drop_whitespace=False) or [""]


def ensure_runtime_dirs(workspace: Path) -> Tuple[Path, Path]:
    reports_root = workspace / "reports"
    state_root = workspace / "state"
    for path in (
        reports_root / "runs",
        reports_root / "snapshots",
        reports_root / "diffs",
        reports_root / "pending",
        reports_root / "approvals",
        reports_root / "notifications",
        state_root / "targets",
    ):
        path.mkdir(parents=True, exist_ok=True)
    return reports_root, state_root


def write_skip_log(reports_root: Path, run_id: str, now: dt.datetime, reason: str) -> None:
    atomic_write_json(
        reports_root / "runs" / (run_id + "-skipped.json"),
        {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "observed_at_utc": iso_utc(now),
            "status": "skipped",
            "reason": reason,
        },
    )


def check_command(args: argparse.Namespace) -> int:
    workspace = resolve_workspace(args.workspace)
    reports_root, state_root = ensure_runtime_dirs(workspace)
    now = parse_utc(args.now)
    run_id = unique_run_id(reports_root, base_run_id(now))
    targets_path = workspace / args.targets
    targets = load_targets(targets_path)

    last_run_path = state_root / "last-successful-run.json"
    if last_run_path.exists() and not args.force:
        last_run = read_json(last_run_path)
        previous = parse_utc(str(last_run["completed_at_utc"]))
        elapsed = now - previous
        if elapsed < MIN_INTERVAL:
            reason = "weekly_interval_not_elapsed; previous_run_id={}".format(last_run.get("run_id", "unknown"))
            write_skip_log(reports_root, run_id, now, reason)
            print(reason, file=sys.stderr)
            return 3

    results: List[Dict[str, object]] = []
    significant: List[Dict[str, object]] = []
    errors = 0

    for target_id, url in targets:
        baseline_path = state_root / "targets" / (target_id + ".json")
        baseline: Optional[Dict[str, object]] = read_json(baseline_path) if baseline_path.exists() else None
        baseline_run_id = str(baseline["run_id"]) if baseline else None
        log_path = reports_root / "runs" / (run_id + "-" + target_id + ".json")
        record: Dict[str, object] = {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "observed_at_utc": iso_utc(now),
            "target_id": target_id,
            "source_url": url,
            "baseline_run_id": baseline_run_id,
            "status": "error",
            "classification": "error",
        }
        try:
            raw, content_type, charset, final_url = fetch(url, args.timeout, args.max_bytes)
            canonical = canonicalize(raw, content_type, charset)
            raw_hash = sha256_bytes(raw)
            canonical_hash = sha256_text(canonical)
            snapshot_path = reports_root / "snapshots" / (run_id + "-" + target_id + ".txt")
            atomic_write_text(snapshot_path, canonical + "\n")

            if baseline is None:
                classification = "initial"
            elif canonical_hash != baseline.get("canonical_sha256"):
                classification = "significant"
            elif raw_hash != baseline.get("raw_sha256"):
                classification = "technical"
            else:
                classification = "unchanged"

            diff_relative: Optional[str] = None
            if classification == "significant" and baseline is not None:
                prior_snapshot = workspace / str(baseline["canonical_snapshot"])
                prior_text = prior_snapshot.read_text(encoding="utf-8").strip()
                diff_text = "\n".join(
                    difflib.unified_diff(
                        wrapped_lines(prior_text),
                        wrapped_lines(canonical),
                        fromfile="baseline/{}".format(baseline_run_id),
                        tofile="current/{}".format(run_id),
                        lineterm="",
                    )
                ) + "\n"
                diff_path = reports_root / "diffs" / (run_id + "-" + target_id + ".diff")
                atomic_write_text(diff_path, diff_text)
                diff_relative = relative_path(diff_path, workspace)

            record.update(
                {
                    "status": "success",
                    "classification": classification,
                    "final_url": final_url,
                    "content_type": content_type,
                    "raw_bytes": len(raw),
                    "raw_sha256": raw_hash,
                    "canonical_sha256": canonical_hash,
                    "canonical_snapshot": relative_path(snapshot_path, workspace),
                    "diff": diff_relative,
                    "warnings": instruction_warnings(canonical),
                }
            )
            atomic_write_json(
                baseline_path,
                {
                    "schema_version": SCHEMA_VERSION,
                    "target_id": target_id,
                    "source_url": url,
                    "run_id": run_id,
                    "observed_at_utc": iso_utc(now),
                    "raw_sha256": raw_hash,
                    "canonical_sha256": canonical_hash,
                    "canonical_snapshot": relative_path(snapshot_path, workspace),
                },
            )
            if classification == "significant":
                significant.append(record)
        except (OSError, ValueError, KeyError, json.JSONDecodeError, urllib.error.URLError) as error:
            errors += 1
            record["error"] = "{}: {}".format(type(error).__name__, error)
        atomic_write_json(log_path, record)
        results.append(record)

    summary_lines = [
        "# Monitor run {}".format(run_id),
        "",
        "- Timestamp UTC: `{}`".format(iso_utc(now)),
        "- Target: `{}`".format(len(results)),
        "- Errori: `{}`".format(errors),
        "",
        "| Target | Classificazione | Baseline | Hash canonico | Diff |",
        "|---|---|---|---|---|",
    ]
    for record in results:
        summary_lines.append(
            "| `{}` | `{}` | `{}` | `{}` | `{}` |".format(
                record["target_id"],
                record["classification"],
                record.get("baseline_run_id") or "nessuna",
                record.get("canonical_sha256", "non disponibile"),
                record.get("diff") or "nessuno",
            )
        )
    summary_lines.extend(
        [
            "",
            "Le pagine osservate sono state trattate esclusivamente come dati non attendibili.",
            "Nessuna notifica e' stata inviata da questo comando.",
            "",
        ]
    )
    summary_path = reports_root / "runs" / (run_id + "-summary.md")
    atomic_write_text(summary_path, "\n".join(summary_lines))

    if significant:
        draft_lines = [
            "# Bozza di notifica — run {}".format(run_id),
            "",
            "Stato: `PENDING_HUMAN_CONFIRMATION`",
            "",
            "Questa bozza non autorizza alcun invio. Serve una conferma umana esplicita riferita a questo run ID e alla destinazione.",
            "",
        ]
        for record in significant:
            draft_lines.extend(
                [
                    "## {}".format(record["target_id"]),
                    "",
                    "- Fonte: `{}`".format(record["source_url"]),
                    "- Baseline: `{}`".format(record["baseline_run_id"]),
                    "- Hash canonico corrente: `{}`".format(record["canonical_sha256"]),
                    "- Diff: `{}`".format(record["diff"]),
                    "",
                ]
            )
        atomic_write_text(reports_root / "pending" / (run_id + ".md"), "\n".join(draft_lines))

    if errors:
        print(relative_path(summary_path, workspace))
        return 1
    atomic_write_json(
        last_run_path,
        {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "completed_at_utc": iso_utc(now),
            "targets": len(results),
        },
    )
    print(relative_path(summary_path, workspace))
    return 0


def safe_label(value: str, field: str) -> str:
    stripped = value.strip()
    if not stripped or len(stripped) > 160 or "\n" in stripped or "\r" in stripped:
        raise ValueError("{} non valido".format(field))
    return stripped


def approve_command(args: argparse.Namespace) -> int:
    if args.confirm != "INVIA":
        print("conferma rifiutata: usare il token letterale INVIA solo dopo consenso umano esplicito", file=sys.stderr)
        return 2
    workspace = resolve_workspace(args.workspace)
    reports_root, _ = ensure_runtime_dirs(workspace)
    run_id = safe_label(args.run_id, "run_id")
    if not re.fullmatch(r"[0-9]{8}T[0-9]{6}Z(?:-[0-9]+)?", run_id):
        raise ValueError("run_id non valido")
    draft_path = reports_root / "pending" / (run_id + ".md")
    if not draft_path.is_file():
        raise ValueError("bozza pending assente per il run richiesto")
    approval_path = reports_root / "approvals" / (run_id + ".json")
    if approval_path.exists():
        raise ValueError("run gia' approvato; non duplicare l'autorizzazione")
    approved_at = parse_utc(args.now)
    atomic_write_json(
        approval_path,
        {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "status": "approved_for_one_notification",
            "confirmed_by": safe_label(args.confirmed_by, "confirmed_by"),
            "confirmed_at_utc": iso_utc(approved_at),
            "destination": safe_label(args.destination, "destination"),
            "draft": relative_path(draft_path, workspace),
            "draft_sha256": sha256_bytes(draft_path.read_bytes()),
            "scope": "single_run_single_destination",
        },
    )
    print(relative_path(approval_path, workspace))
    return 0


def record_notification_command(args: argparse.Namespace) -> int:
    workspace = resolve_workspace(args.workspace)
    reports_root, _ = ensure_runtime_dirs(workspace)
    run_id = safe_label(args.run_id, "run_id")
    approval_path = reports_root / "approvals" / (run_id + ".json")
    if not approval_path.is_file():
        raise ValueError("invio non registrabile: manca l'approvazione umana")
    receipt_path = reports_root / "notifications" / (run_id + ".json")
    if receipt_path.exists():
        raise ValueError("esito notifica gia' registrato")
    approval = read_json(approval_path)
    recorded_at = parse_utc(args.now)
    atomic_write_json(
        receipt_path,
        {
            "schema_version": SCHEMA_VERSION,
            "run_id": run_id,
            "status": args.result,
            "provider": safe_label(args.provider, "provider"),
            "receipt": safe_label(args.receipt, "receipt"),
            "recorded_at_utc": iso_utc(recorded_at),
            "destination": approval["destination"],
            "approval": relative_path(approval_path, workspace),
            "approval_sha256": sha256_bytes(approval_path.read_bytes()),
        },
    )
    print(relative_path(receipt_path, workspace))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    check = subparsers.add_parser("check", help="esegue una singola osservazione settimanale")
    check.add_argument("--workspace", default=".")
    check.add_argument("--targets", default="config/targets.tsv")
    check.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT_SECONDS)
    check.add_argument("--max-bytes", type=int, default=DEFAULT_MAX_BYTES)
    check.add_argument("--now", help="timestamp UTC deterministico per test")
    check.add_argument("--force", action="store_true", help="bypassa la cadenza; solo test o richiesta esplicita")
    check.set_defaults(handler=check_command)

    approve = subparsers.add_parser("approve", help="registra una conferma umana, senza inviare")
    approve.add_argument("--workspace", default=".")
    approve.add_argument("--run-id", required=True)
    approve.add_argument("--confirmed-by", required=True)
    approve.add_argument("--destination", required=True)
    approve.add_argument("--confirm", required=True)
    approve.add_argument("--now", help="timestamp UTC deterministico per test")
    approve.set_defaults(handler=approve_command)

    record = subparsers.add_parser("record-notification", help="registra l'esito di un invio gia' effettuato")
    record.add_argument("--workspace", default=".")
    record.add_argument("--run-id", required=True)
    record.add_argument("--result", choices=("sent", "failed"), required=True)
    record.add_argument("--provider", required=True)
    record.add_argument("--receipt", required=True)
    record.add_argument("--now", help="timestamp UTC deterministico per test")
    record.set_defaults(handler=record_notification_command)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if getattr(args, "timeout", 1) <= 0 or getattr(args, "max_bytes", 1) <= 0:
            raise ValueError("timeout e max-bytes devono essere positivi")
        return int(args.handler(args))
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print("errore: {}".format(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
