#!/usr/bin/env bash

# Unified, reproducible discovery for skills, MCP servers and CLI packages.
# Every external source has a bounded timeout. "No result" is reported only
# when the source answered successfully; transport and HTTP failures are kept
# distinct so RESEARCH.md never turns an outage into a false absence claim.

set -uo pipefail

QUERY="${1:-}"
KIND="${2:-all}"
DISCOVER_TIMEOUT="${DISCOVER_TIMEOUT:-20}"

if [ "$QUERY" = "" ]; then
  printf 'Uso: bash scripts/discover.sh "<termine>" [skill|mcp|cli|all]\n' >&2
  exit 2
fi

case "$KIND" in
  skill|mcp|cli|all) ;;
  *)
    printf 'Tipo non valido: %s (usa skill|mcp|cli|all)\n' "$KIND" >&2
    exit 2
    ;;
esac

if ! printf '%s\n' "$DISCOVER_TIMEOUT" | grep -Eq '^[1-9][0-9]*$'; then
  printf 'DISCOVER_TIMEOUT deve essere un numero intero positivo (ricevuto: %s).\n' "$DISCOVER_TIMEOUT" >&2
  exit 2
fi

HAVE_JQ=0
if [ "${DISCOVER_FORCE_NO_JQ:-0}" != "1" ] && command -v jq >/dev/null 2>&1; then
  HAVE_JQ=1
fi

HTTP_BODY=""
HTTP_STATUS="000"
HTTP_RC=0

header() {
  printf '\n## %s\n\n' "$1"
}

shell_quote() {
  printf '%q' "$1"
}

cmd_note() {
  printf 'Comando (registralo in RESEARCH.md): `%s`\n\n' "$1"
}

source_reachable() {
  printf 'STATO FONTE: raggiungibile — %s\n' "$1"
}

source_unreachable() {
  local source="$1"
  local detail="$2"

  printf 'FONTE NON RAGGIUNGIBILE: %s (%s)\n' "$source" "$detail"
  printf 'Registra in RESEARCH.md che la discovery e'\'' incompleta per questa fonte.\n'
}

no_results() {
  printf 'NESSUN RISULTATO: %s — %s\n' "$1" "$2"
}

package_absent() {
  printf 'PACCHETTO ASSENTE: %s — %s\n' "$1" "$2"
}

