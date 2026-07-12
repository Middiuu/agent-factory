#!/usr/bin/env python3
"""Check that local Markdown links stay inside the repository and resolve."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote


INLINE_LINK = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
REFERENCE_LINK = re.compile(r"^\s*\[[^\]]+\]:\s*(\S+)")
URI_SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")


def is_excluded(path: Path, root: Path) -> bool:
    relative = path.relative_to(root)
    parts = relative.parts
    if ".git" in parts:
        return True
    if len(parts) >= 3 and parts[:2] == ("tests", "fixtures"):
        return parts[2] == "broken-workspace" or parts[2].startswith("invalid-")
    return False


def markdown_text(path: Path) -> str:
    lines: list[str] = []
    in_fence = False
    fence = ""
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\s*(```+|~~~+)", line)
        if match:
            marker = match.group(1)[0]
            if not in_fence:
                in_fence = True
                fence = marker
            elif marker == fence:
                in_fence = False
                fence = ""
            continue
        if not in_fence:
            lines.append(line)
    return "\n".join(lines)


def normalize_target(raw: str) -> str:
    target = raw.strip()
    if target.startswith("<") and ">" in target:
        target = target[1 : target.index(">")]
    else:
        target = target.split(maxsplit=1)[0]
    return unquote(target)


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    failures: list[str] = []
    checked_links = 0
    markdown_files = 0

    for path in sorted(root.rglob("*.md")):
        if not path.is_file() or is_excluded(path, root):
            continue
        markdown_files += 1
        text = markdown_text(path)
        targets = [match.group(1) for match in INLINE_LINK.finditer(text)]
        targets.extend(
            match.group(1)
            for line in text.splitlines()
            if (match := REFERENCE_LINK.match(line))
        )

        for raw in targets:
            target = normalize_target(raw)
            if (
                not target
                or target.startswith("#")
                or target.startswith("//")
                or URI_SCHEME.match(target)
            ):
                continue

            local_part = target.split("#", 1)[0].split("?", 1)[0]
            if not local_part:
                continue
            checked_links += 1

            local_path = Path(local_part)
            if local_path.is_absolute():
                failures.append(
                    f"{path.relative_to(root)}: absolute local target is not allowed: {target}"
                )
                continue

            resolved = (path.parent / local_path).resolve()
            try:
                resolved.relative_to(root)
            except ValueError:
                failures.append(
                    f"{path.relative_to(root)}: target escapes repository: {target}"
                )
                continue

            if not resolved.exists():
                failures.append(
                    f"{path.relative_to(root)}: missing local target: {target}"
                )

    if failures:
        for failure in failures:
            print(f"FAIL {failure}", file=sys.stderr)
        print(f"\nMarkdown link validation failed with {len(failures)} issue(s).", file=sys.stderr)
        return 1

    print(
        f"OK   {checked_links} local Markdown link(s) resolve across "
        f"{markdown_files} checked file(s)."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
