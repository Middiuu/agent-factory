# {{AGENT_NAME}}

Workspace agentico generato per:

```text
{{USER_GOAL}}
```

## Cosa fa

{{AGENT_NAME}} aiuta il coding agent a eseguire procedure specifiche del progetto usando istruzioni Markdown, eventuali skill locali e tool verificati.

Blueprint scelto: `{{SELECTED_BLUEPRINT}}`.

## Quickstart

1. Apri questo workspace con un coding agent che legge `AGENTS.md`.
2. Descrivi il task da svolgere.
3. Il coding agent applica una skill locale solo se presente e pertinente; altrimenti usa le capacita' native documentate in `AGENTS.md`.
4. Gli output vengono salvati in `reports/` quando il task produce un report o un log.

## Setup obbligatorio

{{REQUIRED_TOOLS}}

## Setup opzionale

{{OPTIONAL_TOOLS}}

## Struttura

```text
{{WORKSPACE_NAME}}/
├── README.md
├── AGENTS.md
├── skills/
├── reports/
{{OPTIONAL_FILES}}
```

`skills/` puo' essere vuota quando la discovery dimostra che le capacita' native coprono interamente il lavoro.

## Output attesi

{{EXPECTED_OUTPUTS}}

## Assunzioni

{{ASSUMPTIONS}}

## Validazione

Controllo autonomo minimo dalla root del workspace:

```bash
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$PWD}"
test -f "$WORKSPACE_ROOT/README.md"
test -f "$WORKSPACE_ROOT/AGENTS.md"
test -d "$WORKSPACE_ROOT/skills"
test -d "$WORKSPACE_ROOT/reports"
```

Workspace validato in generazione con `validate-workspace.sh` di agent-factory. Risultato: {{VALIDATION_RESULT}}.

Se agent-factory è disponibile sulla macchina, la validazione è ripetibile dalla sua root con:

```bash
FACTORY_ROOT="${FACTORY_ROOT:?set FACTORY_ROOT to the agent-factory repository}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$PWD}"
bash "$FACTORY_ROOT/scripts/validate-workspace.sh" "$WORKSPACE_ROOT"
```

Questo workspace resta comunque autonomo: la validazione è un controllo di qualità, non una dipendenza.
