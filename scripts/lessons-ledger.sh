#!/usr/bin/env bash

# Validate and query the append-only lesson-event ledger that drives blueprint
# proposals and promotions. The TSV stays deliberately simple and auditable.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_LEDGER="$ROOT/reports/lesson-events.tsv"
COMMAND="${1:-}"
LEDGER="${2:-$DEFAULT_LEDGER}"
CONFIGURED_BASE_REF="${LESSONS_BASE_REF:-}"

usage() {
  printf 'Usage: bash scripts/lessons-ledger.sh <validate|summary|eligible> [ledger.tsv]\n' >&2
}

validate_schema() {
  local file="$1"

  if [ ! -s "$file" ]; then
    printf 'Ledger missing or empty: %s\n' "$file" >&2
    return 1
  fi

  awk -F '\t' '
    BEGIN {
      expected = "schema_version\tevent_id\tdate\tcycle_id\tagent_type\tvariant_id\tevent_kind\treal\tdraft_state"
      valid = 1
    }
    NR == 1 {
      if ($0 != expected) {
        printf "line 1: invalid header\n" > "/dev/stderr"
        valid = 0
      }
      next
    }
    {
      if (NF != 9) {
        printf "line %d: expected 9 tab-separated fields, found %d\n", NR, NF > "/dev/stderr"
        valid = 0
        next
      }

      if ($1 != "1") {
        printf "line %d: schema_version must be 1\n", NR > "/dev/stderr"
        valid = 0
      }
      if ($2 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) {
        printf "line %d: event_id must be a lowercase hyphenated slug\n", NR > "/dev/stderr"
        valid = 0
      } else if (seen_event[$2]++) {
        printf "line %d: duplicate event_id %s\n", NR, $2 > "/dev/stderr"
        valid = 0
      }
      if ($3 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) {
        printf "line %d: date must use YYYY-MM-DD\n", NR > "/dev/stderr"
        valid = 0
      }
      if ($4 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) {
        printf "line %d: cycle_id must be a lowercase hyphenated slug\n", NR > "/dev/stderr"
        valid = 0
      }
      if ($5 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) {
        printf "line %d: agent_type must be a lowercase hyphenated slug\n", NR > "/dev/stderr"
        valid = 0
      }
      if ($6 !~ /^[a-z0-9]+(-[a-z0-9]+)*$/) {
        printf "line %d: variant_id must be a lowercase hyphenated slug\n", NR > "/dev/stderr"
        valid = 0
      }
      if ($7 !~ /^(generation|update|post_run|provider_test|proposal|approval|promotion)$/) {
        printf "line %d: invalid event_kind %s\n", NR, $7 > "/dev/stderr"
        valid = 0
      }
      if ($8 !~ /^(true|false)$/) {
        printf "line %d: real must be true or false\n", NR > "/dev/stderr"
        valid = 0
      }
      if ($9 !~ /^(none|proposed|approved|rejected)$/) {
        printf "line %d: invalid draft_state %s\n", NR, $9 > "/dev/stderr"
        valid = 0
      }

      if ($7 == "proposal" && $9 != "proposed") {
        printf "line %d: proposal events require draft_state=proposed\n", NR > "/dev/stderr"
        valid = 0
      } else if ($7 == "approval" && $9 !~ /^(approved|rejected)$/) {
        printf "line %d: approval events require approved or rejected draft_state\n", NR > "/dev/stderr"
        valid = 0
      } else if ($7 == "promotion" && $9 != "approved") {
        printf "line %d: promotion events require draft_state=approved\n", NR > "/dev/stderr"
        valid = 0
      } else if ($7 !~ /^(proposal|approval|promotion)$/ && $9 != "none") {
        printf "line %d: %s events require draft_state=none\n", NR, $7 > "/dev/stderr"
        valid = 0
      }

      if (($6 in variant_type) && variant_type[$6] != $5) {
        printf "line %d: variant_id %s is associated with multiple agent types\n", NR, $6 > "/dev/stderr"
        valid = 0
      } else {
        variant_type[$6] = $5
      }
    }
    END { exit !valid }
  ' "$file"
}

