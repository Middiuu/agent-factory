#!/usr/bin/env bash

# Validate repository-local Markdown links without fetching external URLs.

set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'FAIL python3 is required to validate Markdown links.\n' >&2
  exit 1
fi

python3 "$ROOT/scripts/check-repo-links.py" "$ROOT"
