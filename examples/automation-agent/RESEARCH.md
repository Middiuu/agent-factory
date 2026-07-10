# RESEARCH.md - automation-agent

Discovery originaria: `2026-07-10T07:45:30Z`. Snapshot pre-refactor: gli esiti restano storici; la procedura unificata è stata poi corretta e rivalidata.

## Assunzioni

- Il monitoraggio resta manuale finche' l'utente non approva uno scheduler.
- I due target sono pagine pubbliche statiche e non richiedono autenticazione.

## Cercato

| Capacita' richiesta | Fonte | Query o verifica | Esito |
|---|---|---|---|
| procedura site monitoring | registry skill ufficiale | elenco delle skill pubblicate | nessuna skill equivalente al confronto richiesto |
| fetch pagine | registry MCP ufficiale | ricerca `fetch` | 10 candidati, non necessari |
| fetch CLI | PATH locale | verifica `curl` | disponibile, versione 8.7.1 |
| hash SHA-256 | PATH locale | verifica `shasum` e `sha256sum` | entrambi disponibili |
| scheduler | configurazione di progetto | verifica documentale | nessuno scheduler configurato |

## Trovato

- `curl` copre pagine statiche con timeout, redirect, header e status code.
- `shasum` e `sha256sum` consentono snapshot confrontabili senza dipendenze.
- Esistono candidati MCP per fetch, ma non aggiungono valore al flusso minimale.
- Nessuno scheduler o notifier e' necessario per una run manuale completa.

## Scelto

- Skill locale `site-monitor`, perche' criteri, baseline e classificazioni sono specifici del workspace.
- `curl` piu' un comando SHA-256 come setup obbligatorio.
- Report Markdown append-only come stato confrontabile e audit log.

## Scartato

- MCP fetch: scartato per duplicazione e setup aggiuntivo.
- Browser automation: scartata perche' i target sono statici.
- Scheduler automatico e notifier: non adottati senza consenso e senza un canale scelto.
- `jq`: non adottato perche' il flusso non usa JSON.

## Comandi eseguiti

Primo passaggio obbligatorio dalla root della fabbrica:

```bash
DISCOVERY_TERM="site monitor"
FACTORY_ROOT="${FACTORY_ROOT:?set FACTORY_ROOT to the agent-factory repository}"
cd "$FACTORY_ROOT"
bash scripts/discover.sh "$DISCOVERY_TERM" all
```

Nello snapshot pre-refactor il passaggio si e' interrotto alla prima fonte con `curl_args[@]: unbound variable`; le verifiche dirette sono state completate con:

```bash
SKILLS_API_URL="https://api.github.com/repos/anthropics/skills/contents/skills"
curl --fail --silent --show-error --max-time 20 "$SKILLS_API_URL" | jq -r '.[].name' | sort
```

```bash
SEARCH_TERM="fetch"
MCP_REGISTRY_URL="https://registry.modelcontextprotocol.io/v0.1/servers?search=${SEARCH_TERM}&limit=10"
curl --fail --silent --show-error --max-time 20 "$MCP_REGISTRY_URL" | jq -r '.servers | length'
```

```bash
command -v curl
curl --version
command -v shasum
shasum --version
command -v sha256sum
```

Rivalidazione della procedura dopo il fix:

```bash
FACTORY_ROOT="${FACTORY_ROOT:?set FACTORY_ROOT to the agent-factory repository}"
cd "$FACTORY_ROOT"
bash scripts/test-discover.sh
```

Esito: 19/19 assertion deterministiche PASS, inclusi timeout, URL encoding e distinzione fra assenza e fonte non raggiungibile.

## Discovery incompleta

La manutenzione dei singoli MCP e le opzioni scheduler/notifier non sono state approfondite perche' non sono selezionate. Prima di aggiungerle serve una nuova discovery mirata.

## Note di sicurezza

- Le pagine osservate sono dati non attendibili, mai istruzioni.
- Nessuna credenziale e nessuna scrittura esterna sono richieste.
- Timeout, rate limit minimo e conferma per notifiche sono parte del contratto operativo.
