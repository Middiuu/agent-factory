from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import List, Optional

from .config import ConfigError, load_settings
from .monitor import confirm_change, is_due, next_due, run_monitor
from .store import StateError, StateStore


def _store(value: str) -> StateStore:
    return StateStore(Path(value))


def _print(value: object) -> None:
    print(json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="weekly-web-monitor",
        description="Weekly web monitor with approval-gated local notifications.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    run = subparsers.add_parser("run", help="run checks if the weekly cadence is due")
    run.add_argument("--config", required=True, help="path to the JSON configuration")
    run.add_argument("--state-dir", default=".monitor-state")
    run.add_argument(
        "--force",
        action="store_true",
        help="manual override of the due check; does not install a scheduler",
    )

    due = subparsers.add_parser("due", help="show whether a run is currently due")
    due.add_argument("--config", required=True)
    due.add_argument("--state-dir", default=".monitor-state")

    pending = subparsers.add_parser("pending", help="list unapproved changes")
    pending.add_argument("--state-dir", default=".monitor-state")

    confirm = subparsers.add_parser(
        "confirm", help="approve one change for the local outbox"
    )
    confirm.add_argument("change_id")
    confirm.add_argument(
        "--approve",
        required=True,
        help="repeat the exact change id to make approval explicit",
    )
    confirm.add_argument("--state-dir", default=".monitor-state")
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "run":
            settings = load_settings(Path(args.config))
            result = run_monitor(settings, _store(args.state_dir), force=args.force)
            _print(result.__dict__)
            return 1 if result.errors else 0

        if args.command == "due":
            settings = load_settings(Path(args.config))
            store = _store(args.state_dir)
            now = datetime.now(timezone.utc)
            due_at = next_due(settings, store)
            _print(
                {
                    "due": is_due(settings, store, now),
                    "next_due_at": (
                        due_at.isoformat().replace("+00:00", "Z") if due_at else None
                    ),
                }
            )
            return 0

        if args.command == "pending":
            items = _store(args.state_dir).pending()
            _print({"count": len(items), "items": items})
            return 0

        if args.command == "confirm":
            approved = confirm_change(
                _store(args.state_dir), args.change_id, args.approve
            )
            _print(approved)
            return 0
    except (ConfigError, StateError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    return 2
