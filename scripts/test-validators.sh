#!/usr/bin/env bash

# Positive baselines plus one isolated negative fixture per semantic check.
# Ledger fixtures also prove distinct-cycle counting and promotion gating.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT/scripts/validate-workspace.sh"
FACTORY_VALIDATOR="$ROOT/scripts/validate-factory.sh"
LEDGER_TOOL="$ROOT/scripts/lessons-ledger.sh"
failures=0
runtime_test_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-factory-validator-tests.XXXXXX")"
trap 'rm -rf "$runtime_test_root"' EXIT

pass() { printf 'OK   %s\n' "$1"; }
fail() { printf 'FAIL %s\n' "$1" >&2; failures=$((failures + 1)); }

assert_contains() {
  local output="$1" marker="$2" label="$3"
  if printf '%s\n' "$output" | grep -Fq "$marker"; then
    pass "$label"
  else
    fail "$label (missing: $marker)"
  fi
}

assert_not_contains() {
  local output="$1" marker="$2" label="$3"
  if printf '%s\n' "$output" | grep -Fq "$marker"; then
    fail "$label (unexpected: $marker)"
  else
    pass "$label"
  fi
}

run_valid_workspace() {
  local ws="$1" output rc
  output="$(bash "$VALIDATOR" "$ws" 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "valid workspace passes: ${ws#$ROOT/}"
  else
    fail "valid workspace failed: ${ws#$ROOT/}"
    printf '%s\n' "$output" >&2
  fi
}

run_invalid_workspace() {
  local fixture="$1" marker="$2" ws="$ROOT/tests/fixtures/$fixture" output rc
  output="$(bash "$VALIDATOR" "$ws" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    pass "isolated fixture fails: $fixture"
  else
    fail "isolated fixture should fail: $fixture"
  fi
  assert_contains "$output" "$marker" "$fixture triggers its intended check"
}

run_valid_workspace "$ROOT/tests/fixtures/valid-no-local-skills"
run_valid_workspace "$ROOT/tests/fixtures/valid-web-workspace"
run_valid_workspace "$ROOT/tests/fixtures/valid-local-skill-no-research"
run_valid_workspace "$ROOT/tests/fixtures/valid-update-history"

for ws in "$ROOT"/examples/*/; do
  run_valid_workspace "$ws"
done

create_dynamic_workspace() {
  local name="$1"
  cp -R "$ROOT/tests/fixtures/valid-no-local-skills" "$runtime_test_root/$name"
}

run_dynamic_invalid() {
  local name="$1" marker="$2" label="$3" output rc
  output="$(bash "$VALIDATOR" "$runtime_test_root/$name" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then pass "$label fails"; else fail "$label should fail"; fi
  assert_contains "$output" "$marker" "$label triggers intended check"
}

create_dynamic_workspace missing-capability-coverage
dynamic_report="$runtime_test_root/missing-capability-coverage/reports/2026-07-10-081500-generation.md"
awk '
  /^## Copertura delle capacità$/ { skip = 1; next }
  skip && /^## / { skip = 0 }
  !skip { print }
' "$dynamic_report" > "$dynamic_report.tmp"
mv "$dynamic_report.tmp" "$dynamic_report"
run_dynamic_invalid missing-capability-coverage 'missing or empty capability coverage section' 'missing capability coverage'

create_dynamic_workspace validation-without-evidence
dynamic_report="$runtime_test_root/validation-without-evidence/reports/2026-07-10-081500-generation.md"
awk '
  /^## Validazione$/ { print; print ""; print "Validator eseguito."; skip = 1; next }
  skip && /^## / { skip = 0 }
  !skip { print }
' "$dynamic_report" > "$dynamic_report.tmp"
mv "$dynamic_report.tmp" "$dynamic_report"
run_dynamic_invalid validation-without-evidence 'validation section must record an exact command' 'validation without command or outcome'

create_dynamic_workspace dirty-without-provenance
dynamic_report="$runtime_test_root/dirty-without-provenance/reports/2026-07-10-081500-generation.md"
awk '{ sub(/Stato fabbrica: `clean`/, "Stato fabbrica: `dirty`"); print }' "$dynamic_report" > "$dynamic_report.tmp"
mv "$dynamic_report.tmp" "$dynamic_report"
run_dynamic_invalid dirty-without-provenance 'dirty factory status requires changed paths' 'incomplete dirty provenance'

create_dynamic_workspace impossible-timestamp
old_report="$runtime_test_root/impossible-timestamp/reports/2026-07-10-081500-generation.md"
dynamic_report="$runtime_test_root/impossible-timestamp/reports/2026-99-99-999999-generation.md"
awk '{ sub(/2026-07-10T08:15:00Z/, "2026-99-99T99:99:99Z"); print }' "$old_report" > "$dynamic_report"
rm "$old_report"
run_dynamic_invalid impossible-timestamp 'filename contains an impossible UTC date or time' 'impossible report timestamp'

create_dynamic_workspace external-relative-link
printf '# Outside workspace\n' > "$runtime_test_root/outside.md"
dynamic_report="$runtime_test_root/external-relative-link/reports/2026-07-10-081500-generation.md"
printf '\n[Documento esterno](../../outside.md)\n' >> "$dynamic_report"
run_dynamic_invalid external-relative-link 'workspace-external relative link' 'workspace-escaping relative link'

create_dynamic_workspace symlinked-workspace-file
ln -s README.md "$runtime_test_root/symlinked-workspace-file/README-link.md"
run_dynamic_invalid symlinked-workspace-file 'workspace contains symlink(s)' 'workspace symlink'

create_dynamic_workspace unsafe-api-ingestion
printf '\nIl task usa API fetch da un endpoint remoto.\n' >> "$runtime_test_root/unsafe-api-ingestion/README.md"
run_dynamic_invalid unsafe-api-ingestion 'must positively classify external content' 'unsafe external API ingestion'

duplicate_factory="$runtime_test_root/factory-duplicate-index"
cp -R "$ROOT" "$duplicate_factory"
printf '| `workspace-blueprint-minimal.md` | duplicate | duplicate regression row | test |\n' \
  >> "$duplicate_factory/skills/agent-workspace-builder/references/blueprint-index.md"
output="$(bash "$duplicate_factory/scripts/validate-factory.sh" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then pass 'factory validator rejects duplicate blueprint rows'; else fail 'duplicate blueprint row should fail'; fi
assert_contains "$output" 'blueprint index contains duplicate table rows' 'duplicate blueprint row triggers bijection check'

missing_factory="$runtime_test_root/factory-missing-index-row"
cp -R "$ROOT" "$missing_factory"
index_file="$missing_factory/skills/agent-workspace-builder/references/blueprint-index.md"
awk '!/`workspace-blueprint-automation-agent\.md`/' "$index_file" > "$index_file.tmp"
mv "$index_file.tmp" "$index_file"
output="$(bash "$missing_factory/scripts/validate-factory.sh" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then pass 'factory validator rejects missing blueprint rows'; else fail 'missing blueprint row should fail'; fi
assert_contains "$output" 'workspace-blueprint-automation-agent.md (found 0)' 'missing blueprint row triggers bijection check'

privacy_factory="$runtime_test_root/factory-privacy-leak"
cp -R "$ROOT" "$privacy_factory"
privacy_path_root='/''tmp'
privacy_key='api_''key'
privacy_value='embedded-''secret-123456'
printf '# Intentional dynamic regression\n\nPath: `%s/private-factory-data`\n\n%s=%s\n' \
  "$privacy_path_root" "$privacy_key" "$privacy_value" > "$privacy_factory/reports/privacy-regression.md"
output="$(bash "$privacy_factory/scripts/validate-factory.sh" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then pass 'factory validator rejects privacy leaks'; else fail 'factory privacy leak should fail'; fi
assert_contains "$output" 'factory contains persisted absolute project/data paths' 'factory path leak triggers privacy gate'
assert_contains "$output" 'factory contains possible secrets' 'factory secret leak triggers privacy gate'

negative_cases=(
  'invalid-setup|missing or empty optional setup section'
  'invalid-report|must contain Timestamp UTC'
  'invalid-reference|broken Markdown reference'
  'invalid-placeholder|unresolved template placeholder(s) found'
  'invalid-path|local absolute project/data path reference(s) found'
  'invalid-secret|possible secret pattern(s) found'
  'invalid-web-safety|must positively classify external content'
  'invalid-research|must document rejected options'
)

for case_spec in "${negative_cases[@]}"; do
  fixture="${case_spec%%|*}"
  marker="${case_spec#*|}"
  run_invalid_workspace "$fixture" "$marker"
done

valid_ledger="$ROOT/tests/fixtures/lesson-events-valid.tsv"
if bash "$LEDGER_TOOL" validate "$valid_ledger" >/dev/null 2>&1; then
  pass 'valid lesson ledger passes'
else
  fail 'valid lesson ledger should pass'
fi

summary="$(bash "$LEDGER_TOOL" summary "$valid_ledger" 2>&1)"
summary_rc=$?
if [ "$summary_rc" -eq 0 ]; then pass 'lesson ledger summary succeeds'; else fail 'lesson ledger summary failed'; fi
assert_contains "$summary" $'research\tnews-brief\t3\ttrue\ttrue\ttrue\ttrue\ttrue' 'summary deduplicates generation cycles and unlocks approved promotion'

eligible="$(bash "$LEDGER_TOOL" eligible "$valid_ledger" 2>&1)"
eligible_rc=$?
if [ "$eligible_rc" -eq 0 ]; then pass 'lesson ledger eligible succeeds'; else fail 'lesson ledger eligible failed'; fi
assert_contains "$eligible" $'research\tnews-brief\t3' 'eligible includes qualifying variant'
assert_not_contains "$eligible" $'minimal\tsimple-helper' 'eligible excludes below-threshold variant'

for spec in 'lesson-events-duplicate.tsv|duplicate event_id' 'lesson-events-invalid-enum.tsv|invalid event_kind'; do
  fixture="${spec%%|*}"
  marker="${spec#*|}"
  output="$(bash "$LEDGER_TOOL" validate "$ROOT/tests/fixtures/$fixture" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then pass "invalid ledger fails: $fixture"; else fail "invalid ledger should fail: $fixture"; fi
  assert_contains "$output" "$marker" "$fixture triggers intended ledger check"
done

append_test_root="$runtime_test_root/append-only"
mkdir -p "$append_test_root"

create_append_test_repo() {
  local name="$1"
  local repo="$append_test_root/$name"
  mkdir -p "$repo/scripts" "$repo/reports"
  cp "$LEDGER_TOOL" "$repo/scripts/lessons-ledger.sh"
  cp "$ROOT/reports/lesson-events.tsv" "$repo/reports/lesson-events.tsv"
  cp "$ROOT/reports/lessons.md" "$repo/reports/lessons.md"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.name 'agent-factory-tests'
  git -C "$repo" config user.email 'agent-factory-tests@example.invalid'
  git -C "$repo" add scripts/lessons-ledger.sh reports/lesson-events.tsv reports/lessons.md
  git -C "$repo" commit -q -m 'baseline'
}

create_append_test_repo valid-append
valid_append_repo="$append_test_root/valid-append"
printf '1\tevt-append-test\t2026-07-10\tcycle-append-test\tminimal\tappend-test\tgeneration\ttrue\tnone\n' >> "$valid_append_repo/reports/lesson-events.tsv"
printf '\n## 2026-07-10 — test append-only — tipo: minimal\n\n- Evento sintetico di regressione.\n' >> "$valid_append_repo/reports/lessons.md"
if bash "$valid_append_repo/scripts/lessons-ledger.sh" validate >/dev/null 2>&1; then
  pass 'append-only policy accepts new ledger rows and lesson sections'
else
  fail 'append-only policy rejected valid appended content'
fi

create_append_test_repo staged-ledger-rewrite
staged_ledger_repo="$append_test_root/staged-ledger-rewrite"
awk '{ sub(/research-local-directory/, "research-local-directorx"); print }' \
  "$staged_ledger_repo/reports/lesson-events.tsv" > "$staged_ledger_repo/reports/lesson-events.tsv.tmp"
mv "$staged_ledger_repo/reports/lesson-events.tsv.tmp" "$staged_ledger_repo/reports/lesson-events.tsv"
git -C "$staged_ledger_repo" add reports/lesson-events.tsv
output="$(bash "$staged_ledger_repo/scripts/lessons-ledger.sh" validate 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then pass 'append-only policy rejects staged ledger rewrites'; else fail 'staged ledger rewrite should fail'; fi
assert_contains "$output" 'Ledger is not append-only' 'staged ledger rewrite triggers append-only check'

create_append_test_repo staged-lessons-rewrite
staged_lessons_repo="$append_test_root/staged-lessons-rewrite"
awk 'NR == 1 { sub(/Registro lezioni/, "Registro riscritto") } { print }' \
  "$staged_lessons_repo/reports/lessons.md" > "$staged_lessons_repo/reports/lessons.md.tmp"
mv "$staged_lessons_repo/reports/lessons.md.tmp" "$staged_lessons_repo/reports/lessons.md"
git -C "$staged_lessons_repo" add reports/lessons.md
output="$(bash "$staged_lessons_repo/scripts/lessons-ledger.sh" validate 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then pass 'append-only policy rejects staged lesson rewrites'; else fail 'staged lessons rewrite should fail'; fi
assert_contains "$output" 'Lessons register is not append-only' 'staged lessons rewrite triggers append-only check'

create_append_test_repo multi-commit-rewrite
multi_commit_repo="$append_test_root/multi-commit-rewrite"
multi_commit_base="$(git -C "$multi_commit_repo" rev-parse HEAD)"
awk '{ sub(/research-local-directory/, "research-local-directorx"); print }' \
  "$multi_commit_repo/reports/lesson-events.tsv" > "$multi_commit_repo/reports/lesson-events.tsv.tmp"
mv "$multi_commit_repo/reports/lesson-events.tsv.tmp" "$multi_commit_repo/reports/lesson-events.tsv"
git -C "$multi_commit_repo" add reports/lesson-events.tsv
git -C "$multi_commit_repo" commit -q -m 'rewrite existing row'
printf '# unrelated follow-up\n' > "$multi_commit_repo/reports/unrelated.md"
git -C "$multi_commit_repo" add reports/unrelated.md
git -C "$multi_commit_repo" commit -q -m 'unrelated follow-up'
output="$(LESSONS_BASE_REF="$multi_commit_base" bash "$multi_commit_repo/scripts/lessons-ledger.sh" validate 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then pass 'append-only policy rejects rewrites hidden earlier in a commit range'; else fail 'multi-commit ledger rewrite should fail'; fi
assert_contains "$output" 'Ledger is not append-only' 'base-ref range validation catches earlier rewrites'

if [ "$failures" -ne 0 ]; then
  printf '\nValidator tests failed with %s issue(s).\n' "$failures" >&2
  exit 1
fi

printf '\nValidator tests passed.\n'
