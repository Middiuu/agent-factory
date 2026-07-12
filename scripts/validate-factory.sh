#!/usr/bin/env bash

# Validate the factory itself: required artifacts must be real and non-empty,
# shell entry points must parse, the blueprint index must be bijective, and CI
# must exercise validators, discovery mocks, and the lessons ledger.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failures=0

pass() {
  printf 'OK   %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1" >&2
  failures=$((failures + 1))
}

finish() {
  if [ "$failures" -ne 0 ]; then
    printf '\nValidation failed with %s issue(s).\n' "$failures" >&2
    exit 1
  fi

  printf '\nValidation passed.\n'
}

require_file() {
  local rel="$1"

  if [ -s "$ROOT/$rel" ]; then
    pass "$rel non-empty"
  elif [ -f "$ROOT/$rel" ]; then
    fail "$rel is empty"
  else
    fail "$rel missing"
  fi
}

require_dir() {
  local rel="$1"

  if [ -d "$ROOT/$rel" ]; then
    pass "$rel/"
  else
    fail "$rel/ missing"
  fi
}

frontmatter_block() {
  local file="$1"

  awk '
    NR == 1 {
      if ($0 != "---") {
        exit 1
      }
      next
    }
    /^---$/ {
      found = 1
      exit 0
    }
    {
      print
    }
    END {
      if (!found) {
        exit 2
      }
    }
  ' "$file"
}

check_skill_frontmatter() {
  local file="$1"
  local rel="${file#$ROOT/}"
  local frontmatter

  if ! frontmatter="$(frontmatter_block "$file")"; then
    fail "$rel frontmatter must start and end with ---"
    return
  fi

  if printf '%s\n' "$frontmatter" | grep -Eq '^name:[[:space:]]*[a-z0-9]+([_-][a-z0-9]+)*[[:space:]]*$'; then
    pass "$rel name frontmatter"
  else
    fail "$rel missing or invalid lowercase slug frontmatter name"
  fi

  if printf '%s\n' "$frontmatter" | grep -Eq '^description:[[:space:]]*(.+|[|>]-?)[[:space:]]*$'; then
    pass "$rel description frontmatter"
  else
    fail "$rel missing frontmatter description"
  fi
}

check_shell_scripts() {
  local script
  local count=0
  local here_string_hits
  local here_string_pattern='<<'

  here_string_pattern="${here_string_pattern}<"

  while IFS= read -r -d '' script; do
    count=$((count + 1))
    if [ ! -s "$script" ]; then
      fail "${script#$ROOT/} is empty"
    elif bash -n "$script"; then
      pass "${script#$ROOT/} passes bash -n"
    else
      fail "${script#$ROOT/} fails bash -n"
    fi
  done < <(find "$ROOT/scripts" -maxdepth 1 -type f -name '*.sh' -print0)

  if [ "$count" -eq 0 ]; then
    fail "no scripts/*.sh files found"
  fi

  here_string_hits="$(grep -RInF --include='*.sh' "$here_string_pattern" "$ROOT/scripts" 2>/dev/null || true)"
  if [ "$here_string_hits" = "" ]; then
    pass "scripts avoid here-strings"
  else
    fail "scripts contain here-strings, which can require forbidden temporary files"
    printf '%s\n' "$here_string_hits" >&2
  fi
}