check_append_only() {
  local file="$1"
  local file_abs
  local default_abs
  local rel="reports/lesson-events.tsv"
  local baseline_ref=""
  local baseline
  local current_prefix
  local baseline_lines
  local current_lines

  file_abs="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  default_abs="$(cd "$(dirname "$DEFAULT_LEDGER")" && pwd)/$(basename "$DEFAULT_LEDGER")"

  if [ "$file_abs" != "$default_abs" ]; then
    printf 'OK   append-only baseline skipped for custom ledger fixture\n'
    return
  fi

  if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'OK   append-only baseline skipped (not a git worktree)\n'
    return
  fi

  if [ "$CONFIGURED_BASE_REF" != "" ]; then
    if printf '%s\n' "$CONFIGURED_BASE_REF" | grep -Eq '^0+$'; then
      printf 'OK   append-only baseline skipped (initial push has no base commit)\n'
      return
    fi
    if ! git -C "$ROOT" rev-parse --verify "$CONFIGURED_BASE_REF^{commit}" >/dev/null 2>&1; then
      printf 'Configured LESSONS_BASE_REF is not available locally: %s\n' "$CONFIGURED_BASE_REF" >&2
      return 1
    fi
    if ! git -C "$ROOT" cat-file -e "$CONFIGURED_BASE_REF:$rel" 2>/dev/null; then
      printf 'OK   append-only baseline skipped (ledger absent at configured base; migration)\n'
      return
    fi
    baseline_ref="$CONFIGURED_BASE_REF"
  fi

  if [ "$baseline_ref" = "" ] && ! git -C "$ROOT" cat-file -e "HEAD:$rel" 2>/dev/null; then
    printf 'OK   append-only baseline skipped (ledger not present in HEAD; migration)\n'
    return
  fi

  if [ "$baseline_ref" = "" ]; then
    if ! git -C "$ROOT" diff --quiet HEAD -- "$rel" 2>/dev/null; then
      baseline_ref="HEAD"
    elif git -C "$ROOT" rev-parse --verify HEAD^ >/dev/null 2>&1 \
        && git -C "$ROOT" cat-file -e "HEAD^:$rel" 2>/dev/null; then
      baseline_ref="HEAD^"
    else
      printf 'OK   append-only baseline skipped (no prior committed ledger)\n'
      return
    fi
  fi

  baseline="$(git -C "$ROOT" show "$baseline_ref:$rel" 2>/dev/null)"
  baseline_lines="$(printf '%s\n' "$baseline" | awk 'END { print NR }')"
  current_lines="$(awk 'END { print NR }' "$file")"

  if [ "$current_lines" -lt "$baseline_lines" ]; then
    printf 'Ledger is not append-only: current file is shorter than %s.\n' "$baseline_ref" >&2
    return 1
  fi

  current_prefix="$(sed -n "1,${baseline_lines}p" "$file")"
  if [ "$current_prefix" != "$baseline" ]; then
    printf 'Ledger is not append-only: existing rows differ from %s.\n' "$baseline_ref" >&2
    return 1
  fi

  printf 'OK   ledger is append-only relative to %s\n' "$baseline_ref"
}

