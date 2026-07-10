# Workspace subagent test - 2026-07-07

## Obiettivo

Testare i workspace generabili da agent-factory con un workflow a subagent, individuare problemi sistemici e applicare miglioramenti professionali senza introdurre runtime, framework o dipendenze non necessarie.

## Workflow con subagent

Sono stati avviati tre subagent indipendenti:

- Planck: fixture temporanee research e automation.
- Volta: fixture temporanee web dev e mobile dev.
- Locke: revisione sistemica di script, template e validatori.

I subagent non hanno modificato il repository. Hanno creato fixture in directory temporanee esterne, poi rimosse, e hanno riportato comandi, risultati e rischi senza conservarne i path macchina-specifici.

## Workspace testati

- `research-agent`
- `automation-agent`
- `react-app-agent`
- `flutter-app-agent`

Le fixture positive sono state validate con:

```bash
bash scripts/validate-workspace.sh <fixture>
```

## Problemi sistemici trovati

- `validate-workspace.sh` intercettava falsi positivi sui segreti: il pattern `sk-` colpiva nomi innocui come `task-runner`.
- Il frontmatter delle skill era troppo permissivo: bastava una prima riga `---`; non veniva richiesta la chiusura del blocco.
- I placeholder non compilati come `<AGENT_NAME>` non venivano bloccati.
- Path assoluti locali come `/Users/...` potevano finire nei workspace senza essere segnalati.
- File root extra non vietati esplicitamente, ad esempio `notes.md`, potevano passare nonostante il contratto del workspace sia minimale.
- `templates/workspace-README.md` mostrava `RESEARCH.md` come sempre presente, anche se e' opzionale.
- `validate-factory.sh` controllava la presenza dei template ma non che fossero non vuoti o contenessero placeholder chiave.

## Miglioramenti applicati

- Rafforzata la validazione frontmatter in `scripts/validate-factory.sh` e `scripts/validate-workspace.sh`: il blocco deve aprirsi e chiudersi con `---`, e `name`/`description` sono letti dal frontmatter.
- Raffinata la scansione segreti: fallisce su pattern ad alta confidenza o assegnazioni sospette, ma permette placeholder documentali come `<your-api-key>` o `${VAR}`.
- Aggiunta rilevazione di placeholder non compilati nei workspace.
- Aggiunta rilevazione di path assoluti locali nei workspace.
- Aggiunta whitelist leggera dei file/cartelle ammessi nella root del workspace.
- Rafforzata la validazione dei template della fabbrica: presenza, non-vuoto e placeholder chiave.
- Aggiornato `templates/workspace-README.md` per usare `<OPTIONAL_FILES>` invece di promettere sempre `RESEARCH.md`.
- Aggiornato il comando di validazione nel template README per evitare path assoluti della macchina locale.
- Aggiornato `README.md` per descrivere i controlli effettivi di `validate-workspace.sh`.

## Validazione eseguita

Comandi finali eseguiti:

```bash
bash -n scripts/validate-factory.sh
bash -n scripts/validate-workspace.sh
bash scripts/validate-factory.sh
RESEARCH_FIXTURE_ROOT="${RESEARCH_FIXTURE_ROOT:?historical temporary fixture root is no longer available}"
DEV_FIXTURE_ROOT="${DEV_FIXTURE_ROOT:?historical temporary fixture root is no longer available}"
bash scripts/validate-workspace.sh "$RESEARCH_FIXTURE_ROOT/research-agent"
bash scripts/validate-workspace.sh "$RESEARCH_FIXTURE_ROOT/automation-agent"
bash scripts/validate-workspace.sh "$DEV_FIXTURE_ROOT/react-app-agent"
bash scripts/validate-workspace.sh "$DEV_FIXTURE_ROOT/flutter-app-agent"
```

Fixture negative verificate:

- frontmatter malformato: fallisce;
- placeholder non compilato: fallisce;
- path assoluto locale: fallisce;
- file vietato `PLAN.md`: fallisce;
- segreto reale in stile `sk-...`: fallisce;
- placeholder documentale di API key: passa.

## Esito

Il workflow con subagent ha validato i quattro blueprint principali e ha prodotto miglioramenti concreti agli script e ai template. Il repository resta Markdown-first, minimale e senza nuove dipendenze.

## Lezioni per la fabbrica

- I validator leggeri devono restare sobri, ma devono bloccare difetti strutturali realmente osservati: frontmatter incompleto, placeholder residui, path locali e file root fuori contratto.
- I template devono evitare di trasformare file opzionali in promesse implicite.
- I controlli anti-segreti devono distinguere documentazione sicura da valori credibili, altrimenti impediscono README corretti.
- Il test con subagent su fixture temporanee e' utile per coprire blueprint diversi senza trasformare agent-factory in una suite pesante.
