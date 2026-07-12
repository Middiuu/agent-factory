from __future__ import annotations

import difflib
import hashlib
import uuid
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Callable, Dict, Optional

from .config import Settings, Target
from .fetch import FetchResult, fetch_url
from .store import StateStore


Fetcher = Callable[[Target, Settings], FetchResult]


@dataclass(frozen=True)
class RunResult:
    run_id: str
    status: str
    checked: int
    changed: int
    errors: int
    next_due_at: Optional[str]


def _iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _parse_utc(value: object) -> Optional[datetime]:
    if not isinstance(value, str):
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed.astimezone(timezone.utc)


def next_due(settings: Settings, store: StateStore) -> Optional[datetime]:
    cadence = store.cadence()
    if cadence is None:
        return None
    last_completed = _parse_utc(cadence.get("last_completed_at"))
    if last_completed is None:
        return None
    return last_completed + timedelta(days=settings.interval_days)


def is_due(settings: Settings, store: StateStore, now: datetime) -> bool:
    due_at = next_due(settings, store)
    return due_at is None or now.astimezone(timezone.utc) >= due_at


def run_monitor(
    settings: Settings,
    store: StateStore,
    *,
    fetcher: Fetcher = fetch_url,
    now: Optional[datetime] = None,
    force: bool = False,
) -> RunResult:
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    run_id = f"run-{current.strftime('%Y%m%dT%H%M%SZ')}-{uuid.uuid4().hex[:8]}"
    due_at = next_due(settings, store)
    if not force and due_at is not None and current < due_at:
        store.append_log(
            {
                "event": "run_skipped_not_due",
                "run_id": run_id,
                "at": _iso(current),
                "next_due_at": _iso(due_at),
            }
        )
        return RunResult(run_id, "skipped", 0, 0, 0, _iso(due_at))

    store.append_log({"event": "run_started", "run_id": run_id, "at": _iso(current)})
    checked = 0
    changed = 0
    errors = 0

    for target in settings.targets:
        try:
            result = fetcher(target, settings)
            digest = hashlib.sha256(result.text.encode("utf-8")).hexdigest()
            stamp = current.strftime("%Y%m%dT%H%M%SZ")
            snapshot_path = store.save_snapshot(
                target.id, f"{stamp}-{digest[:12]}", result.text
            )
            previous = store.target_metadata(target.id)
            checked += 1

            event_name = "target_initialized"
            change_id: Optional[str] = None
            if previous is not None and previous.get("sha256") != digest:
                old_snapshot = previous.get("snapshot")
                if not isinstance(old_snapshot, str):
                    raise ValueError("previous snapshot path is missing")
                old_text = store.read_text(old_snapshot)
                diff = "".join(
                    difflib.unified_diff(
                        old_text.splitlines(keepends=True),
                        result.text.splitlines(keepends=True),
                        fromfile=f"{target.id}:previous",
                        tofile=f"{target.id}:current",
                    )
                )
                change_id = f"{target.id}-{stamp}-{digest[:8]}"
                diff_path = store.save_diff(change_id, diff)
                store.enqueue(
                    change_id,
                    {
                        "id": change_id,
                        "status": "pending",
                        "created_at": _iso(current),
                        "target_id": target.id,
                        "url": target.url,
                        "summary": f"Content changed for {target.id}",
                        "previous_sha256": previous.get("sha256"),
                        "current_sha256": digest,
                        "previous_snapshot": old_snapshot,
                        "current_snapshot": snapshot_path,
                        "diff": diff_path,
                    },
                )
                event_name = "target_changed_pending_approval"
                changed += 1
            elif previous is not None:
                event_name = "target_unchanged"

            store.save_target_metadata(
                target.id,
                {
                    "target_id": target.id,
                    "url": target.url,
                    "sha256": digest,
                    "snapshot": snapshot_path,
                    "checked_at": _iso(current),
                    "http_status": result.status,
                    "content_type": result.content_type,
                },
            )
            event = {
                "event": event_name,
                "run_id": run_id,
                "at": _iso(current),
                "target_id": target.id,
                "sha256": digest,
                "snapshot": snapshot_path,
            }
            if change_id is not None:
                event["change_id"] = change_id
            store.append_log(event)
        except Exception as exc:  # target isolation is intentional
            errors += 1
            store.append_log(
                {
                    "event": "target_error",
                    "run_id": run_id,
                    "at": _iso(current),
                    "target_id": target.id,
                    "error_type": type(exc).__name__,
                    "error": str(exc),
                }
            )

    if errors == 0:
        due_at = current + timedelta(days=settings.interval_days)
        store.save_cadence(
            {
                "last_completed_at": _iso(current),
                "next_due_at": _iso(due_at),
                "interval_days": settings.interval_days,
            }
        )
    else:
        due_at = None

    status = "completed" if errors == 0 else "completed_with_errors"
    store.append_log(
        {
            "event": "run_finished",
            "run_id": run_id,
            "at": _iso(current),
            "status": status,
            "checked": checked,
            "changed": changed,
            "errors": errors,
            "next_due_at": _iso(due_at) if due_at else None,
        }
    )
    return RunResult(
        run_id,
        status,
        checked,
        changed,
        errors,
        _iso(due_at) if due_at else None,
    )


def confirm_change(
    store: StateStore,
    change_id: str,
    approval: str,
    *,
    now: Optional[datetime] = None,
) -> Dict[str, object]:
    if approval != change_id:
        raise ValueError("approval must exactly match the change id")
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    approved = store.approve(change_id, current)
    store.append_log(
        {
            "event": "notification_approved_to_local_outbox",
            "change_id": change_id,
            "at": _iso(current),
        }
    )
    return approved
