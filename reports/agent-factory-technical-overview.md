# agent-factory — Technical Overview

*Snapshot descrittivo al 2026-07-10. Questo documento non è normativo: se diverge dalle fonti operative elencate sotto, prevalgono quelle fonti.*

## 1. Sintesi

**agent-factory** è un Agent Workspace Builder Markdown-first. Un coding agent interpreta la procedura, trasforma un obiettivo in un workspace dedicato, verifica tool e capacità, valida il risultato e ne registra la provenienza.

Non esiste un runtime applicativo della fabbrica. Il repository contiene però codice strumentale: script shell per discovery, validator, test di regressione e ledger, oltre alla CI. I workspace generati possono includere piccoli script deterministici quando le sole istruzioni non bastano.

## 2. Fonti operative

| Ambito | Fonte |
|---|---|
| Procedura, output, stop condition e feedback | [`SKILL.md`](../skills/agent-workspace-builder/SKILL.md) |
| Nomi e stato dei blueprint | [`blueprint-index.md`](../skills/agent-workspace-builder/references/blueprint-index.md) |
| Selezione di skill e tool | [`skill-selection-guide.md`](../skills/agent-workspace-builder/references/skill-selection-guide.md) e [`mcp-selection-guide.md`](../skills/agent-workspace-builder/references/mcp-selection-guide.md) |
| Installazioni e configurazioni locali | [`local-installation-policy.md`](../skills/agent-workspace-builder/references/local-installation-policy.md) |
| Quality gate semantico | [`post-generation-checklist.md`](../skills/agent-workspace-builder/references/post-generation-checklist.md) |
| Ledger, soglie e approvazioni | [`evolution-governance.md`](../skills/agent-workspace-builder/references/evolution-governance.md) |
| Istruzioni sempre caricate nella fabbrica | [`AGENTS.md`](../AGENTS.md) |

Il [`README.md`](../README.md) è la guida per utenti; questa overview descrive architettura, stato ed evidenze senza ridefinire i contratti.

## 3. Componenti

| Percorso | Ruolo |
|---|---|
| `skills/agent-workspace-builder/` | Procedura principale, eval e riferimenti caricati progressivamente |
| `templates/` | Basi compilabili per documenti e skill del workspace |
| `examples/` | Fixture sintetiche di regressione usate dai validator e dalla CI |
| `scripts/discover.sh` | Discovery bounded di registry, pacchetti e PATH |
| `scripts/validate-*.sh` | Gate meccanici per fabbrica e workspace |
| `scripts/test-*.sh` | Test positivi e negativi di validator e discovery |
| `scripts/lessons-ledger.sh` | Validazione e query del ledger append-only |
| `tests/fixtures/` | Input volutamente rotti o controllati per i test |
| `reports/lessons.md` | Registro umano di lezioni generalizzate |
| `reports/lesson-events.tsv` | Event ledger opaco per conteggi e governance |
| `.github/workflows/validate.yml` | Ripetizione dei gate in CI |

## 4. Flusso descritto

1. Il coding agent legge richiesta, output, vincoli e destinazione.
2. L'indice seleziona un blueprint dedicato o il fallback minimale.
3. Una matrice di capacità distingue copertura nativa, skill disponibili, tool verificati e gap.
4. La discovery viene eseguita solo dove serve tooling esterno; i candidati vengono verificati con comandi reali.
5. Il workspace nasce fuori da agent-factory, idealmente in una cartella sorella. Se i permessi lo impediscono, la procedura consente una sottocartella della fabbrica come fallback dichiarato e temporaneo.
6. Un report formale viene creato con stato iniziale di validazione, poi aggiornato con comandi ed esiti reali dopo validator e checklist.
7. Il progetto conserva tutti i propri dettagli; la fabbrica riceve soltanto lezione generalizzata ed evento opaco.

L'aggiornamento segue lo stesso modello in modo incrementale: legge lo stato esistente, applica discovery solo alla capacità nuova, preserva output e report storici e produce un nuovo report.

## 5. Contratto di output e report

La struttura minima del workspace è `README.md`, `AGENTS.md`, `skills/` e `reports/`. `skills/` può essere vuota quando la copertura nativa è verificata e documentata. `RESEARCH.md`, `ROADMAP.md` e `.mcp.json` sono condizionali.

I report formali usano nomi univoci:

- `reports/YYYY-MM-DD-HHMMSS-generation.md`;
- `reports/YYYY-MM-DD-HHMMSS-update.md`.