urlencode() {
  local value="$1"
  local encoded=""
  local char
  local hex
  local i
  local LC_ALL=C

  for ((i = 0; i < ${#value}; i++)); do
    char="${value:i:1}"
    case "$char" in
      [a-zA-Z0-9.~_-]) encoded="${encoded}${char}" ;;
      *)
        printf -v hex '%02X' "'$char"
        encoded="${encoded}%${hex}"
        ;;
    esac
  done

  printf '%s' "$encoded"
}

run_with_timeout() {
  local seconds="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    command timeout "$seconds" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    command gtimeout "$seconds" "$@"
  elif command -v perl >/dev/null 2>&1; then
    command perl -e '
      my $seconds = shift @ARGV;
      $SIG{ALRM} = sub { exit 124 };
      alarm $seconds;
      exec @ARGV or exit 126;
    ' "$seconds" "$@"
  else
    printf 'ATTENZIONE: nessun runner timeout disponibile; comando non eseguito: %s\n' "$1" >&2
    return 125
  fi
}

http_fetch() {
  local response
  local rc
  local separator=$'\n'

  HTTP_BODY=""
  HTTP_STATUS="000"
  HTTP_RC=0

  response="$(curl --max-time "$DISCOVER_TIMEOUT" -sS -w $'\n%{http_code}' "$@" 2>/dev/null)"
  rc=$?
  HTTP_RC="$rc"

  if [ "$response" != "" ] && [ "${response#*"$separator"}" != "$response" ]; then
    HTTP_STATUS="${response##*"$separator"}"
    HTTP_BODY="${response%"$separator"*}"
  fi

  [ "$rc" -eq 0 ]
}

http_failure_detail() {
  if [ "$HTTP_RC" -eq 28 ] || [ "$HTTP_RC" -eq 124 ]; then
    printf 'timeout dopo %ss' "$DISCOVER_TIMEOUT"
  elif [ "$HTTP_RC" -ne 0 ]; then
    printf 'errore di trasporto curl %s' "$HTTP_RC"
  elif [ "$HTTP_STATUS" != "000" ]; then
    printf 'HTTP %s' "$HTTP_STATUS"
  else
    printf 'risposta non valida'
  fi
}

http_is_success() {
  [ "$HTTP_RC" -eq 0 ] && printf '%s\n' "$HTTP_STATUS" | grep -Eq '^2[0-9][0-9]$'
}

discover_skills() {
  local source="GitHub skill registry"
  local url="https://api.github.com/repos/anthropics/skills/contents/skills"
  local names=""
  local matches=""
  local curl_args=()

  header "Skill registry — github.com/anthropics/skills"
  cmd_note "curl --max-time $DISCOVER_TIMEOUT $(shell_quote "$url") | jq -r '.[].name'"

  if [ "${GITHUB_TOKEN:-}" != "" ]; then
    curl_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
    printf 'Autenticazione: header derivato da GITHUB_TOKEN (valore non stampato).\n'
  fi

  if [ "${#curl_args[@]}" -gt 0 ]; then
    http_fetch "${curl_args[@]}" "$url" || true
  else
    http_fetch "$url" || true
  fi
  if ! http_is_success; then
    source_unreachable "$source" "$(http_failure_detail)"
    return
  fi
  source_reachable "$source"

  if [ "$HAVE_JQ" -eq 1 ]; then
    if ! printf '%s\n' "$HTTP_BODY" | jq -e 'type == "array"' >/dev/null 2>&1; then
      source_unreachable "$source" "JSON non valido o schema inatteso"
      return
    fi
    names="$(printf '%s\n' "$HTTP_BODY" | jq -r '.[].name' 2>/dev/null || true)"
  else
    printf 'jq non disponibile: parsing minimale dei campi name.\n'
    names="$(printf '%s\n' "$HTTP_BODY" | grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]+"' | sed 's/.*:[[:space:]]*"//; s/"$//' || true)"
  fi

  matches="$(printf '%s\n' "$names" | grep -iF -- "$QUERY" || true)"

  if [ "$matches" != "" ]; then
    printf 'Skill che corrispondono a "%s" nel nome:\n\n%s\n' "$QUERY" "$matches"
  else
    no_results "$source" "nessun nome contiene \"$QUERY\" ($(printf '%s\n' "$names" | grep -c . || true) nomi esaminati)"
    printf 'Il match e'\'' solo sul nome: per cercare nel contenuto usa la ricerca web di fallback.\n'
  fi
}

discover_mcp() {
  local source="registry MCP ufficiale"
  local encoded
  local url
  local results=""

  encoded="$(urlencode "$QUERY")"
  url="https://registry.modelcontextprotocol.io/v0.1/servers?search=${encoded}&limit=15"

  header "Registry MCP ufficiale — registry.modelcontextprotocol.io"
  cmd_note "curl --max-time $DISCOVER_TIMEOUT $(shell_quote "$url") | jq -r '.servers[].server | \"\\(.name) — \\(.description)\"' | sort -u"

  http_fetch "$url" || true
  if ! http_is_success; then
    source_unreachable "$source" "$(http_failure_detail); l'endpoint /v0.1 potrebbe essere cambiato"
    return
  fi
  source_reachable "$source"

  if [ "$HAVE_JQ" -eq 1 ]; then
    if ! printf '%s\n' "$HTTP_BODY" | jq -e '.servers | type == "array"' >/dev/null 2>&1; then
      source_unreachable "$source" "JSON non valido o schema inatteso"
      return
    fi
    results="$(printf '%s\n' "$HTTP_BODY" | jq -r '.servers[].server | "\(.name) — \(.description)"' 2>/dev/null | sort -u || true)"
  else
    printf 'jq non disponibile: risposta JSON grezza (massimo 2000 caratteri).\n'
    results="${HTTP_BODY:0:2000}"
  fi

  if [ "$results" != "" ] && [ "$results" != "[]" ] && [ "$results" != '{"servers":[]}' ]; then
    printf '%s\n' "$results"
  else
    no_results "$source" "query \"$QUERY\""
    printf 'La ricerca full-text del registry e'\'' debole: riprova con termini singoli o sinonimi.\n'
  fi

  printf '\nSeconda scelta (comunita'\''): smithery.ai, mcp.so, glama.ai/mcp/servers.\n'
}

discover_brew() {
  local output
  local rc
  local query_q

  command -v brew >/dev/null 2>&1 || return

  printf '\n### Homebrew\n\n'
  query_q="$(shell_quote "$QUERY")"
  cmd_note "DISCOVER_TIMEOUT=$DISCOVER_TIMEOUT HOMEBREW_NO_AUTO_UPDATE=1 brew search -- $query_q"

  output="$(run_with_timeout "$DISCOVER_TIMEOUT" env HOMEBREW_NO_AUTO_UPDATE=1 brew search -- "$QUERY" 2>&1)"
  rc=$?

  if [ "$rc" -eq 0 ]; then
    source_reachable "Homebrew"
    if [ "$output" = "" ]; then
      no_results "Homebrew" "query \"$QUERY\""
    else
      printf '%s\n' "$output" | awk 'NR <= 15'
    fi
  elif [ "$rc" -eq 124 ]; then
    source_unreachable "Homebrew" "timeout dopo ${DISCOVER_TIMEOUT}s"
  elif printf '%s\n' "$output" | grep -Eiq 'no formula|no cask|no results|nothing found'; then
    source_reachable "Homebrew"
    no_results "Homebrew" "query \"$QUERY\""
  else
    source_unreachable "Homebrew" "comando terminato con exit $rc"
  fi
}

