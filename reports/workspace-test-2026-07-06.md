# Report: secondo giro di test con subagent (2026-07-06)

Seguito di `workspace-test-2026-07-05.md`. Testate le due parti rimaste scoperte dal primo giro: la **validazione indipendente** (un validatore terzo, non autore, verifica un workspace contro la checklist) e il **ciclo di vita** (aggiornamento di un agente esistente senza rigenerarlo).

## Test 1 — Validazione indipendente di tech-research-agent

Esito: **13 PASS, 1 PASS con riserva, 1 discrepanza fattuale**. Il validatore ha ri-eseguito davvero le verifiche (which, PyPI, query al registry, API GitHub, perfino `uvx mcp-server-fetch --help`).

Il ritrovamento più importante: una claim di discovery (`tavily` → 0 risultati) **era già falsa a 24 ore di distanza** — oggi il registry restituisce 4 server, incluso quello ufficiale Tavily. Non avrebbe cambiato la decisione, ma la checklist di allora non poteva intercettare la deriva: RESEARCH.md non registrava i comandi eseguiti e nessun punto chiedeva di ri-verificare.

Correzioni applicate alla fabbrica:
- Checklist: `.mcp.json` aggiunto ai file previsti (incoerenza interna con AGENTS.md); coerenza README↔AGENTS.md resa specifica (ogni requisito e fallback promesso deve essere operativo in AGENTS.md); criterio operativo per "passi verificabili"; `name` frontmatter == nome directory; pattern grep concreti per i segreti su tutti i file; nuovo punto sui percorsi assoluti macchina-specifici trafilati.
- Checklist + SKILL.md + AGENTS.md: **riproducibilità della discovery** — RESEARCH.md deve registrare i comandi esatti eseguiti ed essere autosufficiente; in validazione va ri-eseguita almeno una verifica per categoria.
- Guida MCP: i fallback opzionali vanno documentati anche in AGENTS.md del workspace, non solo nel README.

Proposte del validatore non applicate: forma della risposta del registry e eccezione di percorso nella checklist (già coperte dai fix del 2026-07-05, che il validatore non aveva in lettura); punti aggiuntivi a basso valore (validità sintattica dei blocchi JSON, coerenza delle date) scartati per minimalismo.

## Test 2 — Aggiornamento di event-planner-agent

Richiesta simulata: aggiungere un run sheet del giorno dell'evento. Esito: **la procedura di aggiornamento regge**. L'updater ha creato una skill dedicata `event-run-sheet` (scelta corretta: capacità distinta), aggiornato README/AGENTS.md, appeso a RESEARCH.md con data senza riscrivere la storia, riparato la cartella `reports/` mancante e validato con la checklist.

Punti dove ha dovuto improvvisare, corretti nella procedura di aggiornamento di SKILL.md:
1. Riparazione di mancanze strutturali da generazioni interrotte: ora ammessa esplicitamente al passo 1; chiarito che "non toccare reports/" riguarda i contenuti, non l'esistenza della cartella.
2. Criterio estendere-vs-creare skill: aggiunto rimando esplicito a "una skill per capacità" (deliverable, momento d'uso o input diversi → skill nuova).
3. Naming e struttura del report di aggiornamento: `YYYY-MM-DD-<nome-agente>-update.md` con struttura minima.
4. Checklist: nota aggiunta — in caso di aggiornamento, posizione e setup si verificano solo se toccati dal cambiamento.

Conferme positive: le avvertenze aggiunte il 2026-07-05 alla guida MCP (termini singoli, `--max-time`) si sono dimostrate utili sul campo in entrambi i test.

## Nota operativa

I subagent hanno sofferto stalli d'infrastruttura ripetuti (watchdog a 600s), non legati alla fabbrica; il lavoro su disco è risultato comunque completo e coerente. I workspace di prova vivono nella cartella scratch di sessione e non vanno conservati.
