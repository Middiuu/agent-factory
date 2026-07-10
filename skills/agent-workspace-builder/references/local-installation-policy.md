# Policy: installazioni locali

## Skill locali al workspace

Le skill generate vivono in `skills/` del workspace dell'agente. Non installarle nella configurazione globale del coding agent: devono viaggiare con il progetto, versionate insieme al resto.

## MCP locali o configurati nel workspace

Gli MCP si configurano a livello di progetto (es. `.mcp.json` nella root del workspace) o si documentano nel README del workspace. Mai aggiungerli alla configurazione globale dell'utente per conto suo.

## Niente installazioni globali se non necessarie

- Dipendenze operative sempre a livello di progetto e riproducibili: versione esatta in `package.json`/lockfile, virtualenv con lock o pin, Gradle wrapper, ecc.
- `npx` / `uvx` senza versione sono ammessi soltanto per esplorazione isolata durante la discovery. Una configurazione persistita deve usare un package pinning esatto e il relativo lockfile o ambiente locale.
- Un'installazione globale è ammessa solo se lo strumento lo richiede per natura (es. SDK di piattaforma, runtime di sistema): in quel caso è un **requisito dichiarato** nel README, eseguito dall'utente, non un'azione del builder.

## Documentare sempre i comandi

Ogni installazione o configurazione, anche locale, va documentata nel README del workspace: comando esatto, dove viene eseguito, come verificare il risultato. Nessun setup "magico" fatto e non scritto.

I comandi non devono incorporare percorsi della macchina che ha generato il workspace. Quando workspace agentico e progetto operativo sono separati, usa variabili dichiarate e verificate:

```bash
WORKSPACE_ROOT="${WORKSPACE_ROOT:?set WORKSPACE_ROOT to the agent workspace}"
APP_ROOT="${APP_ROOT:?set APP_ROOT to the application repository}"
test -d "$WORKSPACE_ROOT/reports"
test -d "$APP_ROOT"
```

Nei comandi copia-incollabili usa variabili shell per URL, file e directory invece di pseudo-placeholder con parentesi angolari.

## Setup obbligatorio vs opzionale

Nel README del workspace distinguere chiaramente:

- **Obbligatorio**: senza questo l'agente non funziona (es. runtime dello stack).
- **Opzionale**: abilita capacità aggiuntive (es. MCP per notifiche); l'agente deve degradare con grazia se manca.

Elencare prima l'obbligatorio, poi l'opzionale, ognuno con i propri comandi.

Se non esiste setup obbligatorio o opzionale, scrivilo esplicitamente. Una sezione vuota non distingue un requisito assente da uno dimenticato.

Per ogni requisito documenta tre elementi:

1. dove va eseguito il comando;
2. comando di installazione o preparazione, se serve;
3. comando di verifica e risultato atteso osservabile.
