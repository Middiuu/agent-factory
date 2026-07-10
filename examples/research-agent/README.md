# research-agent

Workspace esempio autonomo per ricerca web documentata e report Markdown con citazioni.

## Prompt iniziale

```text
Voglio un agente che faccia ricerche online, raccolga fonti affidabili e generi report Markdown con citazioni.
```

## Cosa fa

Il coding agent applica `skills/web-research/SKILL.md` per raccogliere evidenze e `skills/report-writer/SKILL.md` per trasformarle in un report verificabile. Le decisioni di tooling della generazione sono in `RESEARCH.md`.

## Setup obbligatorio

- Un coding agent capace di cercare e leggere pagine web, mostrare gli URL consultati e scrivere nel workspace.
- Nessuna dipendenza locale e nessuna credenziale sono richieste. Prima della prima ricerca verifica nell'inventario del coding agent che search e fetch siano disponibili; se manca una delle due capacita', fermati e scegli un fallback verificato.

## Setup opzionale

`curl` e `jq` servono soltanto come fallback per API pubbliche JSON. Verificali senza installazioni globali:

```bash
command -v curl
curl --version
command -v jq
jq --version
```

Se uno dei due manca, le capacita' native restano il percorso principale.

## Quickstart

1. Apri la root di questo workspace con un coding agent che legge `AGENTS.md`.
2. Formula una domanda di ricerca e specifica data limite, area geografica o fonti obbligatorie.
3. L'agente raccoglie le evidenze, applica entrambe le skill locali e salva il risultato in `reports/`.
4. Leggi nel report anche fonti discordanti, limiti e controlli eseguiti.

## Struttura

```text
README.md
AGENTS.md
RESEARCH.md
skills/
  web-research/SKILL.md
  report-writer/SKILL.md
reports/
  2026-07-10-074530-generation.md
```

## Output attesi

Report `reports/YYYY-MM-DD-HHMMSS-topic-slug.md` con domanda, sintesi, risultati, citazioni, limiti, data della ricerca e fonti.

## Validazione autonoma

Dalla root del workspace:

```bash
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$PWD}"
test -f "$WORKSPACE_ROOT/AGENTS.md"
test -f "$WORKSPACE_ROOT/RESEARCH.md"
test -f "$WORKSPACE_ROOT/skills/web-research/SKILL.md"
test -f "$WORKSPACE_ROOT/skills/report-writer/SKILL.md"
test -d "$WORKSPACE_ROOT/reports"
```
