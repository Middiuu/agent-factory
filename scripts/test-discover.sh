#!/usr/bin/env bash

# Deterministic tests for discover.sh. All external commands are PATH-injected
# mocks; the suite never depends on network availability or public registries.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DISCOVER="$ROOT/scripts/discover.sh"
MOCK_BIN="$ROOT/tests/fixtures/discover-bin"
TEST_PATH="$MOCK_BIN:/usr/bin:/bin"
failures=0

pass() {
  printf 'OK   %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_contains() {
  local output="$1"
  local marker="$2"
  local label="$3"

  if printf '%s\n' "$output" | grep -Fq "$marker"; then
    pass "$label"
  else
    fail "$label (missing: $marker)"
  fi
}

assert_not_contains() {
  local output="$1"
  local marker="$2"
  local label="$3"

  if printf '%s\n' "$output" | grep -Fq "$marker"; then
    fail "$label (unexpected: $marker)"
  else
    pass "$label"
  fi
}

run_discovery() {
  local scenario="$1"
  local timeout_seconds="$2"
  shift 2

  PATH="$TEST_PATH" \
    MOCK_DISCOVER_SCENARIO="$scenario" \
    DISCOVER_FORCE_NO_JQ=1 \
    DISCOVER_TIMEOUT="$timeout_seconds" \
    bash "$DISCOVER" "$@"
}

success_output="$(run_discovery success 2 web all 2>&1)"
assert_contains "$success_output" 'STATO FONTE: raggiungibile — GitHub skill registry' "success marks skill registry reachable"
assert_contains "$success_output" 'STATO FONTE: raggiungibile — registry MCP ufficiale' "success marks MCP registry reachable"
assert_contains "$success_output" 'STATO FONTE: raggiungibile — npm registry' "success marks npm reachable"
assert_contains "$success_output" 'STATO FONTE: raggiungibile — PyPI' "success marks PyPI reachable"
assert_not_contains "$success_output" 'FONTE NON RAGGIUNGIBILE' "success has no unreachable source"

absent_output="$(run_discovery absent 2 missing cli 2>&1)"
assert_contains "$absent_output" 'PACCHETTO ASSENTE: npm — missing' "npm 404 is classified as absence"
assert_contains "$absent_output" 'PACCHETTO ASSENTE: PyPI — missing' "PyPI 404 is classified as absence"
assert_contains "$absent_output" 'NESSUN RISULTATO: Homebrew' "empty Homebrew response is classified as no result"
assert_not_contains "$absent_output" 'FONTE NON RAGGIUNGIBILE' "absence is not mislabeled as network failure"

network_output="$(run_discovery network 2 web all 2>&1)"
assert_contains "$network_output" 'FONTE NON RAGGIUNGIBILE: GitHub skill registry' "skill transport failure stays unreachable"
assert_contains "$network_output" 'FONTE NON RAGGIUNGIBILE: registry MCP ufficiale' "MCP transport failure stays unreachable"
assert_contains "$network_output" 'FONTE NON RAGGIUNGIBILE: npm registry' "npm network failure stays unreachable"
assert_contains "$network_output" 'FONTE NON RAGGIUNGIBILE: PyPI' "PyPI transport failure stays unreachable"
assert_not_contains "$network_output" 'PACCHETTO ASSENTE' "network failure is never reported as package absence"

encoded_output="$(run_discovery success 2 '@scope/pkg & tool' mcp 2>&1)"
assert_contains "$encoded_output" '%40scope%2Fpkg%20%26%20tool' "MCP query is URL encoded"

timeout_output="$(run_discovery timeout 3 web cli 2>&1)"
assert_contains "$timeout_output" 'FONTE NON RAGGIUNGIBILE: Homebrew (timeout dopo 3s)' "Homebrew timeout is explicit"
assert_contains "$timeout_output" 'FONTE NON RAGGIUNGIBILE: npm registry (timeout dopo 3s)' "npm timeout is explicit"
assert_contains "$timeout_output" 'FONTE NON RAGGIUNGIBILE: PyPI (timeout dopo 3s)' "curl timeout uses configured duration"

invalid_output="$(PATH="$TEST_PATH" DISCOVER_TIMEOUT=zero bash "$DISCOVER" web skill 2>&1)"
invalid_rc=$?
if [ "$invalid_rc" -eq 2 ]; then
  pass "invalid timeout exits 2"
else
  fail "invalid timeout should exit 2 (got $invalid_rc)"
fi
assert_contains "$invalid_output" 'DISCOVER_TIMEOUT deve essere un numero intero positivo' "invalid timeout has actionable error"

if [ "$failures" -ne 0 ]; then
  printf '\nDiscovery tests failed with %s issue(s).\n' "$failures" >&2
  exit 1
fi

printf '\nDiscovery tests passed.\n'
