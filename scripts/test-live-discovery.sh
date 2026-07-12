#!/usr/bin/env bash

# Bounded live smoke test for registry drift. This complements, but never
# replaces, the deterministic discovery test suite used on every change.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISCOVER_TIMEOUT="${DISCOVER_TIMEOUT:-15}"
LIVE_DISCOVERY_QUERY="${LIVE_DISCOVERY_QUERY:-web}"
LIVE_DISCOVERY_MIN_REACHABLE="${LIVE_DISCOVERY_MIN_REACHABLE:-2}"

if ! printf '%s\n' "$LIVE_DISCOVERY_MIN_REACHABLE" | grep -Eq '^[1-9][0-9]*$'; then
  printf 'LIVE_DISCOVERY_MIN_REACHABLE must be a positive integer.\n' >&2
  exit 2
fi

output="$(
  DISCOVER_TIMEOUT="$DISCOVER_TIMEOUT" \
    bash "$ROOT/scripts/discover.sh" "$LIVE_DISCOVERY_QUERY" all 2>&1
)"
printf '%s\n' "$output"

reachable_sources="$(
  printf '%s\n' "$output" \
    | sed -n 's/^STATO FONTE: raggiungibile — //p' \
    | awk '
        $0 == "GitHub skill registry" ||
        $0 == "registry MCP ufficiale" ||
        $0 == "Homebrew" ||
        $0 == "npm registry" ||
        $0 == "PyPI" { seen[$0] = 1 }
        END { for (source in seen) print source }
      ' \
    | sort
)"
reachable_count="$(printf '%s\n' "$reachable_sources" | awk 'NF { count++ } END { print count + 0 }')"
for marker in \
  '## Skill registry' \
  '## Registry MCP ufficiale' \
  '## CLI e pacchetti' \
  'Promemoria:'; do
  if ! printf '%s\n' "$output" | grep -Fq "$marker"; then
    printf 'FAIL live discovery output is incomplete; missing: %s\n' "$marker" >&2
    exit 1
  fi
done

if [ "$reachable_count" -lt "$LIVE_DISCOVERY_MIN_REACHABLE" ]; then
  printf 'FAIL only %s source(s) were reachable; required at least %s.\n' \
    "$reachable_count" "$LIVE_DISCOVERY_MIN_REACHABLE" >&2
  exit 1
fi

printf '\nOK   live discovery reached %s source(s) (minimum: %s).\n' \
  "$reachable_count" "$LIVE_DISCOVERY_MIN_REACHABLE"
printf '%s\n' "$reachable_sources"
