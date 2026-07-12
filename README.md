# agent-factory

[![Validate](https://github.com/Middiuu/agent-factory/actions/workflows/validate.yml/badge.svg?branch=main)](https://github.com/Middiuu/agent-factory/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**agent-factory** è un Agent Workspace Builder Markdown-first: guida un coding agent nella generazione o nell'aggiornamento di workspace agentici specifici per progetto.

Non è un agente finale e non contiene runtime applicativo. La logica vive in istruzioni versionate; gli script shell e la CI sono tooling strumentale per discovery, validazione e governance.

Principi: minimale, verificabile, provider-aware senza dipendere da un singolo client, skill-driven quando serve, MCP/CLI-ready e safe by design. In caso di dubbio: meno file, meno tool, meno codice.

Il repository pubblico corrente è [Middiuu/agent-factory](https://github.com/Middiuu/agent-factory). La linea pubblica è stata ricreata il 2026-07-10 a partire dal commit radice `5b4ea50`; la pubblicazione e il primo gate CI sono documentati nel [report post-pubblicazione](reports/2026-07-10-remote-publication.md).

## Prerequisiti e permessi

Minimo necessario:

- un coding agent capace di leggere `AGENTS.md`, oppure istruito esplicitamente a farlo;
- accesso in lettura alla fabbrica e scrittura nella destinazione del workspace;
- Bash, Git, Python 3 e utility Unix di base;
- `curl` per la discovery di rete; `jq` è consigliato ma la discovery degrada senza;
- npm o Homebrew solo quando sono già presenti e pertinenti alla query.

La rete può essere assente: in quel caso la discovery resta incompleta e deve essere dichiarata, mai completata a memoria.

Il builder può usare la shell locale e creare una cartella sorella. Se i permessi lo impediscono, può creare temporaneamente il workspace dentro la fabbrica e segnalarne lo spostamento. Installazioni globali, azioni distruttive, spese, invii o accessi ampi richiedono sempre consenso esplicito.

## Quickstart

1. Apri questo repository con il coding agent.
2. Descrivi l'agente o il cambiamento desiderato.
3. Il coding agent legge la skill principale, sceglie un blueprint dall'indice, mappa le capacità e verifica skill/tool esistenti.
4. Crea il workspace fuori dalla fabbrica, salvo fallback dichiarato per permessi.
5. Produce un report timestampato, esegue validator e checklist, quindi registra soltanto feedback generalizzato e metadati opachi.

Esempio:

```text
Voglio un agente che faccia ricerche online, raccolga fonti affidabili e generi report Markdown con citazioni.
```

## Compatibilità basata sulle capacità

“Provider-aware” descrive un design portabile, non una garanzia universale. Il client deve poter leggere Markdown/frontmatter, lavorare sul filesystem, eseguire comandi shell e usare la rete quando la discovery lo richiede.

| Capacità | Stato |
|---|---|
| Lettura esplicita di `AGENTS.md` e `SKILL.md` | Portabile by design; auto-caricamento dipende dal client |
| Skill locali con frontmatter | Usabili come istruzioni; trigger automatico dipende dal client |
| Shell e filesystem | Necessari per generazione e gate meccanici |
| `.mcp.json` | Opzionale e client-specific; non è assunto come formato universale |
| Espansione `${VAR}` in configurazioni MCP | Verificare sul client; documentare sempre l'export nell'ambiente |
| Famiglie Claude e Codex | Esercitate in casi limitati; non equivalgono a copertura generale |

Ogni report registra commit della fabbrica e stato clean/dirty. Un commit dirty non è una provenienza esatta.

## Workspace generato

Base obbligatoria:

```text
README.md
AGENTS.md
skills/
reports/
```

`skills/` può essere vuota quando capacità native, skill già installate o istruzioni locali coprono interamente il lavoro. Nessuna skill viene creata per riempire la struttura.

Opzionali, solo se motivati:

```text
RESEARCH.md
ROADMAP.md
.mcp.json
```

I report formali usano `reports/YYYY-MM-DD-HHMMSS-generation.md` e `reports/YYYY-MM-DD-HHMMSS-update.md`, in UTC; una collisione usa `-2`, `-3`, ... prima di `generation`/`update`. La sezione Validazione registra comando esatto, `PASS`/`FAIL` ed exit code osservato. Il validator applica lo schema corrente soltanto al report più recente, così gli update non riscrivono la storia. Eventuali run e output di dominio restano nel workspace del progetto.

## Discovery

Il primo passaggio standard per capacità che possono richiedere tooling esterno è:

```bash
bash scripts/discover.sh "<termine preciso>" [skill|mcp|cli|all]
```

Lo script:

- applica timeout a ogni fonte o comando esterno;
- distingue fonte irraggiungibile, HTTP fallito, zero risultati e pacchetto assente;
- interroga registry di skill e MCP, PATH, Homebrew, npm e PyPI quando disponibili;
- usa la ricerca npm per query libere e limita i lookup esatti npm/PyPI ai nomi di pacchetto validi;
- stampa comandi quotati e riproducibili per `RESEARCH.md`.

I risultati sono candidati, non decisioni. Le skill già installate nel client vanno verificate separatamente. Una discovery banale o non applicabile può restare nel report; `RESEARCH.md` serve quando il confronto è non banale.

Le configurazioni MCP persistenti devono usare versioni esatte e dipendenze locali con lockfile o pin equivalenti. Invocazioni `npx`/`uvx` non versionate sono ammesse soltanto durante una discovery isolata.

## Template ed esempi

- `templates/` contiene basi compilabili con placeholder canonici `{{UPPER_CASE}}`.
- `examples/` contiene quattro fixture sintetiche complete: research, web dev, mobile dev e automation.

Le fixture servono a CI e regressione per struttura, riferimenti, safety, discovery e report. Nel collaudo corrente automation ha prodotto una baseline live su target pubblici sintetici, web dev ha completato lint/test/build su un'app React effimera e research ha verificato fetch e hash su fonti ufficiali. Mobile ha invece registrato correttamente l'assenza di Flutter/ADB e di un simulatore utilizzabile, senza simulare build o device.

Restano esempi sintetici, non configurazioni production né evidenze valide per promuovere un blueprint. Vanno adattati a un progetto reale e sottoposti alla checklist.

## Quality gate a due strati

Gate meccanici:

```bash
bash scripts/validate-factory.sh
bash scripts/test-validators.sh
bash scripts/test-discover.sh
bash scripts/check-repo-links.sh
bash scripts/validate-evals.sh
bash scripts/test-evals.sh
bash scripts/validate-workspace.sh <workspace-path>
bash scripts/lessons-ledger.sh validate
```

I test includono fixture positive, casi negativi isolati, link/symlink confinati, provenance report, timestamp calendariali, history append-only e mock deterministici della rete. Il gate della fabbrica scansiona inoltre path macchina-specifici, segreti, JSON e link locali fuori dalle fixture negative intenzionali. La CI esegue qualità statica su Ubuntu, il gate completo su Ubuntu e macOS e uno smoke live settimanale separato; quest'ultimo è ripetibile manualmente con `bash scripts/test-live-discovery.sh`. Il verde shell è necessario ma non sufficiente.

Il secondo strato è `skills/agent-workspace-builder/references/post-generation-checklist.md`: verifica obiettivo, setup, coerenza README/AGENTS, discovery, comandi reali, file extra, output e report. Un fallimento semantico prevale su un validator verde.

Per mantenere il validator indipendente da librerie linguistiche, le intestazioni strutturali dei template restano canoniche in italiano; un workspace interamente inglese può usare gli equivalenti inglesi riconosciuti. Il testo sotto le intestazioni segue invece la lingua dell'utente.

## Eval della skill

`skills/agent-workspace-builder/evals/evals.json` definisce tre scenari: capacità native minime, automation web sicura e due update incrementali. Il protocollo richiede esecuzioni con e senza skill sullo stesso prompt/input e senza mostrare le rubriche; run e transcript lo auto-attestano, ma l'assenza di trace raw non consente una verifica indipendente dell'isolamento. Transcript, output, grading, benchmark e viewer restano sotto `evals/runs/iteration-1/`; il manifest canonico degli hash vive in `evals/results/`.

Riproduzione del gate persistito:

```bash
bash scripts/validate-evals.sh
bash scripts/test-evals.sh
```

Per rigenerare benchmark e viewer offline dalle evidenze già graduate, usa
`scripts/build-eval-artifacts.sh` come documentato in
`skills/agent-workspace-builder/evals/README.md`.

Le metriche e gli identificatori di modello non esposti per run non vengono ricostruiti. Una singola run per configurazione misura la copertura degli scenari, non la varianza statistica; i transcript sono resoconti persistiti, non trace raw del provider. Le fixture eval restano sintetiche e non contano nel ledger delle generazioni reali.

## Report e memoria

Nel workspace del progetto vivono:

- obiettivo, path e assunzioni;
- discovery completa;
- report di generazione, update e run;
- output e dati del progetto.

Nella fabbrica vivono soltanto:

- `reports/lessons.md`: registro umano append-only di lezioni generalizzate;
- `reports/lesson-events.tsv`: ledger append-only di eventi opachi per conteggi e soglie;
- `reports/agent-factory-technical-overview.md`: overview descrittiva aggiornata;
- altri report storici: snapshot non normativi.

## Privacy e storia Git

La policy corrente vieta alla fabbrica nomi, obiettivi, percorsi, URL, dati o dettagli dei progetti generati. Esempi, fixture ed eval persistiti usano esclusivamente casi sintetici dichiarati.

Il 2026-07-10 il precedente repository remoto è stato eliminato e il repository pubblico omonimo è stato ricreato. La nuova `main`, inizializzata dal commit radice `5b4ea50`, è stata pubblicata e verificata con CI verde. La migrazione ha sostituito la linea visibile nell'origin corrente; non può eliminare o attestare copie autonome già presenti in fork, cache o cloni esterni.

La sostituzione di una history resta un'operazione amministrativa separata e distruttiva: non è e non diventa un effetto automatico del builder.

## Governance e contribuzione

```bash
bash scripts/lessons-ledger.sh summary
bash scripts/lessons-ledger.sh eligible
```

Il ledger deriva i conteggi per variante e ciclo reale. Una soglia rende una modifica candidabile, non autorizzata. Servono proposta, approvazione esplicita, worktree pulito, diff limitato e gate verdi. Non vengono eseguiti commit o push automatici.

Prima di contribuire:

1. Esegui `git status --short` e preserva cambi estranei.
2. Modifica soltanto i file necessari.
3. Aggiungi o aggiorna fixture per ogni comportamento cambiato.
4. Esegui i gate pertinenti e `git diff --check`.
5. Non riscrivere report storici, lezioni o righe del ledger.

`AGENTS.md` e la skill principale richiedono sempre una richiesta utente esplicita e specifica.

Per proporre modifiche consulta [CONTRIBUTING.md](CONTRIBUTING.md). Problemi di sicurezza vanno comunicati secondo [SECURITY.md](SECURITY.md); la partecipazione al progetto segue [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md). Le modifiche pubbliche rilevanti sono riassunte in [CHANGELOG.md](CHANGELOG.md).

## Versioning

Non esiste un package runtime con SemVer. La versione operativa è il commit Git della fabbrica, accompagnato da stato clean/dirty nei report. Evoluzioni generali devono essere commit dedicati e revisionabili; un worktree dirty impedisce modifiche di governance.

## File principali

- `AGENTS.md` — istruzioni operative ad alto segnale.
- `skills/agent-workspace-builder/SKILL.md` — contratto principale.
- `skills/agent-workspace-builder/references/` — indice, blueprint, guide, checklist e governance.
- `skills/agent-workspace-builder/evals/` — scenari di comportamento della skill.
- `templates/` — basi compilabili.
- `examples/` — fixture sintetiche complete.
- `scripts/` — discovery, validator, test e ledger.
- `reports/` — memoria generalizzata e snapshot descrittivi.
- `CONTRIBUTING.md` — flusso di contribuzione e gate richiesti.
- `SECURITY.md` — ambito e canale di segnalazione delle vulnerabilità.
- `CODE_OF_CONDUCT.md` — regole di partecipazione e moderazione.
- `CHANGELOG.md` — cronologia pubblica delle modifiche rilevanti.

## Licenza

MIT — vedi `LICENSE`.
