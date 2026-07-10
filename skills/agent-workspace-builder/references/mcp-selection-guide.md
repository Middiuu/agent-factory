# Guida: scegliere MCP o CLI

## Dove cercare (fonti concrete)

La ricerca degli strumenti è compito del builder, non dell'utente: interroga le fonti sotto, confronta le opzioni secondo i criteri di questa guida e documenta scelte e scarti (con motivazione) nel `RESEARCH.md` del workspace.

**Primo passaggio standard**: dalla root della fabbrica assegna un termine esplicito ed esegui la discovery:

```bash
DISCOVERY_TERM="fetch"
bash scripts/discover.sh "$DISCOVERY_TERM" all
```

Lo script interroga in un colpo skill registry, registry MCP, npm (con conteggio download), Homebrew, PyPI e il PATH locale, con timeout e degrado dichiarato; stampa i comandi esatti da registrare in `RESEARCH.md`. Le query manuali sotto restano per approfondire (più termini, fonti di comunità, casi che lo script non copre).

- **Registry MCP ufficiale** — [registry.modelcontextprotocol.io](https://registry.modelcontextprotocol.io), interrogabile via API REST senza autenticazione:

  ```bash
  SEARCH_TERM="fetch"
  MCP_REGISTRY_URL="https://registry.modelcontextprotocol.io/v0.1/servers?search=${SEARCH_TERM}&limit=10"
  curl --fail --silent --show-error --max-time 20 "$MCP_REGISTRY_URL" \
    | jq -r '.servers[].server | "\(.name) — \(.description)"' | sort -u
  ```

  Avvertenze pratiche: la ricerca full-text del registry è debole — usa termini singoli e più query separate (`fetch`, `github`), non frasi (`web+search` dà 0 risultati); i risultati contengono versioni duplicate dello stesso server, il `sort -u` sopra le compatta; metti sempre un timeout a curl, le richieste possono bloccarsi; se l'endpoint `/v0.1` cambia versione, controlla la documentazione del registry.

- **Repository di riferimento** — [github.com/modelcontextprotocol/servers](https://github.com/modelcontextprotocol/servers): server di riferimento e link ai server ufficiali dei vendor.
- **Registry di comunità** (seconda scelta, per copertura): [smithery.ai](https://smithery.ai), [mcp.so](https://mcp.so), [glama.ai/mcp/servers](https://glama.ai/mcp/servers).
- **MCP già configurati nell'ambiente** — in Claude Code `claude mcp list`; in altri coding agent la configurazione equivalente.
- **CLI già presenti o installabili** — assegna `TOOL_NAME` o `PACKAGE_NAME` e usa `command -v "$TOOL_NAME"`, `brew search "$TOOL_NAME"`, `npm view "$PACKAGE_NAME"` e PyPI per verificarne l'esistenza. Mai consigliare una CLI senza averla verificata.
- **Fallback: ricerca web**, se i registry non coprono il servizio. Vale la stessa regola: verificare esistenza e manutenzione prima di citare.

Se la rete non è disponibile o una fonte non risponde, non citare a memoria: segnala in `RESEARCH.md` che la discovery è incompleta e cosa resta da verificare.

## Quando serve un MCP

Quando l'agente deve interagire ripetutamente con un servizio esterno in modo strutturato (Slack, GitHub, database, browser) e un server MCP ufficiale o ben mantenuto esiste. L'MCP conviene quando espone operazioni tipizzate che altrimenti richiederebbero script fragili.

## Quando basta una CLI

Quando lo strumento è già una CLI matura (`git`, `gh`, `flutter`, `curl`, `jq`) e il coding agent può eseguire comandi shell. Una CLI documentata è più semplice, più trasparente e più facile da verificare di un MCP equivalente. In caso di parità, scegli la CLI.

## Quando basta documentazione

Quando l'uso è occasionale o manuale: basta una sezione nel README del workspace con i comandi o gli endpoint. Non configurare integrazioni per operazioni che si fanno due volte l'anno.

## Come valutare manutenzione e affidabilità

- Fonte: preferire server/tool ufficiali del vendor o di organizzazioni note.
- Manutenzione: ultima release entro ~12 mesi e issue gestite; oltre, il tool va trattato come non mantenuto salvo evidenza contraria. Per pacchetti npm:

  ```bash
  PACKAGE_NAME="${PACKAGE_NAME:?set PACKAGE_NAME before verification}"
  npm view "$PACKAGE_NAME" time.modified
  ```
- Adozione: usato realmente, non solo annunciato. Segnale verificabile per npm:

  ```bash
  PACKAGE_NAME="${PACKAGE_NAME:?set PACKAGE_NAME before verification}"
  NPM_DOWNLOADS_URL="https://api.npmjs.org/downloads/point/last-month/${PACKAGE_NAME}"
  curl --fail --silent --show-error --max-time 20 "$NPM_DOWNLOADS_URL" | jq -e '.downloads >= 0'
  ```
- Verifica sempre che il tool esista e sia attivo prima di consigliarlo: mai citare a memoria.

## Come registrare la discovery

In `RESEARCH.md`, oltre ai comandi esatti, riassumi il confronto in una matrice — rende le scelte confrontabili e la ri-verifica in validazione immediata:

```md
| Capacità richiesta | Fonte interrogata | Comando | Esito | Decisione |
|---|---|---|---|---|
| fetch pagine web | registry MCP | comando `C2` registrato sotto la tabella | candidati registrati nell'output | scartati: capacità nativa sufficiente |
```

I comandi richiamati dalla matrice vanno poi riportati per esteso, uno per blocco. Esempio per `C2`:

```bash
SEARCH_TERM="fetch"
bash scripts/discover.sh "$SEARCH_TERM" mcp
```

## Come evitare MCP rischiosi

- Diffidare di server che chiedono credenziali ampie per fare poco: minimo privilegio.
- Evitare server non mantenuti, senza sorgente ispezionabile o di autore ignoto.
- Attenzione ai server che eseguono codice arbitrario o hanno accesso di scrittura ampio: valutare se serve davvero.
- Preferire autenticazione via variabili d'ambiente/OAuth a token incollati in file versionati.

## Come documentare il setup locale

Nel README del workspace generato: cosa serve, comando di installazione locale, configurazione (es. `.mcp.json` di progetto), variabili d'ambiente richieste, come verificare che funzioni. Un blocco per tool, copia-incollabile.

I fallback opzionali (es. un MCP da attivare se al coding agent manca una capacità nativa) vanno documentati anche in `AGENTS.md` del workspace, non solo nel README: è l'agente a doverli usare, e l'agente non si fa guidare dal README.

## Generazione sicura di `.mcp.json`

Non esiste un template universale copia-incollabile: comando, argomenti e trasporto dipendono dal server e dal client. Genera `.mcp.json` soltanto dopo che `RESEARCH.md` registra:

- package e versione **esatta** selezionati;
- registry e repository sorgente verificati;
- maintainer, licenza, data dell'ultima release e superficie dei permessi;
- comando documentato dall'upstream e prova locale minima;
- hash del lockfile o altra evidenza riproducibile dell'installazione.

Per Node installa il package nel progetto con una versione esatta e lockfile, poi usa il binario locale documentato dal package. Per Python crea un ambiente locale e un lock/pin esatto. `npx -y package` e `uvx package` senza versione sono ammessi soltanto durante una discovery isolata: non devono sopravvivere nella configurazione operativa del workspace.

I server di esempio o reference non sono automaticamente adatti alla produzione. Prima di concedere filesystem, rete o credenziali esegui una threat review proporzionata, limita root e operazioni al minimo e preferisci un'integrazione vendor mantenuta quando il task riguarda un servizio autenticato.

I segreti restano in variabili d'ambiente, mai nel file. L'espansione delle variabili dentro `.mcp.json` non è portabile tra tutti i coding agent: documenta nel README l'esportazione prima dell'avvio e il comando specifico con cui verificare la connessione.

## Installazioni locali

MCP e pacchetti vanno configurati a livello di progetto (es. `.mcp.json` nel workspace), mai globalmente se evitabile. Regole complete — dipendenze, `npx`/`uvx`, eccezioni ammesse — in `local-installation-policy.md`.
