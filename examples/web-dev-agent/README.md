# web-dev-agent

Workspace esempio autonomo per guidare modifiche React e validarle senza confondere le istruzioni agentiche con il repository applicativo.

## Prompt iniziale

```text
Voglio un agente web dev che mi aiuti con una web app React, test e documentazione tecnica.
```

## Quickstart

1. Dalla root dell'app React, esegui `export APP_ROOT="$PWD"`.
2. Apri questo workspace nello stesso ambiente con un coding agent che legge `AGENTS.md`.
3. L'agente verifica `APP_ROOT`, rileva il package manager dal lockfile e usa le skill in `skills/`.
4. Codice e test restano in `APP_ROOT`; review ed esiti vengono salvati in `reports/` di questo workspace.

## Setup obbligatorio

- Un'app React esistente, indicata tramite `APP_ROOT` e contenente `package.json`.
- Node.js e il package manager gia' scelto dal repository.

Verifica, senza installazioni globali:

```bash
APP_ROOT="${APP_ROOT:?run export APP_ROOT from the application root}"
test -f "$APP_ROOT/package.json"
command -v node
node --version
```

Il lockfile determina il package manager: `pnpm-lock.yaml` usa `pnpm`, `yarn.lock` usa `yarn`, `package-lock.json` usa `npm`. Se nessun lockfile esiste, chiedi all'utente invece di crearne uno implicitamente.

## Setup opzionale

- Skill o tool di browser testing gia' disponibili nel coding agent, per flussi E2E richiesti.
- Playwright soltanto se e' gia' una dipendenza del progetto o se l'utente ne approva l'aggiunta locale in `APP_ROOT`.
- Nessun MCP e nessun deploy sono necessari per il flusso base.

## Struttura

```text
README.md
AGENTS.md
skills/
  react-dev/SKILL.md
  testing/SKILL.md
reports/
  2026-07-10-074530-generation.md
RESEARCH.md
```

## Output attesi

Codice e test nell'app indicata da `APP_ROOT`; report `reports/YYYY-MM-DD-HHMMSS-web-task.md` con file modificati, comandi, conteggi dei test, limiti ed eventuali verifiche saltate.

## Validazione autonoma

Dalla root del workspace agentico:

```bash
AGENT_WORKSPACE_ROOT="${AGENT_WORKSPACE_ROOT:-$PWD}"
APP_ROOT="${APP_ROOT:?set APP_ROOT before validation}"
test -f "$AGENT_WORKSPACE_ROOT/AGENTS.md"
test -f "$AGENT_WORKSPACE_ROOT/RESEARCH.md"
test -d "$AGENT_WORKSPACE_ROOT/skills"
test -d "$AGENT_WORKSPACE_ROOT/reports"
test -f "$APP_ROOT/package.json"
```
