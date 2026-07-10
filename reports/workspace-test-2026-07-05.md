# Report: test della fabbrica con subagent (2026-07-05/06)

## Cosa è stato testato

Due generazioni di prova eseguite da subagent indipendenti, in una cartella scratch di sessione (nessun workspace reale creato):

1. **tech-research-agent** — obiettivo research, blueprint dedicato `workspace-blueprint-research-agent.md`. Completato: workspace intero, discovery reale (registry MCP via API, skill installate, repo `anthropics/skills` via API GitHub, CLI con `which`), RESEARCH.md, auto-validazione con la checklist (tutti i punti passati), report con lezioni.
2. **event-planner-agent** — obiettivo event planning, test del fallback su `workspace-blueprint-minimal.md`. Quasi completato (interrotto dal limite di sessione dopo README, AGENTS.md, RESEARCH.md e skill locale): la discovery ha funzionato, con scarti ben motivati (MCP verticali/commerciali, MCP calendario fuori scopo, CLI superflue).

Esito complessivo: **la procedura regge end-to-end**. La discovery obbligatoria è risultata eseguibile con le fonti e i comandi documentati nelle guide; entrambi i builder hanno correttamente scelto "nessun MCP" motivandolo, creato solo skill locali per le specificità del progetto e prodotto RESEARCH.md conformi.

## Lezioni per la fabbrica (dal test) e correzioni applicate

1. La ricerca del registry MCP non gestisce termini multipli (`web+search` → 0 risultati) → guida MCP: usare termini singoli e query separate.
2. Il registry restituisce versioni duplicate dello stesso server → guida MCP: filtro `jq ... | sort -u` nell'esempio.
3. Le query al registry possono bloccarsi → guida MCP: `--max-time 20` negli esempi curl.
4. Mancava un comando concreto per elencare `anthropics/skills` → guida skill: aggiunto `curl` sull'API GitHub (verificato).
5. La checklist non prevedeva l'eccezione di percorso già ammessa da AGENTS.md → checklist: punto riformulato.
6. `.gitkeep` nelle cartelle vuote non era tra i file ammessi → checklist e SKILL.md: segnaposto esplicitamente ammesso.

## Lezioni dalla revisione critica (stesso ciclo) e correzioni applicate

7. La regola "2–3 domande di chiarimento" poteva bloccare le esecuzioni non interattive → SKILL.md e AGENTS.md: fallback "interpretazione più semplice + assunzioni documentate nel report".
8. Nessuna indicazione su cosa fare se la rete non è disponibile durante la discovery → entrambe le guide: mai citare a memoria, segnalare discovery incompleta in RESEARCH.md.
9. L'endpoint `/v0.1` del registry può cambiare versione → guida MCP: avvertenza aggiunta.
10. L'espansione `${VAR}` in `.mcp.json` è specifica di Claude Code → guida MCP: nota di portabilità nel template.

## Residui

- Il test event-planner non ha completato auto-validazione e report finale (limite di sessione, non un difetto della fabbrica): il fallback sul blueprint minimale è comunque risultato adeguato fino al punto di interruzione.
- I workspace di prova vivono nella cartella scratch di sessione e non vanno conservati.
