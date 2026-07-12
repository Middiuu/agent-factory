# Markdown File Organizer

Workspace minimale per un coding agent che rinomina e organizza file Markdown locali.

## Setup obbligatorio

Non sono richiesti setup, dipendenze, servizi o tool esterni. Sono sufficienti le capacità native del coding agent e le normali operazioni sul filesystem locale.

## Setup opzionale

Nessuno. Eventuali convenzioni di nomina o categorie possono essere fornite direttamente nel prompt dell'attività.

## Quickstart

1. Avvia il coding agent con questo workspace come contesto di istruzioni.
2. Indica esplicitamente la directory locale da organizzare e il criterio desiderato, se già noto.
3. Esamina il piano `origine -> destinazione` proposto dall'agente.
4. Conferma il piano per applicare le rinomine e gli spostamenti.
5. Controlla il riepilogo finale e gli eventuali conflitti rimasti.

L'agente lavora in anteprima per impostazione predefinita, non modifica i contenuti e non sovrascrive o elimina file.

## Output attesi

- Un piano verificabile `origine -> destinazione` prima delle modifiche.
- I file Markdown rinominati o spostati dopo approvazione.
- Un riepilogo finale di operazioni, file ignorati, conflitti e verifiche.

## Contenuto

- `AGENTS.md`: contratto operativo dell'agente.
- `skills/`: directory intenzionalmente vuota, perché non servono skill locali.
- `reports/`: report delle attività di generazione o aggiornamento del workspace.
