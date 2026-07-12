from __future__ import annotations

import json
import os
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional


class StateError(RuntimeError):
    """Raised when persisted monitor state is invalid."""


class StateStore:
    def __init__(self, root: Path):
        self.root = root

    def _path(self, relative: str) -> Path:
        return self.root / relative

    def _relative(self, path: Path) -> str:
        return path.relative_to(self.root).as_posix()

    def _atomic_text(self, path: Path, text: str) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, temporary = tempfile.mkstemp(
            dir=path.parent, prefix=f".{path.name}.", text=True
        )
        try:
            with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
                handle.write(text)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, path)
        finally:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass

    def write_json(self, relative: str, value: dict[str, Any]) -> str:
        path = self._path(relative)
        self._atomic_text(
            path,
            json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
        )
        return self._relative(path)

    def read_json(self, relative: str) -> Optional[Dict[str, Any]]:
        path = self._path(relative)
        if not path.exists():
            return None
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            raise StateError(f"invalid state file: {relative}") from exc
        if not isinstance(value, dict):
            raise StateError(f"state file is not an object: {relative}")
        return value

    def append_log(self, event: dict[str, Any]) -> None:
        path = self._path("logs/events.jsonl")
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(event, sort_keys=True, ensure_ascii=False) + "\n")
            handle.flush()
            os.fsync(handle.fileno())

    def save_snapshot(self, target_id: str, name: str, content: str) -> str:
        path = self._path(f"snapshots/{target_id}/{name}.txt")
        self._atomic_text(path, content)
        return self._relative(path)

    def save_diff(self, change_id: str, content: str) -> str:
        path = self._path(f"diffs/{change_id}.diff")
        self._atomic_text(path, content)
        return self._relative(path)

    def read_text(self, relative: str) -> str:
        try:
            return self._path(relative).read_text(encoding="utf-8")
        except OSError as exc:
            raise StateError(f"cannot read state file: {relative}") from exc

    def target_metadata(self, target_id: str) -> Optional[Dict[str, Any]]:
        return self.read_json(f"metadata/{target_id}.json")

    def save_target_metadata(self, target_id: str, value: dict[str, Any]) -> str:
        return self.write_json(f"metadata/{target_id}.json", value)

    def cadence(self) -> Optional[Dict[str, Any]]:
        return self.read_json("cadence.json")

    def save_cadence(self, value: dict[str, Any]) -> str:
        return self.write_json("cadence.json", value)

    def enqueue(self, change_id: str, value: dict[str, Any]) -> str:
        return self.write_json(f"pending/{change_id}.json", value)

    def pending(self) -> List[Dict[str, Any]]:
        directory = self._path("pending")
        if not directory.exists():
            return []
        items: List[Dict[str, Any]] = []
        for path in sorted(directory.glob("*.json")):
            value = self.read_json(self._relative(path))
            if value is not None:
                items.append(value)
        return items

    def approve(self, change_id: str, approved_at: datetime) -> dict[str, Any]:
        pending_path = self._path(f"pending/{change_id}.json")
        value = self.read_json(f"pending/{change_id}.json")
        if value is None:
            raise StateError(f"pending change not found: {change_id}")
        if value.get("id") != change_id or value.get("status") != "pending":
            raise StateError(f"invalid pending change: {change_id}")

        approved = {
            **value,
            "status": "approved",
            "approved_at": approved_at.isoformat().replace("+00:00", "Z"),
            "delivery": "local_outbox",
        }
        self.write_json(f"approved/{change_id}.json", approved)
        self.write_json(f"outbox/{change_id}.json", approved)
        pending_path.unlink()
        return approved
