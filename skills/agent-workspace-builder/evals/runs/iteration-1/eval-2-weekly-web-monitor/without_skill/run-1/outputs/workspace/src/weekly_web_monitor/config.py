from __future__ import annotations

import json
import re
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlsplit


TARGET_ID = re.compile(r"^[a-z0-9][a-z0-9_-]{0,63}$")


class ConfigError(ValueError):
    """Raised when configuration is missing or unsafe."""


@dataclass(frozen=True)
class Target:
    id: str
    url: str


@dataclass(frozen=True)
class Settings:
    interval_days: int
    timeout_seconds: float
    max_response_bytes: int
    user_agent: str
    targets: tuple[Target, ...]


def _integer(value: object, name: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ConfigError(f"{name} must be an integer")
    return value


def load_settings(path: Path) -> Settings:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ConfigError(f"configuration not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ConfigError(f"invalid JSON in {path}: {exc}") from exc

    if not isinstance(raw, dict):
        raise ConfigError("configuration root must be an object")

    interval_days = _integer(raw.get("interval_days", 7), "interval_days")
    if interval_days < 7:
        raise ConfigError("interval_days must be at least 7")

    timeout = raw.get("timeout_seconds", 20)
    if isinstance(timeout, bool) or not isinstance(timeout, (int, float)):
        raise ConfigError("timeout_seconds must be a number")
    if not 1 <= float(timeout) <= 120:
        raise ConfigError("timeout_seconds must be between 1 and 120")

    max_bytes = _integer(raw.get("max_response_bytes", 2_097_152), "max_response_bytes")
    if not 1024 <= max_bytes <= 10_485_760:
        raise ConfigError("max_response_bytes must be between 1024 and 10485760")

    user_agent = raw.get("user_agent", "weekly-web-monitor/0.1")
    if not isinstance(user_agent, str) or not user_agent.strip() or len(user_agent) > 200:
        raise ConfigError("user_agent must be a non-empty string up to 200 characters")

    target_items = raw.get("targets")
    if not isinstance(target_items, list) or not target_items:
        raise ConfigError("targets must be a non-empty array")

    targets: list[Target] = []
    seen: set[str] = set()
    for index, item in enumerate(target_items):
        if not isinstance(item, dict):
            raise ConfigError(f"targets[{index}] must be an object")
        target_id = item.get("id")
        url = item.get("url")
        if not isinstance(target_id, str) or not TARGET_ID.fullmatch(target_id):
            raise ConfigError(
                f"targets[{index}].id must match {TARGET_ID.pattern}"
            )
        if target_id in seen:
            raise ConfigError(f"duplicate target id: {target_id}")
        if not isinstance(url, str):
            raise ConfigError(f"targets[{index}].url must be a string")
        parsed = urlsplit(url)
        if parsed.scheme not in {"http", "https"} or not parsed.hostname:
            raise ConfigError(f"targets[{index}].url must be an http(s) URL")
        if parsed.username or parsed.password:
            raise ConfigError(f"targets[{index}].url must not contain credentials")
        seen.add(target_id)
        targets.append(Target(id=target_id, url=url))

    return Settings(
        interval_days=interval_days,
        timeout_seconds=float(timeout),
        max_response_bytes=max_bytes,
        user_agent=user_agent.strip(),
        targets=tuple(targets),
    )
