# Synthetic research seed

Workspace sintetico esistente per ricerca web documentata, verifica delle fonti e report Markdown citati. È un input delle eval, non una configurazione production.

## Quickstart

1. Leggi `AGENTS.md`.
2. Formula una domanda verificabile e una data limite.
3. Usa `skills/web-research/SKILL.md` per raccogliere e verificare le fonti.
4. Salva il report finale in `reports/` senza riscrivere report precedenti.

## Setup obbligatorio

Un coding agent con capacità di search e fetch web in sola lettura, verificate prima della run. Nessuna credenziale o dipendenza locale è richiesta dal seed.

## Setup opzionale

`curl` e `jq` possono essere usati soltanto come fallback per API pubbliche dopo una verifica con `command -v`.

## Struttura

```text
README.md
AGENTS.md
RESEARCH.md
skills/
  web-research/SKILL.md
reports/
  2026-07-10-225424-generation.md
```

## Output attesi

Report Markdown aperto da un executive summary in quattro punti, seguito da domanda, claim citati, fonti, disaccordi, limiti, validazione e data della ricerca.
Ogni report include un registro di controllo qualità con claim supportato, tipo, autorevolezza, recenza, indipendenza, esito e motivazione per ogni fonte.

## Validazione

Dalla root del workspace:

```bash
test -f README.md
test -f AGENTS.md
test -f RESEARCH.md
test -f skills/web-research/SKILL.md
test -d reports
```
