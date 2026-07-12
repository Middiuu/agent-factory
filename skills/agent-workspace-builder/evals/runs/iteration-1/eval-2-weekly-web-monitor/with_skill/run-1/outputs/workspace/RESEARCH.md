# RESEARCH.md - Weekly Web Monitor

Workspace: `weekly-web-monitor`

Discovery completata: `2026-07-11T07:50:20Z`

Obiettivo:

```text
Genera un agente di monitoraggio web settimanale con log, confronto dei cambiamenti e notifiche solo dopo conferma. Non configurare credenziali o scheduler globali.
```

## Assunzioni

- Nessun URL, canale o destinatario è stato fornito: il workspace resta generico e richiede target espliciti prima della prima run.
- “Settimanale” significa intervallo minimo di sette giorni tra run riuscite; non viene configurato alcuno scheduler.
- “Notifiche solo dopo conferma” richiede una bozza locale, consenso contestuale, approvazione registrata e poi un notifier già configurato dall'utente. In assenza del notifier l'agente si ferma.
- Le fonti sono pagine HTTP(S) pubbliche e non sensibili; rendering JavaScript e autenticazione non sono inclusi.

## Cercato

| ID | Capacità richiesta | Fonte | Query o verifica | Esito |
|---|---|---|---|---|
| D1 | skill già installate | contesto del coding agent | elenco skill disponibile nella sessione | presenti skill browser e web research, ma non una procedura project-specific per baseline, classi e gate |
| D2 | fetch web | discovery aggregata | `web fetch` / `all` | registry skill HTTP 403; MCP nessun risultato per la frase; registry npm e Homebrew raggiungibili |
| D3 | notifiche | discovery aggregata | `notifications` / `all` | due MCP trovati e pacchetti generici; nessun canale richiesto |
| D4 | cadenza settimanale | discovery aggregata | `weekly scheduler` / `all` | nessun MCP; pacchetti non pertinenti; scheduler escluso dal vincolo |
| D5 | fetch MCP | registry MCP ufficiale | `fetch` / `mcp` | candidati per fetch trovati; nessuno necessario per HTTP(S) statico |
| D6 | CLI HTTP | PATH e registry | `curl` / `cli` | `curl` presente nel PATH; versione 8.7.1 verificata |
| D7 | runtime | PATH locale | `python3 --version` | `python3` presente nel PATH; versione 3.9.6 verificata |

## Trovato

- Il contesto espone capacità browser e ricerca web, utili per interazione o ricerca, ma la procedura di questo workspace deve mantenere baseline confrontabili, hash, log e gate di conferma in modo portabile.
- La query MCP singola `fetch` ha restituito server di comunità per fetch ed estrazione, alcuni con servizi, pagamenti o bypass anti-bot. Non servono per pagine statiche pubbliche.
- La query `notifications` ha restituito `io.github.nirholas/notifications-mcp` e `io.github.topvisor/mcp-notifications`, oltre a pacchetti generici. Senza canale e consenso a configurare un'integrazione, nessuno è adottabile.
- Python 3.9.6 e curl 8.7.1 sono presenti. Python offre HTTP, parsing HTML/JSON, SHA-256, diff e test locali tramite sola libreria standard.
- La query scheduler ha restituito soprattutto componenti UI o servizi cloud. Il requisito vieta configurazioni globali e non richiede un prodotto di scheduling.

## Scelto

- `python3` 3.9.6 come unico runtime obbligatorio, senza pacchetti esterni. Copre fetch HTTP(S) statico, canonicalizzazione deterministica, hash, diff, log, test e gate locale.
- Una skill locale `weekly-web-monitor`, perché baseline, classificazioni, cadenza e conferma costituiscono una procedura ripetibile specifica non coperta dalle skill installate.
- Nessun MCP e nessun notifier. Una bozza e un'approvazione locale rendono verificabile il consenso; l'invio resta subordinato a un notifier preesistente scelto dall'utente.
- Nessuno scheduler. La periodicità è applicata come intervallo minimo nello script e descritta per esecuzione manuale o per una futura automazione separata, esplicitamente richiesta.

## Scartato

- MCP/browser per fetch: complessità e superficie di permessi non necessarie per pagine statiche; i candidati non sono stati adottati né installati.
- MCP e pacchetti di notifica: canale, destinatario e credenziali non specificati; configurarli divergerebbe dal requisito di non configurare credenziali.
- Pacchetti scheduler e servizi cloud: non necessari, alcuni implicano account o scheduling esterno; nessuno è stato installato o configurato.
- `curl` come dipendenza operativa: verificato e utile per diagnostica, ma Python standard library evita una seconda dipendenza. Non compare nei comandi runtime.
- Rendering JavaScript: fuori scope; se una fonte lo richiede serviranno nuova discovery, permessi e test specifici.

## Comandi eseguiti

I primi tre comandi sono stati avviati in parallelo dalla root della fabbrica; tutti hanno restituito exit code `0`.

```bash
DISCOVERY_TERM="web fetch"
bash scripts/discover.sh "$DISCOVERY_TERM" all
```

```bash
DISCOVERY_TERM="notifications"
bash scripts/discover.sh "$DISCOVERY_TERM" all
```

```bash
DISCOVERY_TERM="weekly scheduler"
bash scripts/discover.sh "$DISCOVERY_TERM" all
```

Approfondimenti e verifiche successive, tutti con exit code `0`:

```bash
DISCOVERY_TERM="fetch"
bash scripts/discover.sh "$DISCOVERY_TERM" mcp
```

```bash
DISCOVERY_TERM="curl"
bash scripts/discover.sh "$DISCOVERY_TERM" cli
```

```bash
command -v python3
python3 --version
```

```bash
command -v curl
curl --version
```

## Discovery incompleta

Il registry GitHub delle skill ha restituito HTTP `403` in tutte le query aggregate. È un limite della fonte/rate limit, non prova di assenza di skill. Il gap non blocca il workspace: le skill disponibili nella sessione sono state verificate dal contesto e la procedura locale copre comportamento specifico che le capacità generiche non forniscono.

## Note di sicurezza

- Nessun candidato è stato installato e nessuna configurazione globale è stata modificata.
- Nessun URL operativo, secret, canale o credenziale è incluso.
- I server che dichiarano bypass anti-bot, pagamenti o API esterne sono stati scartati; l'agente non aggira controlli di accesso.
- Il contenuto remoto è trattato come dato non attendibile e non può cambiare workflow, destinazioni o comandi.
