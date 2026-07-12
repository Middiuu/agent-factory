#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v python3 >/dev/null 2>&1; then
  printf 'FAIL python3 is required to build eval artifacts.\n' >&2
  exit 1
fi

python3 "$ROOT/scripts/build-eval-artifacts.py" --root "$ROOT" "$@"