# References in the main skill are executable dependencies of the procedure.
# references/ resolve from the skill directory; templates/ and scripts/ from root.
check_skill_doc_references() {
  local skill_md="$ROOT/skills/agent-workspace-builder/SKILL.md"
  local skill_dir="$ROOT/skills/agent-workspace-builder"
  local ref
  local base

  [ -s "$skill_md" ] || return

  while IFS= read -r ref; do
    [ "$ref" = "" ] && continue
    case "$ref" in
      references/*) base="$skill_dir" ;;
      *) base="$ROOT" ;;
    esac

    if [ -s "$base/$ref" ]; then
      pass "SKILL.md reference is non-empty: $ref"
    elif [ -e "$base/$ref" ]; then
      fail "SKILL.md references empty file: $ref"
    else
      fail "SKILL.md references missing file: $ref"
    fi
  done < <(grep -oE '(references|templates|scripts)/[A-Za-z0-9._-]+\.(md|sh)' "$skill_md" | sort -u)
}

check_blueprint_index() {
  local refs_dir="$ROOT/skills/agent-workspace-builder/references"
  local index="$refs_dir/blueprint-index.md"
  local file
  local name
  local occurrences
  local index_names
  local duplicate_names
  local count=0
  local indexed_count=0

  if [ ! -s "$index" ]; then
    fail "references/blueprint-index.md missing or empty"
    return
  fi
  pass "references/blueprint-index.md non-empty"

  index_names="$(awk -F '|' '
    /^\|[[:space:]]*`workspace-blueprint-[A-Za-z0-9-]+\.md`[[:space:]]*\|/ {
      name = $2
      gsub(/^[[:space:]]*`|`[[:space:]]*$/, "", name)
      print name
    }
  ' "$index")"
  indexed_count="$(printf '%s\n' "$index_names" | awk 'NF { count++ } END { print count + 0 }')"
  duplicate_names="$(printf '%s\n' "$index_names" | awk 'NF' | sort | uniq -d)"
  if [ "$duplicate_names" = "" ]; then
    pass "blueprint index has no duplicate table rows"
  else
    fail "blueprint index contains duplicate table rows"
    printf '%s\n' "$duplicate_names" >&2
  fi

  while IFS= read -r -d '' file; do
    count=$((count + 1))
    name="$(basename "$file")"

    if [ ! -s "$file" ]; then
      fail "blueprint is empty: $name"
      continue
    fi
    if ! grep -Eq '^#[[:space:]]+.+' "$file"; then
      fail "blueprint has no title heading: $name"
    else
      pass "blueprint non-empty with title: $name"
    fi

    occurrences="$(printf '%s\n' "$index_names" | grep -Fxc "$name" || true)"
    if [ "$occurrences" -eq 1 ]; then
      pass "blueprint has exactly one index table row: $name"
    else
      fail "blueprint must have exactly one index table row: $name (found $occurrences)"
    fi
  done < <(find "$refs_dir" -maxdepth 1 -type f -name 'workspace-blueprint-*.md' -print0)

  if [ "$count" -eq 0 ]; then
    fail "no workspace blueprint files found"
  fi

  if [ -s "$refs_dir/workspace-blueprint-minimal.md" ]; then
    pass "fallback blueprint workspace-blueprint-minimal.md is non-empty"
  else
    fail "fallback blueprint workspace-blueprint-minimal.md missing or empty"
  fi

  if [ "$indexed_count" -eq "$count" ]; then
    pass "blueprint index and filesystem counts match ($count)"
  else
    fail "blueprint index has $indexed_count table rows for $count blueprint files"
  fi

  while IFS= read -r name; do
    [ "$name" = "" ] && continue
    if [ -s "$refs_dir/$name" ]; then
      pass "indexed blueprint exists and is non-empty: $name"
    elif [ -e "$refs_dir/$name" ]; then
      fail "blueprint-index.md lists empty file: $name"
    else
      fail "blueprint-index.md lists missing file: $name"
    fi
  done < <(printf '%s\n' "$index_names" | awk 'NF' | sort -u)
}

factory_candidate_is_placeholder() {
  local candidate="$1"
  local assignment_key='(api[_-]?key|client[_-]?secret|access[_-]?token|auth[_-]?token|password|passwd|secret|token)'
  local placeholder_value

  placeholder_value="${assignment_key}[[:space:]]*[:=][[:space:]]*[\"']?(\\\$\\{[^}]+\\}|\\\$[A-Za-z_][A-Za-z0-9_]*|<[A-Za-z0-9_ -]+>|\\{\\{[^}]+\\}\\}|REPLACE_ME|CHANGE_ME|your[-_ ]?(api[-_ ]?)?key|placeholder|example|dummy|fake|redacted|not[-_ ]?set|none|null)[\"']?([[:space:],;#]|$)"
  printf '%s\n' "$candidate" | grep -Eiq "$placeholder_value"
}

check_factory_privacy() {
  local file
  local path_hits=""
  local secret_hits=""
  local hits
  local candidate
  local unix_pattern="(^|[[:space:]\`\"'(=])(/[A-Za-z0-9._~{}$-]+){2,}"
  local windows_pattern="(^|[^A-Za-z0-9])([A-Za-z]:[\\/][^[:space:]\`\"']+|\\\\[A-Za-z0-9._-]+[\\/][A-Za-z0-9.$_-]+)"
  local assignment_pattern="(api[_-]?key|client[_-]?secret|access[_-]?token|auth[_-]?token|password|passwd|secret|token)[[:space:]]*[:=][[:space:]]*(\"[^\"]{8,}\"|'[^']{8,}'|[^[:space:]\`\"']{8,})"
  local token_pattern='(github_pat_[A-Za-z0-9_]{20,255}|gh[pousr]_[A-Za-z0-9]{20,255}|glpat-[A-Za-z0-9_-]{20,255}|sk-ant-[A-Za-z0-9_-]{20,255}|sk-(proj-)?[A-Za-z0-9_-]{20,255}|xox[baprs]-[A-Za-z0-9-]{10,255}|(AKIA|ASIA)[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|npm_[A-Za-z0-9]{20,255}|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----)'

  while IFS= read -r -d '' file; do
    hits="$({
      grep -nEo "$unix_pattern" "$file" 2>/dev/null \
        | grep -Ev '/(usr/bin/env|bin/bash|bin/sh|dev/(null|stdin|stdout|stderr))$|/Users/\.\.\.$' || true
      grep -nE "$windows_pattern" "$file" 2>/dev/null || true
    } | sort -u)"
    if [ "$hits" != "" ]; then
      path_hits="${path_hits}${file#$ROOT/}:$hits"$'\n'
    fi

    while IFS= read -r candidate; do
      [ "$candidate" = "" ] && continue
      if ! factory_candidate_is_placeholder "$candidate"; then
        secret_hits="${secret_hits}${file#$ROOT/}:$candidate"$'\n'
      fi
    done < <(grep -nEo -i "$assignment_pattern" "$file" 2>/dev/null || true)

    hits="$(grep -nE "$token_pattern" "$file" 2>/dev/null || true)"
    if [ "$hits" != "" ]; then
      secret_hits="${secret_hits}${file#$ROOT/}:$hits"$'\n'
    fi
  done < <(find "$ROOT" \
    \( -path "$ROOT/.git" -o -path "$ROOT/tests/fixtures/broken-workspace" -o -path "$ROOT/tests/fixtures/invalid-*" \) -prune \
    -o -type f -print0)

  if [ "$path_hits" = "" ]; then
    pass "factory contains no persisted absolute project/data paths"
  else
    fail "factory contains persisted absolute project/data paths outside intentional negative fixtures"
    printf '%s' "$path_hits" >&2
  fi

  if [ "$secret_hits" = "" ]; then
    pass "factory contains no embedded high-confidence secrets"
  else
    fail "factory contains possible secrets outside intentional negative fixtures"
    printf '%s' "$secret_hits" | cut -d: -f1-2 | sort -u >&2
  fi
}

check_templates() {
  local template
  local rel
  local invalid_hits
  local count=0

  while IFS= read -r -d '' template; do
    count=$((count + 1))
    rel="templates/$(basename "$template")"

    if [ -s "$template" ]; then
      pass "$rel non-empty"
    else
      fail "$rel is empty"
      continue
    fi

    if grep -Eq '\{\{[A-Z][A-Z0-9_]*\}\}' "$template"; then
      pass "$rel contains canonical {{UPPER_CASE}} placeholders"
    else
      fail "$rel has no canonical {{UPPER_CASE}} placeholders"
    fi

    invalid_hits="$(grep -nE '\{\{[a-z][A-Za-z0-9_]*\}\}|<[A-Z][A-Z0-9_]*>|<[A-Z][A-Za-z0-9]*[a-z][A-Z][A-Za-z0-9]*>' "$template" 2>/dev/null || true)"
    if [ "$invalid_hits" = "" ]; then
      pass "$rel has no legacy placeholder syntax"
    else
      fail "$rel contains non-canonical placeholder syntax"
      printf '%s\n' "$invalid_hits" >&2
    fi
  done < <(find "$ROOT/templates" -maxdepth 1 -type f -name '*.md' -print0)

  if [ "$count" -eq 0 ]; then
    fail "no templates/*.md files found"
  fi

  if grep -Fqx '## Executive summary' "$ROOT/templates/report-update.md" \
      && grep -Fq '{{EXECUTIVE_SUMMARY}}' "$ROOT/templates/report-update.md"; then
    pass "update report template requires an executive summary"
  else
    fail "templates/report-update.md must contain the executive summary section and placeholder"
  fi
}

check_workflow_coverage() {
  local workflow="$ROOT/.github/workflows/validate.yml"
  local required

  [ -s "$workflow" ] || return

  for required in \
    'bash scripts/validate-factory.sh' \
    'bash scripts/validate-workspace.sh' \
    'bash scripts/test-validators.sh' \
    'bash scripts/test-discover.sh' \
    'bash scripts/validate-evals.sh' \
    'bash scripts/test-evals.sh' \
    'bash scripts/check-repo-links.sh' \
    'bash scripts/lessons-ledger.sh validate'; do
    if grep -Fq "$required" "$workflow"; then
      pass "CI runs: $required"
    else
      fail "CI must run: $required"
    fi
  done

  if grep -Eq 'fetch-depth:[[:space:]]*0' "$workflow"; then
    pass "CI fetches full history for append-only range validation"
  else
    fail "CI checkout must use fetch-depth: 0 for append-only range validation"
  fi

  if grep -Fq 'LESSONS_BASE_REF:' "$workflow"; then
    pass "CI supplies the PR/push base ref to append-only validation"
  else
    fail "CI must supply LESSONS_BASE_REF for multi-commit append-only validation"
  fi

  if grep -Fq 'ubuntu-latest' "$workflow" && grep -Fq 'macos-latest' "$workflow"; then
    pass "CI validates on Ubuntu and macOS"
  else
    fail "CI must validate on Ubuntu and macOS"
  fi

  if grep -Eq 'actions/checkout@[0-9a-f]{40}' "$workflow"; then
    pass "CI pins actions/checkout to a full commit SHA"
  else
    fail "CI must pin actions/checkout to a full commit SHA"
  fi
}

check_workflow_action_pins() {
  local workflow
  local line
  local rel
  local count=0

  while IFS= read -r -d '' workflow; do
    rel="${workflow#$ROOT/}"
    while IFS= read -r line; do
      [ "$line" = "" ] && continue
      count=$((count + 1))
      if printf '%s\n' "$line" | grep -Eq 'uses:[[:space:]]+[^[:space:]@]+@[0-9a-f]{40}([[:space:]]*#.*)?$|uses:[[:space:]]+\./'; then
        pass "$rel action reference is immutable: $(printf '%s\n' "$line" | sed 's/^[[:space:]]*//')"
      else
        fail "$rel contains an unpinned or unsupported action reference: $(printf '%s\n' "$line" | sed 's/^[[:space:]]*//')"
      fi
    done < <(grep -E '^[[:space:]]*-?[[:space:]]*uses:' "$workflow" 2>/dev/null || true)
  done < <(find "$ROOT/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print0)

  if [ "$count" -eq 0 ]; then
    fail "no GitHub Actions uses: references found"
  fi
}

check_discovery_contract() {
  local discover="$ROOT/scripts/discover.sh"
  local test_discover="$ROOT/scripts/test-discover.sh"
  local live_discover="$ROOT/scripts/test-live-discovery.sh"
  local smoke_workflow="$ROOT/.github/workflows/discovery-smoke.yml"
  local marker

  [ -s "$discover" ] || return
  for marker in DISCOVER_TIMEOUT run_with_timeout urlencode registry.npmjs.org 'PACCHETTO ASSENTE' 'FONTE NON RAGGIUNGIBILE'; do
    if grep -Fq "$marker" "$discover"; then
      pass "discover.sh implements $marker"
    else
      fail "discover.sh missing required behavior marker: $marker"
    fi
  done

  if [ -s "$test_discover" ] && grep -Fq 'tests/fixtures/discover-bin' "$test_discover"; then
    pass "discovery tests use deterministic command mocks"
  else
    fail "test-discover.sh must use tests/fixtures/discover-bin mocks"
  fi

  if [ -s "$test_discover" ] && grep -Fq 'multiword query uses npm search' "$test_discover"; then
    pass "discovery tests cover multiword npm queries"
  else
    fail "test-discover.sh must cover multiword npm queries"
  fi

  if [ -s "$live_discover" ] && grep -Fq 'LIVE_DISCOVERY_MIN_REACHABLE' "$live_discover"; then
    pass "live discovery smoke has an explicit reachability threshold"
  else
    fail "test-live-discovery.sh must enforce a reachability threshold"
  fi

  if [ -s "$smoke_workflow" ] \
      && grep -Fq 'schedule:' "$smoke_workflow" \
      && grep -Fq 'bash scripts/test-live-discovery.sh' "$smoke_workflow"; then
    pass "scheduled workflow runs the bounded live discovery smoke"
  else
    fail "discovery smoke workflow must be scheduled and run test-live-discovery.sh"
  fi
}

check_json_syntax() {
  local file
  local count=0

  if ! command -v python3 >/dev/null 2>&1; then
    fail "python3 is required for JSON and Markdown-link validation"
    return
  fi

  while IFS= read -r -d '' file; do
    count=$((count + 1))
    if python3 -m json.tool "$file" >/dev/null; then
      pass "${file#$ROOT/} is valid JSON"
    else
      fail "${file#$ROOT/} is invalid JSON"
    fi
  done < <(find "$ROOT" -path "$ROOT/.git" -prune -o -type f -name '*.json' -print0)

  if [ "$count" -eq 0 ]; then
    fail "no JSON files found"
  fi
}

check_repo_links() {
  if bash "$ROOT/scripts/check-repo-links.sh" "$ROOT"; then
    pass "repository-local Markdown links resolve"
  else
    fail "repository-local Markdown link validation failed"
  fi
}

check_lesson_ledger() {
  local ledger_script="$ROOT/scripts/lessons-ledger.sh"
  local ledger="$ROOT/reports/lesson-events.tsv"

  [ -s "$ledger_script" ] || return
  [ -s "$ledger" ] || return

  if bash "$ledger_script" validate "$ledger"; then
    pass "lesson event ledger validates"
  else
    fail "lesson event ledger validation failed"
  fi
  if bash "$ledger_script" summary "$ledger" >/dev/null; then
    pass "lesson event ledger summary is computable"
  else
    fail "lesson event ledger summary failed"
  fi
  if bash "$ledger_script" eligible "$ledger" >/dev/null; then
    pass "lesson event ledger eligibility is computable"
  else
    fail "lesson event ledger eligibility failed"
  fi
}

printf 'Validating agent-factory at %s\n' "$ROOT"

for required_file in \
  README.md \
  AGENTS.md \
  CHANGELOG.md \
  CODE_OF_CONDUCT.md \
  CONTRIBUTING.md \
  SECURITY.md \
  skills/agent-workspace-builder/SKILL.md \
  skills/agent-workspace-builder/evals/README.md \
  skills/agent-workspace-builder/evals/evals.json \
  skills/agent-workspace-builder/evals/files/research-seed/AGENTS.md \
  skills/agent-workspace-builder/evals/files/research-seed/README.md \
  skills/agent-workspace-builder/evals/files/research-seed/RESEARCH.md \
  skills/agent-workspace-builder/evals/files/research-seed/skills/web-research/SKILL.md \
  skills/agent-workspace-builder/evals/runs/iteration-1/analysis-notes.json \
  skills/agent-workspace-builder/evals/runs/iteration-1/benchmark.json \
  skills/agent-workspace-builder/evals/runs/iteration-1/benchmark.md \
  skills/agent-workspace-builder/evals/runs/iteration-1/review.html \
  skills/agent-workspace-builder/evals/results/2026-07-11-paired-benchmark.json \
  reports/lessons.md \
  reports/lesson-events.tsv \
  reports/agent-factory-technical-overview.md \
  scripts/validate-factory.sh \
  scripts/validate-workspace.sh \
  scripts/discover.sh \
  scripts/check-repo-links.py \
  scripts/check-repo-links.sh \
  scripts/test-discover.sh \
  scripts/test-evals.sh \
  scripts/test-live-discovery.sh \
  scripts/test-validators.sh \
  scripts/build-eval-artifacts.py \
  scripts/build-eval-artifacts.sh \
  scripts/validate-evals.py \
  scripts/validate-evals.sh \
  scripts/lessons-ledger.sh \
  .github/CODEOWNERS \
  .github/dependabot.yml \
  .github/pull_request_template.md \
  .github/ISSUE_TEMPLATE/config.yml \
  .github/ISSUE_TEMPLATE/bug_report.yml \
  .github/ISSUE_TEMPLATE/improvement.yml \
  .github/ISSUE_TEMPLATE/security_channel.yml \
  .github/workflows/discovery-smoke.yml \
  .github/workflows/validate.yml; do
  require_file "$required_file"
done

require_dir "skills/agent-workspace-builder/references"
require_dir "templates"
require_dir "scripts"
require_dir "tests/fixtures"
require_dir ".github/workflows"
require_dir ".github/ISSUE_TEMPLATE"

check_shell_scripts
check_blueprint_index
check_skill_doc_references
check_templates
check_workflow_coverage
check_workflow_action_pins
check_discovery_contract
check_json_syntax
check_repo_links
check_lesson_ledger
check_factory_privacy

skill_count=0
while IFS= read -r -d '' skill_file; do
  skill_count=$((skill_count + 1))
  check_skill_frontmatter "$skill_file"
done < <(find "$ROOT/skills" -type f -name SKILL.md -print0)

if [ "$skill_count" -eq 0 ]; then
  fail "no skills/*/SKILL.md files found"
fi

finish
