# Indice dei blueprint

Unica fonte di verita' per il routing dei blueprint disponibili: nomi esatti dei file, quando usarli e stato di esercizio. La procedura carica questo indice e usa i nomi elencati qui, mai nomi dedotti dal tipo.

Questo indice non autorizza auto-modifiche. Nuovi blueprint, cambi di stato e modifiche a blueprint esistenti sono sempre proposte: richiedono evidenze verificabili, approvazione esplicita dell'utente e una modifica revisionabile secondo `evolution-governance.md`. Nessuna soglia o contatore applica cambiamenti da solo.

| File (nome esatto) | Tipo / variante | Quando usarlo | Stato di esercizio |
|---|---|---|---|
| `workspace-blueprint-research-agent.md` | research | Ricerca online, fonti, report con citazioni | Esercitato da generazioni reali documentate nel ledger append-only |
| `workspace-blueprint-web-dev-agent.md` | web dev | Sviluppo/manutenzione di web app | Esercitato da una generazione reale documentata nel ledger append-only |
| `workspace-blueprint-mobile-dev-agent.md` | mobile dev | Sviluppo app mobile (Flutter, RN, nativo) | Bozza per anticipazione — nessuna generazione reale |
| `workspace-blueprint-automation-agent.md` | automation | Monitoraggi, notifiche, pipeline leggere | Bozza per anticipazione — nessuna generazione reale |
| `workspace-blueprint-minimal.md` | fallback universale | Ogni tipo non coperto sopra | Esercitato solo in test simulati |

Regole:

- Un blueprint "bozza per anticipazione" si usa comunque, ma il report di generazione deve segnalare che il blueprint non era ancora esercitato: la prima generazione reale è anche il suo collaudo.
- Esempi, fixture e collaudi sintetici non diventano evidenze di generazione reale.
- Le evidenze di conteggio vivono in `reports/lesson-events.tsv`; stati e conteggi si derivano con `bash scripts/lessons-ledger.sh summary`, non si mantengono come autorita' manuale separata.
- Una ricorrenza puo' motivare una proposta, mai una promozione automatica. Prima di cambiare questo indice, mostra all'utente evidenze, diff previsto e impatto sul routing e attendi approvazione esplicita.
- I blueprint di variante usano il prefisso `workspace-blueprint-`, seguito dagli slug di tipo e variante; entrano nell'indice soltanto dopo l'approvazione.