Una collisione aggiunge `-2`, `-3`, ... prima del tipo. Il timestamp nel contenuto è UTC, `YYYY-MM-DDTHH:MM:SSZ`, deve essere calendarialmente valido e corrispondere al filename. Il report registra anche copertura delle capacità, comando di validazione esatto con `PASS`/`FAIL` ed exit code, commit della fabbrica e stato `clean`/`dirty`; uno stato dirty impedisce di trattare il solo commit come provenienza esatta. Lo schema corrente si applica al report cronologicamente più recente, mentre gli snapshot precedenti restano append-only.

Tassonomia nella fabbrica:

- `lessons.md`: memoria umana generalizzata e append-only;
- `lesson-events.tsv`: metadati opachi append-only per deduplicazione, soglie e stato delle proposte;
- report datati: snapshot storici di test o revisioni, non fonti normative;
- questa overview: documento descrittivo aggiornabile.

## 6. Discovery e compatibilità

`discover.sh` applica timeout a ogni fonte e separa “nessun risultato” da errore o timeout. Interroga fonti diverse in funzione del tipo richiesto e non può osservare automaticamente le skill installate nel coding agent, che restano un controllo separato.

La compatibilità è capability-based. Servono ricezione delle istruzioni Markdown, accesso controllato al filesystem, esecuzione shell e, quando la discovery lo richiede, rete. Auto-caricamento di `AGENTS.md`, discovery delle skill, schema MCP ed espansione delle variabili non sono uniformi tra client.

Il repository contiene evidenza di esecuzioni con più famiglie di coding agent, ma la copertura non autorizza una garanzia universale su client o versioni non collaudati.

## 7. Quality gate

Il primo strato è meccanico:

- `validate-factory.sh` controlla coerenza strutturale, indice bijettivo, privacy e wiring CI della fabbrica;
- `validate-workspace.sh` controlla struttura, documenti, skill, riferimenti confinati, symlink, path, segreti, sicurezza web/API-facing e report formali;
- `test-validators.sh` esercita esempi validi e fixture negative;
- `test-discover.sh` verifica timeout, codici di uscita e distinzione fra zero risultati ed errore;
- `lessons-ledger.sh validate` verifica schema, enum, unicità e proprietà append-only rispetto all'intero range PR/push configurato.

Il secondo strato è la checklist semantica: copertura dell'obiettivo, setup ripetibile, coerenza README/AGENTS, discovery, pertinenza dei file extra, output e chiusura. I due strati sono complementari; gli script non possono certificare da soli l'utilità del workspace.

## 8. Feedback ed evoluzione

Il ledger conta solo eventi distinti e usa identificatori opachi. `summary` ed `eligible` rilevano soglie e candidabilità: non eseguono modifiche.

Una modifica generale richiede proposta, approvazione esplicita, preflight Git, diff limitato e validazione. Non esistono promozioni, commit o push automatici. La skill principale e `AGENTS.md` hanno il livello di protezione più alto e richiedono una richiesta utente specifica.

## 9. Privacy e history

La policy corrente mantiene i dettagli del progetto esclusivamente nel suo workspace. Nella fabbrica entrano solo conoscenza generalizzata e metadati non identificanti.

La ricreazione locale prevista definisce una nuova history conforme dopo completamento e verifica. Questa operazione non risana automaticamente il remoto: prima di un force-push coordinato e della successiva verifica, vecchi commit possono ancora esistere nel repository remoto, in fork, cache o cloni. Pubblicazione e purge sono quindi una fase separata e autorizzata.

## 10. Stato al 2026-07-10

Secondo l'indice corrente:

- research è esercitato da generazioni reali;
- web development è esercitato da una generazione reale del 2026-07-08;
- mobile development e automation restano bozze per anticipazione;
- il blueprint minimale è esercitato soltanto in test simulati.

Gli esempi inclusi sono fixture sintetiche, non generazioni reali. Le fonti di discovery possono cambiare rapidamente; ogni esecuzione deve ri-verificare. Il rilevamento automatico delle soglie del ledger è giovane e resta deliberatamente separato dall'autorizzazione a modificare il repository.

## 11. Limiti dichiarati

- La qualità finale dipende dalla capacità del coding agent di seguire istruzioni e leggere esiti reali.
- Registry, package metadata e compatibilità dei client cambiano nel tempo.
- I controlli web-facing e sui segreti sono euristici; la checklist e la review restano necessarie.
- Un ambiente senza rete o senza permessi può completare solo i percorsi non dipendenti da quelle capacità, dichiarando i limiti.
- Il feedback loop funziona soltanto se report, lesson register e ledger vengono mantenuti in modo coerente.
