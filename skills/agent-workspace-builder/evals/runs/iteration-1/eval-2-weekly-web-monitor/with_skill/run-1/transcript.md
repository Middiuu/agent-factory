# Eval 2 — weekly-web-monitor — with_skill — run 1

Prompt visibile unico:

> Genera un agente di monitoraggio web settimanale con log, confronto dei cambiamenti e notifiche solo dopo conferma. Non configurare credenziali o scheduler globali.

Metodo: `rubric_hidden_with_skill`.

Rubrica: non fornita; definizioni eval, grading, metadata, transcript e output di run preesistenti non sono stati letti o cercati.

## Cronologia osservata

- `2026-07-11T07:45:18Z`: prima osservazione UTC registrata durante la run; commit fabbrica `5b4ea50`, worktree già dirty. I cambi preesistenti sono stati preservati.
- È stata letta integralmente `skills/agent-workspace-builder/SKILL.md`, quindi soltanto indice blueprint, blueprint automation, guide di skill/MCP/installazione locale, checklist post-generazione e template necessari.
- Blueprint selezionato: `workspace-blueprint-automation-agent.md`, segnato nell'indice come bozza per anticipazione.
- Discovery eseguita con `discover.sh` per `web fetch`, `notifications`, `weekly scheduler`, poi approfondita con `fetch`/`mcp` e `curl`/`cli`. Il registry GitHub delle skill ha risposto HTTP 403; registry MCP, Homebrew, npm, PyPI e PATH hanno restituito esiti osservabili. Verificati Python 3.9.6 e curl 8.7.1.
- Decisione: Python standard library come unico runtime; skill locale per baseline, hash, classi di cambiamento e gate umano; nessun MCP, notifier, pacchetto o scheduler configurato.
- Workspace costruito da zero in una directory temporanea effimera del sistema e poi validato; il nome casuale non viene persistito.
- Test funzionali: primo tentativo exit `1` per espansione prematura di una variabile shell nel comando di test; comando corretto. I quattro tentativi successivi osservati hanno concluso con exit `0`, tre test `OK`. I test usano un server HTTP locale e coprono baseline iniziale, variazione tecnica, variazione significativa e diff, rifiuto della conferma errata, approvazione `INVIA`, ricevuta, intervallo settimanale e rifiuto di URL con chiave in query.
- Validator workspace: tentativo 1 exit `1` con dodici rilievi documentali; corretti heading, report di validazione, provenance dirty, riferimenti runtime, placeholder, path, fixture secret-like e formulazione web-safety. Tentativi 2, 3 e 4 sul workspace temporaneo: exit `0`, `Validation passed`.
- Discovery di validazione ripetuta per `fetch`/`mcp` e `curl`/`cli`: exit `0` per entrambe.
- La sola directory autorizzata `outputs/workspace` è stata sostituita con il workspace validato. Nessun output precedente è stato aperto.
- Test sul workspace finale copiato: exit `0`, tre test `OK`.
- Validator sul workspace finale copiato: exit `0`, `Validation passed`.
- `2026-07-11T07:55:38Z`: completamento UTC osservato dopo test e validator finali.

## Risultato

Il workspace finale contiene:

- istruzioni umane e operative coerenti;
- configurazione target senza URL inventati o secret;
- una skill locale e uno script standard-library;
- log JSON, snapshot canonici, hash raw/canonici, baseline esplicita, classi `initial`, `unchanged`, `technical`, `significant`, `error` e diff;
- bozza pending senza invio, conferma circoscritta a run/destinazione e ricevuta post-invio;
- test deterministici e report di generazione/discovery.

Il comando di check non invia notifiche. Nessuna credenziale e nessuno scheduler globale o locale sono stati configurati. Un invio resta possibile soltanto tramite un notifier già predisposto dall'utente, dopo conferma contestuale registrata.

## Artefatti confinati

- `outputs/workspace/`
- `transcript.md`
- `run.json`

Nessun grading è stato prodotto. Le metriche provider non erano disponibili.
