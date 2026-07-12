# Synthetic research seed

Workspace sintetico esistente per ricerca web documentata, verifica delle fonti e report Markdown citati. È un input delle eval, non una configurazione production.

## Quickstart

1. Leggi `AGENTS.md`.
2. Formula una domanda verificabile e una data limite.
3. Usa `skills/web-research/SKILL.md` per raccogliere e verificare le fonti.
4. Compila il registro di qualità delle fonti descritto sotto.
5. Apri il report con il formato executive summary descritto sotto.
6. Salva il report finale in `reports/` senza riscrivere report precedenti.

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

Report Markdown con domanda, executive summary, claim citati, registro di qualità delle fonti, disaccordi, limiti e data della ricerca.

## Formato executive summary

La prima sezione del corpo del report deve essere `## Executive summary` e contenere, nell'ordine:

- **Risposta breve:** 2-3 frasi che rispondono direttamente alla domanda;
- **Evidenze decisive:** 2-4 punti, ciascuno con citazione;
- **Implicazioni:** 1-3 punti rilevanti per la decisione o il lettore;
- **Confidenza e limiti:** livello `alta`, `media` o `bassa`, con il principale limite che lo determina.

Il dettaglio delle evidenze, i disaccordi e l'elenco completo delle fonti seguono l'executive summary.

## Controllo qualità delle fonti

Per ogni fonte usata, il report include una riga con URL o identificatore di citazione, claim supportato, punteggi `0-2` per provenienza, supporto diretto, attualità e indipendenza, totale `0-8`, classe e note.

- `7-8`: qualità `alta`;
- `4-6`: qualità `media`;
- `0-3`: qualità `bassa`.

Una fonte con `0` in provenienza o supporto diretto non può sostenere un claim centrale. Un claim decisivo richiede almeno una fonte di qualità alta oppure due fonti almeno medie e indipendenti; se la soglia non è raggiunta, va marcato `[incerto]`.

## Validazione

Dalla root del workspace:

```bash
test -f README.md
test -f AGENTS.md
test -f RESEARCH.md
test -f skills/web-research/SKILL.md
test -d reports
```
