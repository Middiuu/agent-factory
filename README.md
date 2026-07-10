# agent-factory

**agent-factory** è un Agent Workspace Builder Markdown-first: guida un coding agent nella generazione o nell'aggiornamento di workspace agentici specifici per progetto.

Non è un agente finale e non contiene runtime applicativo. La logica vive in istruzioni versionate; gli script shell e la CI sono tooling strumentale per discovery, validazione e governance.

Principi: minimale, verificabile, provider-aware senza dipendere da un singolo client, skill-driven quando serve, MCP/CLI-ready e safe by design. In caso di dubbio: meno file, meno tool, meno codice.

## Prerequisiti e permessi

Minimo necessario:

- un coding agent capace di leggere `AGENTS.md`, oppure istruito esplicitamente a farlo;
- accesso in lettura alla fabbrica e scrittura nella destinazione del workspace;
- Bash, Git e utility Unix di base;
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
- stampa comandi quotati e riproducibili per `RESEARCH.md`.

I risultati sono candidati, non decisioni. Le skill già installate nel client vanno verificate separatamente. Una discovery banale o non applicabile può restare nel report; `RESEARCH.md` serve quando il confronto è non banale.

Le configurazioni MCP persistenti devono usare versioni esatte e dipendenze locali con lockfile o pin equivalenti. Invocazioni `npx`/`uvx` non versionate sono ammesse soltanto durante una discovery isolata.

## Template ed esempi

- `templates/` contiene basi compilabili con placeholder canonici `{{UPPER_CASE}}`.
- `examples/` contiene quattro fixture sintetiche complete: research, web dev, mobile dev e automation.

Le fixture servono a CI e regressione per struttura, riferimenti, safety, discovery e report. Non sono configurazioni production, non installano scheduler o SDK e non provano che un tool esterno sia adatto a un progetto reale. Vanno adattate e sottoposte alla checklist.

## Quality gate a due strati

Gate meccanici:

```bash
bash scripts/validate-factory.sh
bash scripts/test-validators.sh
bash scripts/test-discover.sh
bash scripts/validate-workspace.sh <workspace-path>
bash scripts/lessons-ledger.sh validate
```

I test includono fixture positive, casi negativi isolati, link/symlink confinati, provenance report, timestamp calendariali, history append-only e mock deterministici della rete. Il gate della fabbrica scansiona inoltre path macchina-specifici e segreti fuori dalle fixture negative intenzionali. Il verde shell è necessario ma non sufficiente.

Il secondo strato è `skills/agent-workspace-builder/references/post-generation-checklist.md`: verifica obiettivo, setup, coerenza README/AGENTS, discovery, comandi reali, file extra, output e report. Un fallimento semantico prevale su un validator verde.

Per mantenere il validator indipendente da librerie linguistiche, le intestazioni strutturali dei template restano canoniche in italiano; un workspace interamente inglese può usare gli equivalenti inglesi riconosciuti. Il testo sotto le intestazioni segue invece la lingua dell'utente.

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

La policy corrente vieta alla fabbrica nomi, obiettivi, percorsi, URL, dati o dettagli dei progetti generati.

La ricreazione locale del repository prevista al termine del refactor stabilisce una nuova history conforme e rimuove la vecchia linea dalla copia locale. Non implica che un remoto, fork, cache o clone precedente sia risanato. Finché la nuova history non viene pubblicata con un force-push coordinato e verificata, i commit precedenti possono restare recuperabili altrove.

La pubblicazione della history sostitutiva è un'operazione separata e distruttiva: non è un effetto automatico del builder.

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

## Licenza

MIT — vedi `LICENSE`.
