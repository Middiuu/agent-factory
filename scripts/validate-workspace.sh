#!/usr/bin/env bash

# Structural and semantic validation for generated agent workspaces.
# Keep this validator dependency-free: it must run with Bash plus standard
# POSIX utilities on both macOS and Linux.

set -euo pipefail

if [ "${1:-}" = "" ]; then
  printf 'Usage: bash scripts/validate-workspace.sh <workspace-path>\n' >&2
  exit 2
fi

if [ ! -d "$1" ]; then
  printf 'Workspace not found: %s\n' "$1" >&2
  exit 2
fi

WS="$(cd "$1" && pwd)"
failures=0
SKILL_COUNT=0

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

  if [ -s "$WS/$rel" ]; then
    pass "$rel non-empty"
  elif [ -f "$WS/$rel" ]; then
    fail "$rel is empty"
  else
    fail "$rel missing"
  fi
}

require_dir() {
  local rel="$1"

  if [ -d "$WS/$rel" ]; then
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

frontmatter_value() {
  local key="$1"
  local file="$2"

  awk -v wanted="$key" '
    NR == 1 && $0 != "---" { exit 1 }
    NR > 1 && $0 == "---" { exit }
    NR > 1 {
      colon = index($0, ":")
      if (colon == 0) {
        next
      }
      found_key = substr($0, 1, colon - 1)
      if (found_key != wanted) {
        next
      }
      value = substr($0, colon + 1)
      sub(/^[[:space:]]+/, "", value)
      sub(/[[:space:]]+$/, "", value)
      sub(/^"/, "", value)
      sub(/"$/, "", value)
      print value
      exit
    }
  ' "$file"
}

check_skill_frontmatter() {
  local file="$1"
  local rel="${file#$WS/}"
  local dir_name
  local name_value
  local desc_value

  dir_name="$(basename "$(dirname "$file")")"

  if ! frontmatter_block "$file" >/dev/null; then
    fail "$rel frontmatter must start and end with ---"
    return
  fi

  name_value="$(frontmatter_value name "$file")"
  desc_value="$(frontmatter_value description "$file")"

  if [ "$name_value" = "" ]; then
    fail "$rel missing frontmatter name"
  elif [ "$name_value" != "$dir_name" ]; then
    fail "$rel name '$name_value' does not match directory '$dir_name'"
  elif ! printf '%s\n' "$name_value" | grep -Eq '^[a-z0-9]+([_-][a-z0-9]+)*$'; then
    fail "$rel name must be a lowercase slug"
  else
    pass "$rel name frontmatter"
  fi

  if [ "$desc_value" = "" ] || [ "$desc_value" = "|" ] || [ "$desc_value" = ">" ]; then
    fail "$rel missing frontmatter description"
  else
    pass "$rel description frontmatter"
  fi
}

section_has_content() {
  local file="$1"
  local heading_regex="$2"

  awk -v wanted="$heading_regex" '
    /^[#]+[[:space:]]+/ {
      heading = tolower($0)
      active = 0
      if (heading ~ wanted) {
        found = 1
        active = 1
      }
      next
    }
    active && $0 !~ /^[[:space:]]*$/ { content = 1 }
    END { exit !(found && content) }
  ' "$file"
}

section_has_pattern() {
  local file="$1"
  local heading_regex="$2"
  local content_regex="$3"

  awk -v wanted="$heading_regex" -v content_wanted="$content_regex" '
    /^[#]+[[:space:]]+/ {
      heading = tolower($0)
      active = 0
      if (heading ~ wanted) {
        found = 1
        active = 1
      }
      next
    }
    active && tolower($0) ~ content_wanted { matched = 1 }
    END { exit !(found && matched) }
  ' "$file"
}

heading_line() {
  local file="$1"
  local heading_regex="$2"

  awk -v wanted="$heading_regex" '
    /^[#]+[[:space:]]+/ && tolower($0) ~ wanted { print NR; exit }
  ' "$file"
}

check_nonempty_section() {
  local file="$1"
  local rel="$2"
  local label="$3"
  local heading_regex="$4"

  if section_has_content "$file" "$heading_regex"; then
    pass "$rel has non-empty $label section"
  else
    fail "$rel missing or empty $label section"
  fi
}

check_doc_basics() {
  local doc="$1"

  if [ ! -s "$WS/$doc" ]; then
    return
  fi

  if grep -Eq 'skills/' "$WS/$doc"; then
    pass "$doc references skills/"
  else
    fail "$doc should reference skills/"
  fi

  if grep -Eq 'reports/' "$WS/$doc"; then
    pass "$doc references reports/"
  else
    fail "$doc should reference reports/"
  fi
}

check_readme_setup() {
  local file="$WS/README.md"
  local required_re='^#+[[:space:]]+(setup obbligatorio|required setup|mandatory setup|prerequisiti obbligatori)([[:space:]]|$)'
  local optional_re='^#+[[:space:]]+(setup opzionale|optional setup|prerequisiti opzionali)([[:space:]]|$)'
  local required_line
  local optional_line

  [ -s "$file" ] || return

  check_nonempty_section "$file" "README.md" "required setup" "$required_re"
  check_nonempty_section "$file" "README.md" "optional setup" "$optional_re"

  required_line="$(heading_line "$file" "$required_re")"
  optional_line="$(heading_line "$file" "$optional_re")"
  if [ "$required_line" != "" ] && [ "$optional_line" != "" ]; then
    if [ "$required_line" -lt "$optional_line" ]; then
      pass "README.md lists required setup before optional setup"
    else
      fail "README.md must list required setup before optional setup"
    fi
  fi

  check_nonempty_section "$file" "README.md" "usage/quickstart" '^#+[[:space:]]+(quickstart|come usarlo|utilizzo|usage)([[:space:]]|$)'
  check_nonempty_section "$file" "README.md" "expected outputs" '^#+[[:space:]]+(output attesi|expected outputs|output)([[:space:]]|$)'
}

check_skill_files() {
  local skill_file

  if [ ! -d "$WS/skills" ]; then
    return
  fi

  while IFS= read -r -d '' skill_file; do
    SKILL_COUNT=$((SKILL_COUNT + 1))
    check_skill_frontmatter "$skill_file"
  done < <(find "$WS/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f -print0)

  if [ "$SKILL_COUNT" -eq 0 ]; then
    pass "no local skills found (allowed when discovery selected existing capabilities)"
  else
    pass "$SKILL_COUNT local skill file(s) found"
  fi
}

check_reference_target() {
  local doc="$1"
  local raw_target="$2"
  local target="$raw_target"
  local rel_doc="${doc#$WS/}"
  local doc_dir
  local target_path
  local resolved_dir

  target="${target#<}"
  target="${target%>}"
  target="${target%%#*}"
  target="${target%%\?*}"

  [ "$target" = "" ] && return
  case "$target" in
    http://*|https://*|mailto:*|tel:*|data:*|\#*) return ;;
  esac

  if [ "${target#/}" != "$target" ]; then
    fail "$rel_doc has workspace-external absolute link: $raw_target"
    return
  fi

  doc_dir="$(dirname "$doc")"
  target_path="$doc_dir/$target"
  if [ -e "$target_path" ]; then
    resolved_dir="$(cd "$(dirname "$target_path")" 2>/dev/null && pwd -P)" || resolved_dir=""
    case "$resolved_dir" in
      "$WS"|"$WS"/*) ;;
      *)
        fail "$rel_doc has workspace-external relative link: $raw_target"
        return
        ;;
    esac
    if [ -L "$target_path" ]; then
      fail "$rel_doc references a symlink instead of a portable workspace file: $raw_target"
      return
    fi
    return
  fi

  fail "$rel_doc has broken Markdown reference: $raw_target"
}

check_symlinks() {
  local hits

  hits="$(find "$WS" -path "$WS/.git" -prune -o -type l -print 2>/dev/null || true)"
  if [ "$hits" = "" ]; then
    pass "workspace contains no symlinks"
  else
    fail "workspace contains symlink(s); generated workspaces must be self-contained"
    printf '%s\n' "$hits" | sed "s#^$WS/#  #" >&2
  fi
}

check_markdown_references() {
  local doc
  local token
  local rel
  local broken_before="$failures"

  while IFS= read -r -d '' doc; do
    rel="${doc#$WS/}"

    while IFS= read -r token; do
      [ "$token" = "" ] && continue
      token="${token#](}"
      token="${token%)}"
      check_reference_target "$doc" "$token"
    done < <(grep -oE '\]\(<[^>]+>|\]\([^[:space:])]+)' "$doc" 2>/dev/null || true)

    while IFS= read -r token; do
      [ "$token" = "" ] && continue
      if [ ! -f "$WS/$token" ]; then
        fail "$rel has broken skill reference: $token"
      fi
    done < <(grep -oE 'skills/[A-Za-z0-9._/-]+/SKILL\.md' "$doc" 2>/dev/null | sort -u || true)

    while IFS= read -r token; do
      [ "$token" = "" ] && continue
      case "$token" in
        *YYYY*|*'< '*|*'>'*|*'*'*) continue ;;
      esac
      if [ ! -f "$WS/$token" ]; then
        fail "$rel references missing report file: $token"
      fi
    done < <(grep -oE 'reports/[A-Za-z0-9._/-]+\.md' "$doc" 2>/dev/null | sort -u || true)
  done < <(find "$WS" -path "$WS/.git" -prune -o -type f -name '*.md' -print0)

  if [ "$failures" -eq "$broken_before" ]; then
    pass "all internal references in Markdown files resolve"
  fi
}

check_placeholders() {
  local placeholder_hits
  local pattern='(<[A-Z][A-Z0-9_]*>|<[A-Z][A-Za-z0-9]*[a-z][A-Z][A-Za-z0-9]*>|\{\{[^{}]+\}\})'

  placeholder_hits="$(grep -RInE --exclude-dir=.git "$pattern" "$WS" 2>/dev/null || true)"

  if [ "$placeholder_hits" != "" ]; then
    fail "unresolved template placeholder(s) found (<UPPER_CASE>, <CamelCase>, or {{...}})"
    printf '%s\n' "$placeholder_hits" >&2
  else
    pass "no unresolved template placeholders found"
  fi
}

check_local_paths() {
  local absolute_path_hits
  # Boundaries prevent URL fragments from being mistaken for absolute Unix,
  # Windows, or UNC project/data paths.
  local unix_pattern="(^|[[:space:]\`\"'(=])(/[A-Za-z0-9._~{}$-]+){2,}"
  local windows_pattern="(^|[^A-Za-z0-9])([A-Za-z]:[\\\\/][^[:space:]\`\"']+|\\\\\\\\[A-Za-z0-9._-]+[\\\\/][A-Za-z0-9.$_-]+)"

  absolute_path_hits="$({
    grep -RInEo --exclude-dir=.git "$unix_pattern" "$WS" 2>/dev/null \
      | grep -Ev '/(usr/bin/env|bin/bash|bin/sh|dev/(null|stdin|stdout|stderr))$' || true
    grep -RInE --exclude-dir=.git "$windows_pattern" "$WS" 2>/dev/null || true
  } | sort -u)"

  if [ "$absolute_path_hits" != "" ]; then
    fail "local absolute project/data path reference(s) found (Unix, Windows, or UNC)"
    printf '%s\n' "$absolute_path_hits" >&2
  else
    pass "no local absolute project/data path references found"
  fi
}

candidate_is_placeholder() {
  local candidate="$1"
  local assignment_key='(api[_-]?key|client[_-]?secret|access[_-]?token|auth[_-]?token|password|passwd|secret|token)'
  local placeholder_value

  # Match only the right-hand side. Words such as "placeholder" elsewhere on
  # the same line must never excuse an embedded credential.
  placeholder_value="${assignment_key}[[:space:]]*[:=][[:space:]]*[\"']?(\\\$\\{[^}]+\\}|\\\$[A-Za-z_][A-Za-z0-9_]*|<[A-Za-z0-9_ -]+>|\\{\\{[^}]+\\}\\}|REPLACE_ME|CHANGE_ME|CHANGEME|your[-_ ]?(api[-_ ]?)?key|placeholder|example|dummy|fake|redacted|not[-_ ]?set|none|null|process\\.env\\.[A-Z][A-Z0-9_]*|os\\.(environ|getenv).*)[\"']?([[:space:],;#]|$)"
  printf '%s\n' "$candidate" | grep -Eiq "$placeholder_value"
}

print_secret_locations() {
  local hits="$1"
  local candidate
  local location

  while IFS= read -r candidate; do
    [ "$candidate" = "" ] && continue
    location="$(printf '%s\n' "$candidate" | cut -d: -f1-2)"
    printf '  %s (value redacted)\n' "$location" >&2
  done < <(printf '%s\n' "$hits")
}

check_secret_patterns() {
  local assignment_pattern
  local token_pattern
  local assignment_candidates
  local token_hits
  local secret_hits=""
  local candidate

  assignment_pattern="(api[_-]?key|client[_-]?secret|access[_-]?token|auth[_-]?token|password|passwd|secret|token)[[:space:]]*[:=][[:space:]]*(\"[^\"]{8,}\"|'[^']{8,}'|[^[:space:]\`\"']{8,})"
  token_pattern='(github_pat_[A-Za-z0-9_]{20,255}|gh[pousr]_[A-Za-z0-9]{20,255}|glpat-[A-Za-z0-9_-]{20,255}|sk-ant-[A-Za-z0-9_-]{20,255}|sk-(proj-)?[A-Za-z0-9_-]{20,255}|xox[baprs]-[A-Za-z0-9-]{10,255}|(AKIA|ASIA)[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|npm_[A-Za-z0-9]{20,255}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|-----BEGIN ([A-Z ]+ )?PRIVATE KEY-----)'

  assignment_candidates="$(grep -RInEo -i --exclude-dir=.git "$assignment_pattern" "$WS" 2>/dev/null || true)"
  token_hits="$(grep -RInE --exclude-dir=.git "$token_pattern" "$WS" 2>/dev/null || true)"

  while IFS= read -r candidate; do
    [ "$candidate" = "" ] && continue
    if ! candidate_is_placeholder "$candidate"; then
      secret_hits="${secret_hits}${candidate}"$'\n'
    fi
  done < <(printf '%s\n' "$assignment_candidates")

  if [ "$token_hits" != "" ]; then
    secret_hits="${secret_hits}${token_hits}"$'\n'
  fi

  if [ "$secret_hits" != "" ]; then
    fail "possible secret pattern(s) found"
    print_secret_locations "$secret_hits"
  else
    pass "no embedded secrets or modern token formats found"
  fi
}

check_web_safety() {
  local indicators
  local indicator_files
  local agents="$WS/AGENTS.md"
  local semantic_failures=0

  indicators='web[ -]?(search|research|fetch|scrap|crawl)|crawl|site[ -]?monitor|monitor(aggio|ing)|pagine web|contenuto (web|esterno|osservato)|external content|browser automation|fetch semplice|api[ -]?(fetch|client|monitor|research|ingest)|feed[ -]?(reader|monitor|ingest)|rss|atom feed|api (esterna|remota|pubblica)|external (api|feed|url|endpoint)|endpoint (esterno|remoto)'
  indicator_files="$(find "$WS" -path "$WS/.git" -prune -o -type f -name '*.md' -exec grep -ilE "$indicators" {} + 2>/dev/null || true)"

  if [ "$indicator_files" = "" ]; then
    pass "no web-facing indicators found (web safety check not applicable)"
    return
  fi

  if grep -Eiq '(contenut[^.]*(dato|non fidat|inaffidabil)[^.]*(mai|non)[^.]*istruz|web content[^.]*(untrusted|data)[^.]*(not|never)[^.]*instruction|treat[^.]*content[^.]*(data|untrusted)[^.]*(not|never)[^.]*instruction)' "$agents" 2>/dev/null; then
    pass "web safety positively classifies external content as data, not instructions"
  else
    fail "web-facing workspace must positively classify external content as untrusted data, never instructions"
    semantic_failures=$((semantic_failures + 1))
  fi

  if grep -Eiq '(non (eseguire|esegue|seguire|obbedire|agire)|non pu[oò] modificare|do not (execute|follow|obey|act)|never (execute|follow|obey|act)|cannot (change|modify))' "$agents" 2>/dev/null; then
    pass "web safety forbids acting on instructions found in content"
  else
    fail "web-facing workspace must forbid executing or following content-supplied instructions"
    semantic_failures=$((semantic_failures + 1))
  fi

  if grep -Eiq '(prompt[ -]?injection[^.]*(scart|ignor|segnal|logg|non agire|reject|ignore|report|quarantin)|(scart|ignor|segnal|logg|non agire|reject|ignore|report|quarantin)[^.]*prompt[ -]?injection)' "$agents" 2>/dev/null; then
    pass "web safety defines a positive prompt-injection response"
  else
    fail "web-facing workspace must identify prompt injection and define reject/ignore/report handling"
    semantic_failures=$((semantic_failures + 1))
  fi

  if [ "$semantic_failures" -eq 0 ]; then
    pass "web-facing workspace has semantic anti-injection safeguards"
  fi
}

check_research() {
  local file="$WS/RESEARCH.md"
  local rel="RESEARCH.md"

  if [ ! -e "$file" ]; then
    pass "RESEARCH.md omitted (allowed when discovery was trivial or not applicable)"
    return
  fi

  if [ ! -s "$file" ]; then
    fail "RESEARCH.md is empty"
    return
  fi

  check_nonempty_section "$file" "$rel" "commands executed" '^#+[[:space:]]+(comandi eseguiti|commands executed)([[:space:]]|$)'
  check_nonempty_section "$file" "$rel" "incomplete-discovery status" '^#+[[:space:]]+(discovery incompleta|incomplete discovery)([[:space:]]|$)'

  if section_has_pattern "$file" '^#+[[:space:]]+(comandi eseguiti|commands executed)([[:space:]]|$)' '`[^`]+`|```(bash|sh|shell)?'; then
    pass "RESEARCH.md records exact commands"
  else
    fail "RESEARCH.md commands section must contain exact commands in code formatting"
  fi

  if grep -Eiq '(cercat|searched|query|obiettivo[^\n]*discovery|capacità richiesta|capacita richiesta)' "$file"; then
    pass "RESEARCH.md documents what was searched"
  else
    fail "RESEARCH.md must document what was searched"
  fi

  if grep -Eiq '(trovat|found|risultat|results?|esito)' "$file"; then
    pass "RESEARCH.md documents what was found"
  else
    fail "RESEARCH.md must document what was found"
  fi

  if grep -Eiq '(scelt|chosen|selected|adottat)' "$file"; then
    pass "RESEARCH.md documents selected options"
  else
    fail "RESEARCH.md must document selected options"
  fi

  if grep -Eiq '(scart|reject|discard|non adottat)' "$file"; then
    pass "RESEARCH.md documents rejected options"
  else
    fail "RESEARCH.md must document rejected options"
  fi

  if grep -Eiq '(motiv|perch[eé]|because|reason|decisione)' "$file"; then
    pass "RESEARCH.md records decision rationale"
  else
    fail "RESEARCH.md must record rationale for choices and rejections"
  fi

  if grep -Eq '`?bash[[:space:]]+scripts/discover\.sh[[:space:]]+' "$file"; then
    pass "RESEARCH.md records the mandatory discover.sh pass"
  else
    fail "RESEARCH.md must record the exact bash scripts/discover.sh command"
  fi
}

valid_utc_timestamp() {
  local timestamp="$1"
  local parsed=""

  parsed="$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$timestamp" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"
  if [ "$parsed" = "$timestamp" ]; then
    return 0
  fi

  parsed="$(date -u -d "$timestamp" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || true)"
  [ "$parsed" = "$timestamp" ]
}

check_generation_report() {
  local file="$1"
  local kind="$2"
  local compact_timestamp="$3"
  local rel="${file#$WS/}"
  local expected_timestamp
  local factory_state
  local validation_heading='^#+[[:space:]]+(validazione|validation)([[:space:]]|$)'

  expected_timestamp="${compact_timestamp:0:10}T${compact_timestamp:11:2}:${compact_timestamp:13:2}:${compact_timestamp:15:2}Z"

  check_nonempty_section "$file" "$rel" "objective" '^#+[[:space:]]+(obiettivo|obiettivo dell.aggiornamento|objective)([[:space:]]|$)'
  check_nonempty_section "$file" "$rel" "workspace" '^#+[[:space:]]+workspace([[:space:]]|$)'
  check_nonempty_section "$file" "$rel" "selected blueprint" '^#+[[:space:]]+(blueprint scelto|selected blueprint)([[:space:]]|$)'
  check_nonempty_section "$file" "$rel" "capability coverage" '^#+[[:space:]]+(copertura delle capacit[aà]|capability coverage|capabilities coverage)([[:space:]]|$)'
  check_nonempty_section "$file" "$rel" "files changed" '^#+[[:space:]]+(file creati|file modificati|files created|files modified)([[:space:]]|$)'
  if [ "$kind" = "update" ]; then
    check_nonempty_section "$file" "$rel" "unchanged scope" '^#+[[:space:]]+(cosa e. rimasto invariato|ambito invariato|unchanged scope|what remained unchanged)([[:space:]]|$)'
  fi
  check_nonempty_section "$file" "$rel" "discovery" '^#+[[:space:]]+discovery([[:space:]]|$)'
  check_nonempty_section "$file" "$rel" "assumptions" '^#+[[:space:]]+(assunzioni|assumptions)([[:space:]]|$)'
  check_nonempty_section "$file" "$rel" "validation" "$validation_heading"
  check_nonempty_section "$file" "$rel" "limits/follow-up" '^#+[[:space:]]+(limiti o follow-up|limiti|limits or follow-up|limits|follow-up)([[:space:]]|$)'
  check_nonempty_section "$file" "$rel" "factory lessons" '^#+[[:space:]]+(lezioni per la fabbrica|factory lessons)([[:space:]]|$)'

  if section_has_pattern "$file" "$validation_heading" '(^|[[:space:]`])(bash|sh|git|jq|npm|pnpm|yarn|python[0-9.]*|pytest|make|just)[[:space:]]+[^[:space:]]'; then
    pass "$rel validation section records an exact command"
  else
    fail "$rel validation section must record an exact command"
  fi
  if section_has_pattern "$file" "$validation_heading" '(pass|fail|exit[ -]?(code|status)|rc[[:space:]]*[:=][[:space:]]*[0-9]+)'; then
    pass "$rel validation section records an observable outcome"
  else
    fail "$rel validation section must record PASS/FAIL or an exit code"
  fi

  if grep -Eiq '^Fabbrica:[[:space:]]+commit[[:space:]]+`?[0-9a-f]{7,40}`?([[:space:]]*,[[:space:]]*ottenuto con:)?[[:space:]]*$|^Factory:[[:space:]]+commit[[:space:]]+`?[0-9a-f]{7,40}`?([[:space:]]*,[[:space:]]*obtained with:)?[[:space:]]*$' "$file"; then
    pass "$rel records a concrete factory commit"
  else
    fail "$rel must record a concrete 7-40 character factory commit"
  fi

  factory_state="$(awk '
    tolower($0) ~ /^(stato fabbrica|factory status):/ {
      line = tolower($0)
      gsub(/[` .]/, "", line)
      sub(/^(statofabbrica|factorystatus):/, "", line)
      print line
      exit
    }
  ' "$file")"
  case "$factory_state" in
    clean)
      pass "$rel records factory status clean"
      ;;
    dirty)
      pass "$rel records factory status dirty"
      if grep -Eiq '^(Path modificati nella fabbrica|Changed factory paths):[[:space:]]*[^[:space:]]' "$file" \
          && grep -Eiq '(commit non descrive esattamente|commit does not exactly describe)' "$file"; then
        pass "$rel explains dirty factory provenance"
      else
        fail "$rel dirty factory status requires changed paths and an inexact-commit disclosure"
      fi
      ;;
    *)
      fail "$rel must record Stato fabbrica/Factory status as clean or dirty"
      ;;
  esac

  if ! valid_utc_timestamp "$expected_timestamp"; then
    fail "$rel filename contains an impossible UTC date or time"
  elif grep -Fq "Timestamp UTC: \`$expected_timestamp\`" "$file"; then
    pass "$rel UTC timestamp matches its filename"
  else
    fail "$rel must contain Timestamp UTC: \`$expected_timestamp\` matching its filename"
  fi
}

check_generation_reports() {
  local file
  local base
  local kind
  local compact_timestamp
  local numeric_suffix
  local latest_file=""
  local latest_kind=""
  local latest_timestamp=""
  local latest_suffix=0
  local count=0

  if [ ! -d "$WS/reports" ]; then
    return
  fi

  while IFS= read -r -d '' file; do
    base="$(basename "$file")"
    if [[ ! "$base" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6})(-([1-9][0-9]*))?-(generation|update)\.md$ ]]; then
      continue
    fi

    count=$((count + 1))
    compact_timestamp="${BASH_REMATCH[1]}"
    numeric_suffix="${BASH_REMATCH[3]:-1}"
    kind="${BASH_REMATCH[4]}"
    if [ "$latest_timestamp" = "" ] \
        || [[ "$compact_timestamp" > "$latest_timestamp" ]] \
        || { [ "$compact_timestamp" = "$latest_timestamp" ] && [ "$numeric_suffix" -gt "$latest_suffix" ]; }; then
      latest_file="$file"
      latest_kind="$kind"
      latest_timestamp="$compact_timestamp"
      latest_suffix="$numeric_suffix"
    fi
  done < <(find "$WS/reports" -maxdepth 1 -type f -name '*.md' -print0)

  if [ "$count" -eq 0 ]; then
    fail "reports/ must contain a YYYY-MM-DD-HHMMSS[-N]-generation.md or update report"
  else
    check_generation_report "$latest_file" "$latest_kind" "$latest_timestamp"
    pass "current report validated; $count formal generation/update report(s) preserved"
  fi
}

printf 'Validating workspace at %s\n' "$WS"

require_file "README.md"
require_file "AGENTS.md"
require_dir "skills"
require_dir "reports"

check_symlinks
check_doc_basics "README.md"
check_doc_basics "AGENTS.md"
check_readme_setup
check_skill_files
check_research
check_generation_reports
check_markdown_references
check_placeholders
check_local_paths
check_secret_patterns
check_web_safety

finish
