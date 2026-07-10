# RESEARCH.md - {{AGENT_NAME}}

Workspace: `{{WORKSPACE_NAME}}`

Discovery completata: `{{TIMESTAMP_UTC}}`

Obiettivo:

```text
{{USER_GOAL}}
```

## Assunzioni

{{ASSUMPTIONS}}

## Cercato

| ID | Capacita' richiesta | Fonte | Query o verifica | Esito |
|---|---|---|---|---|
{{SEARCH_ROWS}}

## Trovato

{{FOUND_OPTIONS}}

## Scelto

{{SELECTED_TOOLS}}

Per ogni scelta indicare evidenza, versione o capacita' osservata, perche' copre il requisito e se e' obbligatoria oppure opzionale.

## Scartato

{{REJECTED_TOOLS}}

Per ogni scarto indicare il motivo verificabile: duplicazione di capacita' native, manutenzione, rischio, costo o mancata reperibilita'.

## Comandi eseguiti

{{DISCOVERY_COMMANDS}}

I comandi devono comparire nell'ordine reale di esecuzione e usare variabili shell dichiarate per URL, file e directory.

## Discovery incompleta

{{INCOMPLETE_DISCOVERY}}

## Note di sicurezza

{{SECURITY_NOTES}}
