# Organizzatore di file Markdown

Workspace agentico minimale per rinominare e organizzare file Markdown locali in modo controllato.

## Cosa fa

L'agente inventaria i file `.md` nella cartella indicata, propone una mappa `origine → destinazione`, rileva collisioni, applica gli spostamenti approvati e aggiorna i link Markdown relativi resi obsoleti dalle modifiche.

Blueprint scelto: `workspace-blueprint-minimal.md`.

## Quickstart

1. Apri questo workspace con un coding agent che legge `AGENTS.md`.
2. Indica la cartella locale da organizzare e la convenzione desiderata per nomi e sottocartelle.
3. Esamina il piano `origine → destinazione` e confermalo.
4. Ricevi i file riorganizzati e un riepilogo dei controlli eseguiti.

## Setup obbligatorio

Serve soltanto un coding agent con capacità native di lettura, ricerca, modifica e spostamento di file locali. La cartella bersaglio deve essere accessibile in lettura e scrittura.

Non sono richiesti tool esterni, dipendenze, skill locali o servizi di rete.

## Setup opzionale

Nessuno.

## Struttura

```text
markdown-file-organizer/
├── README.md
├── AGENTS.md
├── skills/
└── reports/
```

`skills/` resta intenzionalmente vuota: le capacità native del coding agent coprono l'intero flusso.

## Output attesi

- file Markdown rinominati o spostati soltanto dentro la radice autorizzata;
- link Markdown relativi aggiornati quando uno spostamento ne cambia la destinazione;
- riepilogo finale con mappa applicata, collisioni evitate, file non modificati e limiti incontrati;
- eventuale report persistente in `reports/` solo quando richiesto.

## Assunzioni

- L'ambito predefinito comprende soltanto file regolari con estensione `.md`.
- L'utente fornisce la radice bersaglio e la convenzione di organizzazione; se una delle due manca, l'agente chiede chiarimenti prima di spostare file.
- Nessun file viene eliminato o sovrascritto implicitamente.
- Il contenuto resta invariato, salvo gli aggiornamenti strettamente necessari ai link relativi.

## Validazione

Controllo autonomo minimo dalla root del workspace:

```bash
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$PWD}"
test -f "$WORKSPACE_ROOT/README.md"
test -f "$WORKSPACE_ROOT/AGENTS.md"
test -d "$WORKSPACE_ROOT/skills"
test -d "$WORKSPACE_ROOT/reports"
```

Workspace validato in generazione con `validate-workspace.sh` di agent-factory. Il risultato osservato è riportato nel report di generazione.

Se agent-factory è disponibile sulla macchina, la validazione è ripetibile dalla sua root con:

```bash
FACTORY_ROOT="${FACTORY_ROOT:?set FACTORY_ROOT to the agent-factory repository}"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$PWD}"
bash "$FACTORY_ROOT/scripts/validate-workspace.sh" "$WORKSPACE_ROOT"
```

Il workspace resta autonomo: il validator è un controllo di qualità, non una dipendenza operativa.
