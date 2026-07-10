# {{AGENT_NAME}} - update

Timestamp UTC: `{{TIMESTAMP_UTC}}`

Nome file: `{{REPORT_FILENAME}}`

Fabbrica: commit `{{FACTORY_VERSION}}`, ottenuto con:

```bash
FACTORY_ROOT="${FACTORY_ROOT:?set FACTORY_ROOT to the agent-factory repository}"
git -C "$FACTORY_ROOT" rev-parse --short HEAD
git -C "$FACTORY_ROOT" status --short
```

Stato fabbrica: `{{FACTORY_STATUS}}`

{{FACTORY_DIRTY_DETAILS}}

## Obiettivo dell'aggiornamento

{{USER_GOAL}}

## Workspace

Identificatore: `{{WORKSPACE_NAME}}`.

La posizione assoluta della macchina di aggiornamento non viene persistita.

## Blueprint scelto

`{{SELECTED_BLUEPRINT}}`

## Copertura delle capacità

{{CAPABILITY_COVERAGE}}

## File modificati

{{MODIFIED_FILES}}

## Cosa e' rimasto invariato

{{UNCHANGED_SCOPE}}

## Discovery

{{DISCOVERY_SUMMARY}}

## Assunzioni

{{ASSUMPTIONS}}

## Validazione

Comando eseguito:

{{VALIDATION_COMMAND}}

Esito osservato (`PASS`/`FAIL` ed exit code):

{{VALIDATION_RESULT}}

## Limiti o follow-up

{{FOLLOW_UP}}

## Lezioni per la fabbrica

{{FACTORY_LESSONS}}
