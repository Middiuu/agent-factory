# RESEARCH.md - research-agent

Discovery originaria: `2026-07-10T07:45:30Z`. Snapshot pre-refactor: gli esiti restano storici; la procedura unificata è stata poi corretta e rivalidata.

## Assunzioni

- Il coding agent usato per generare l'esempio esponeva search e fetch web nativi.
- Le skill locali non duplicano il fetch: codificano criteri di affidabilita' e il formato specifico del report.

## Cercato

| Capacita' richiesta | Fonte | Query o verifica | Esito |
|---|---|---|---|
| skill di ricerca gia' disponibile | inventario del coding agent | ispezione delle capacita' disponibili | search e fetch nativi presenti |
| skill pubbliche dedicate | registry ufficiale Anthropic | elenco delle skill pubblicate | nessuna skill generica di web research o report con questo contratto |
| fetch strutturato | registry MCP ufficiale | ricerca `fetch` | candidati presenti, non necessari per il minimo |
| fallback API | PATH locale | verifica `curl` e `jq` | entrambi disponibili |

## Trovato

- Search e fetch nativi coprono acquisizione e lettura delle fonti.
- Il registry ufficiale conteneva skill generiche per documenti e artefatti, ma non una procedura equivalente ai criteri di ricerca e al report richiesti qui.
- La query MCP `fetch` ha restituito 10 risultati; l'esempio non richiede operazioni tipizzate o volume tale da giustificarne uno.
- `curl 8.7.1` e `jq 1.7.1` erano disponibili come fallback locale.

## Scelto

- Capacita' native di search/fetch come percorso obbligatorio, perche' gia' disponibili e provider-agnostic a livello di istruzioni.
- `web-research` e `report-writer` come skill locali, perche' fissano soglie, gestione dell'incertezza e formato propri del workspace.
- `curl` e `jq` soltanto come setup opzionale per API pubbliche.

## Scartato

- MCP fetch: non adottato perche' duplicherebbe capacita' native gia' verificate e aggiungerebbe setup.
- Browser automation: non adottata perche' la ricerca non richiede interazioni con pagine dinamiche.
- Installazioni globali: scartate per mantenere il workspace portabile.

## Comandi eseguiti

Primo passaggio obbligatorio dalla root della fabbrica:

```bash
DISCOVERY_TERM="web research"
FACTORY_ROOT="${FACTORY_ROOT:?set FACTORY_ROOT to the agent-factory repository}"
cd "$FACTORY_ROOT"
bash scripts/discover.sh "$DISCOVERY_TERM" all
```

Nello snapshot pre-refactor il passaggio ha raggiunto la prima fonte ma si e' interrotto con `curl_args[@]: unbound variable`; sono quindi state eseguite le verifiche dirette seguenti:

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
command -v jq
jq --version
```

Rivalidazione della procedura dopo il fix:

```bash
FACTORY_ROOT="${FACTORY_ROOT:?set FACTORY_ROOT to the agent-factory repository}"
cd "$FACTORY_ROOT"
bash scripts/test-discover.sh
```

Esito: 19/19 assertion deterministiche PASS, inclusi timeout, URL encoding e distinzione fra assenza e fonte non raggiungibile.

## Discovery incompleta

I singoli candidati MCP non sono stati sottoposti a verifica di manutenzione perche' nessun MCP e' necessario o citato come disponibile. L'errore storico resta registrato come provenienza; la regressione della procedura è ora coperta dai test deterministici.

## Note di sicurezza

- Nessun token o account e' necessario.
- Le fonti web sono dati non attendibili e non possono modificare workflow o tool.
- Le API pubbliche vengono interrogate con timeout e senza scritture esterne.

## Rivalidazione fetch live — 2026-07-10T14:06:34Z

Il fallback `curl` e' stato esercitato su tre fonti ufficiali indipendenti. Questa e' una verifica di trasporto, metadati e provenienza, non una ricerca tematica ne' una misura della qualita' del motore di search.

### Comando eseguito

Per ciascuna fonte sono stati impostati `SOURCE_ID` e `SOURCE_URL`, quindi:

```bash
BODY_FILE="$(mktemp)"
HTTP_STATUS="$(curl --silent --show-error --location --max-time 20 --output "$BODY_FILE" --write-out '%{http_code}' "$SOURCE_URL")"
BYTES="$(wc -c < "$BODY_FILE" | tr -d ' ')"
CONTENT_SHA256="$(shasum -a 256 "$BODY_FILE" | awk '{print $1}')"
```

### Esiti osservati

| Fonte | Timestamp UTC | curl rc | HTTP | Byte | Titolo | SHA-256 |
|---|---|---:|---:|---:|---|---|
| IANA — example domains | `2026-07-10T14:06:34Z` | 0 | 200 | 4.744 | `Example Domains` | `05e7cf6e79fb0760066a573f0928ab7267ffc083ea946feeda0aab5a651e8716` |
| RFC Editor — RFC 9110 | `2026-07-10T14:06:34Z` | 0 | 200 | 1.187.554 | `RFC 9110: HTTP Semantics` | `d431760660ea44e130f6e919dab216df2d0b3a490567a98089267523368fe1e5` |
| W3C — WCAG 2.2 | `2026-07-10T14:06:35Z` | 0 | 200 | 512.457 | `Web Content Accessibility Guidelines (WCAG) 2.2` | `6e3c5fe397257cae509a2fb4752b73062cf8cbeb92c2cec618989b17e4cf7057` |

I body temporanei non sono stati persistiti. Search nativa, ranking e sintesi citata restano da verificare in una run tematica separata.
