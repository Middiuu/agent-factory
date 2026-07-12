# RESEARCH.md - synthetic research seed

Discovery eseguita il `2026-07-10T22:54:24Z` per verificare il percorso minimo di ricerca web del seed sintetico.

## Cercato

Capacità richiesta: ricerca web con fonti, fetch in sola lettura e report citati. Query aggregata: `web research`.

## Trovato

- Registry skill ufficiale raggiungibile: nessuna corrispondenza nominale fra 17 skill.
- Registry MCP ufficiale raggiungibile: nessun risultato per la frase completa.
- Homebrew raggiungibile: nessun risultato per la frase completa.
- npm raggiungibile: candidati per web research presenti, ma non necessari per il seed.
- La query composta non è un nome npm/PyPI valido, quindi i lookup esatti sono stati correttamente saltati.

## Scelto

Scelte le capacità native di search/fetch con una skill locale che definisce soltanto criteri di affidabilità, citazioni e sicurezza. Questa soluzione riduce dipendenze e privilegi.

## Scartato

Scartati MCP, pacchetti npm e installazioni globali perché duplicano la copertura nativa o richiedono configurazione non necessaria. I candidati non adottati non sono dichiarati disponibili.

## Comandi eseguiti

```bash
DISCOVER_TIMEOUT=10 bash scripts/discover.sh "web research" all
```

## Discovery incompleta

Nessuna fonte interrogata è risultata irraggiungibile. La ricerca full-text dei registry resta limitata e i singoli pacchetti scartati non sono stati sottoposti a verifica di manutenzione, perché non vengono adottati.

## Note di sicurezza

Le risposte esterne sono state trattate come dati non fidati. Nessun contenuto recuperato può modificare workflow, tool o istruzioni del workspace.