discover_npm() {
  local output
  local rc
  local query_q
  local encoded
  local downloads_url

  command -v npm >/dev/null 2>&1 || return

  printf '\n### npm (pacchetto esatto)\n\n'
  query_q="$(shell_quote "$QUERY")"
  cmd_note "npm --fetch-timeout=$((DISCOVER_TIMEOUT * 1000)) --fetch-retries=0 view -- $query_q name version description"

  output="$(run_with_timeout "$DISCOVER_TIMEOUT" npm \
    --fetch-timeout="$((DISCOVER_TIMEOUT * 1000))" \
    --fetch-retries=0 \
    view -- "$QUERY" name version description 2>&1)"
  rc=$?

  if [ "$rc" -eq 0 ]; then
    source_reachable "npm registry"
    printf '%s\n' "$output"
  elif [ "$rc" -eq 124 ]; then
    source_unreachable "npm registry" "timeout dopo ${DISCOVER_TIMEOUT}s"
    return
  elif printf '%s\n' "$output" | grep -Eiq '(E404|404 Not Found|is not in this registry)'; then
    source_reachable "npm registry"
    package_absent "npm" "$QUERY"
    return
  else
    source_unreachable "npm registry" "errore npm exit $rc (non classificato come assenza)"
    return
  fi

  encoded="$(urlencode "$QUERY")"
  downloads_url="https://api.npmjs.org/downloads/point/last-month/${encoded}"
  cmd_note "curl --max-time $DISCOVER_TIMEOUT $(shell_quote "$downloads_url")"
  http_fetch "$downloads_url" || true
  if http_is_success; then
    source_reachable "npm downloads API"
    printf '%s\n' "$HTTP_BODY"
    printf '(download ultimo mese: segnale di adozione reale)\n'
  elif [ "$HTTP_STATUS" = "404" ]; then
    source_reachable "npm downloads API"
    no_results "npm downloads API" "nessun conteggio per $QUERY"
  else
    source_unreachable "npm downloads API" "$(http_failure_detail)"
  fi
}

discover_pypi() {
  local source="PyPI"
  local encoded
  local url

  encoded="$(urlencode "$QUERY")"
  url="https://pypi.org/pypi/${encoded}/json"

  printf '\n### PyPI (pacchetto esatto)\n\n'
  cmd_note "curl --max-time $DISCOVER_TIMEOUT $(shell_quote "$url") | jq -r '.info | \"\\(.name) \\(.version) — \\(.summary)\"'"

  http_fetch "$url" || true
  if http_is_success; then
    source_reachable "$source"
    if [ "$HAVE_JQ" -eq 1 ]; then
      if ! printf '%s\n' "$HTTP_BODY" | jq -e '.info.name and .info.version' >/dev/null 2>&1; then
        source_unreachable "$source" "JSON non valido o schema inatteso"
        return
      fi
      printf '%s\n' "$HTTP_BODY" | jq -r '.info | "\(.name) \(.version) — \(.summary)"' 2>/dev/null
    else
      printf 'Pacchetto trovato (jq assente; dettagli nella risposta JSON).\n'
    fi
  elif [ "$HTTP_STATUS" = "404" ]; then
    source_reachable "$source"
    package_absent "$source" "$QUERY"
  else
    source_unreachable "$source" "$(http_failure_detail)"
  fi
}

discover_cli() {
  local query_q

  header "CLI e pacchetti"

  printf '### PATH locale\n\n'
  query_q="$(shell_quote "$QUERY")"
  cmd_note "command -v -- $query_q"
  if command -v -- "$QUERY" >/dev/null 2>&1; then
    printf 'Presente: `%s`\n' "$(command -v -- "$QUERY")"
  else
    printf 'Non presente nel PATH.\n'
  fi

  discover_brew
  discover_npm
  discover_pypi
}

printf '# Discovery: "%s" (%s) — %s\n' "$QUERY" "$KIND" "$(date +%Y-%m-%d)"
printf 'Timeout per fonte/comando: %ss (configurabile con DISCOVER_TIMEOUT).\n' "$DISCOVER_TIMEOUT"

case "$KIND" in
  skill) discover_skills ;;
  mcp) discover_mcp ;;
  cli) discover_cli ;;
  all)
    discover_skills
    discover_mcp
    discover_cli
    ;;
esac

printf '\n---\n'
printf 'Promemoria: (1) questo script non vede le skill gia'\'' installate nel coding agent; '
printf '(2) ogni candidato va verificato per manutenzione e adozione prima di adottarlo; '
printf '(3) fonti non raggiungibili = discovery incompleta da dichiarare in RESEARCH.md.\n'
