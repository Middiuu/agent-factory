---
name: report-writer
description: Use this skill when turning research notes into a sourced Markdown report.
---

# Report Writer

## Procedura

1. Apri con la domanda di ricerca e una sintesi di massimo 5 righe.
2. Organizza i risultati per sezioni tematiche con heading `##`.
3. Collega ogni claim importante a una fonte con URL; i claim senza fonte restano marcati `[incerto]`.
4. Chiudi con tre sezioni obbligatorie: `## Limiti`, `## Data della ricerca`, `## Fonti`.
5. Imposta `WORKSPACE_ROOT="${WORKSPACE_ROOT:-$PWD}"` e uno slug in `TOPIC_SLUG`, calcola `RUN_TIMESTAMP="$(date -u '+%Y-%m-%d-%H%M%S')"` e salva il report in `REPORT_FILE="$WORKSPACE_ROOT/reports/${RUN_TIMESTAMP}-${TOPIC_SLUG}.md"`.

## Validazione

- `REPORT_FILE="${REPORT_FILE:?set REPORT_FILE to the generated report}"; test "$(grep -c 'http' "$REPORT_FILE")" -gt 0` passa e la sezione Fonti elenca tutti gli URL citati.
- `grep '^## ' "$REPORT_FILE"` mostra le tre sezioni di chiusura.