check_lessons_append_only() {
  local file="$ROOT/reports/lessons.md"
  local rel="reports/lessons.md"
  local baseline_ref=""
  local baseline
  local current_prefix
  local baseline_lines
  local current_lines

  if [ ! -s "$file" ]; then
    printf 'Lessons register missing or empty: %s\n' "$file" >&2
    return 1
  fi

  if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'OK   lessons append-only baseline skipped (not a git worktree)\n'
    return
  fi

  if [ "$CONFIGURED_BASE_REF" != "" ]; then
    if printf '%s\n' "$CONFIGURED_BASE_REF" | grep -Eq '^0+$'; then
      printf 'OK   lessons append-only baseline skipped (initial push has no base commit)\n'
      return
    fi
    if ! git -C "$ROOT" rev-parse --verify "$CONFIGURED_BASE_REF^{commit}" >/dev/null 2>&1; then
      printf 'Configured LESSONS_BASE_REF is not available locally: %s\n' "$CONFIGURED_BASE_REF" >&2
      return 1
    fi
    if ! git -C "$ROOT" cat-file -e "$CONFIGURED_BASE_REF:$rel" 2>/dev/null; then
      printf 'OK   lessons append-only baseline skipped (register absent at configured base)\n'
      return
    fi
    baseline_ref="$CONFIGURED_BASE_REF"
  fi

  if [ "$baseline_ref" = "" ] && ! git -C "$ROOT" cat-file -e "HEAD:$rel" 2>/dev/null; then
    printf 'OK   lessons append-only baseline skipped (register not present in HEAD)\n'
    return
  fi

  if [ "$baseline_ref" = "" ]; then
    if ! git -C "$ROOT" diff --quiet HEAD -- "$rel" 2>/dev/null; then
      baseline_ref="HEAD"
    elif git -C "$ROOT" rev-parse --verify HEAD^ >/dev/null 2>&1 \
        && git -C "$ROOT" cat-file -e "HEAD^:$rel" 2>/dev/null; then
      baseline_ref="HEAD^"
    else
      printf 'OK   lessons append-only baseline skipped (no prior committed register)\n'
      return
    fi
  fi

  baseline="$(git -C "$ROOT" show "$baseline_ref:$rel" 2>/dev/null)"
  if ! printf '%s\n' "$baseline" | grep -Fq '<!-- append-only-policy: 1 -->'; then
    printf 'OK   lessons append-only baseline skipped (policy migration)\n'
    return
  fi

  baseline_lines="$(printf '%s\n' "$baseline" | awk 'END { print NR }')"
  current_lines="$(awk 'END { print NR }' "$file")"
  if [ "$current_lines" -lt "$baseline_lines" ]; then
    printf 'Lessons register is not append-only: current file is shorter than %s.\n' "$baseline_ref" >&2
    return 1
  fi

  current_prefix="$(sed -n "1,${baseline_lines}p" "$file")"
  if [ "$current_prefix" != "$baseline" ]; then
    printf 'Lessons register is not append-only: existing lines differ from %s.\n' "$baseline_ref" >&2
    return 1
  fi

  printf 'OK   lessons register is append-only relative to %s\n' "$baseline_ref"
}

validate_ledger() {
  local file="$1"
  local file_abs
  local default_abs

  validate_schema "$file"
  printf 'OK   ledger schema, enums, slugs, and event IDs are valid\n'
  check_append_only "$file"

  file_abs="$(cd "$(dirname "$file")" && pwd)/$(basename "$file")"
  default_abs="$(cd "$(dirname "$DEFAULT_LEDGER")" && pwd)/$(basename "$DEFAULT_LEDGER")"
  if [ "$file_abs" = "$default_abs" ]; then
    check_lessons_append_only
  fi
}

emit_summary() {
  local file="$1"
  local only_eligible="$2"

  printf 'agent_type\tvariant_id\treal_generation_cycles\tproposal_exists\tapproval_approved\tpromotion_recorded\tdraft_eligible\tpromotion_eligible\n'
  awk -F '\t' -v only_eligible="$only_eligible" '
    NR == 1 { next }
    {
      type[$6] = $5
      variants[$6] = 1
      if ($7 == "generation" && $8 == "true") {
        cycles[$6 SUBSEP $4] = 1
      }
      if ($7 == "proposal" && $9 == "proposed") {
        proposed[$6] = 1
      }
      if ($7 == "approval" && $9 == "approved") {
        approved[$6] = 1
      }
      if ($7 == "promotion" && $9 == "approved") {
        promoted[$6] = 1
      }
    }
    END {
      for (key in cycles) {
        split(key, parts, SUBSEP)
        count[parts[1]]++
      }
      for (variant in variants) {
        draft_ok = (count[variant] >= 2 ? "true" : "false")
        promotion_ok = (count[variant] >= 3 && approved[variant] ? "true" : "false")
        if (only_eligible == "true" && draft_ok != "true" && promotion_ok != "true") {
          continue
        }
        printf "%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\n", \
          type[variant], variant, count[variant] + 0, \
          (proposed[variant] ? "true" : "false"), \
          (approved[variant] ? "true" : "false"), \
          (promoted[variant] ? "true" : "false"), \
          draft_ok, promotion_ok
      }
    }
  ' "$file" | sort -t $'\t' -k1,1 -k2,2
}

case "$COMMAND" in
  validate)
    validate_ledger "$LEDGER"
    ;;
  summary)
    validate_ledger "$LEDGER" >/dev/null
    emit_summary "$LEDGER" false
    ;;
  eligible)
    validate_ledger "$LEDGER" >/dev/null
    emit_summary "$LEDGER" true
    ;;
  *)
    usage
    exit 2
    ;;
esac
