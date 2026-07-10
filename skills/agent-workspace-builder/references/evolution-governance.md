# Governance dell'evoluzione

Carica questa reference solo quando registri una lezione, valuti una soglia o proponi una modifica generale alla fabbrica.

## Separazione dei dati

- Il workspace del progetto conserva obiettivo, nomi, percorsi, discovery e report completi.
- `reports/lessons.md` conserva soltanto lezioni generalizzate leggibili da umani.
- `reports/lesson-events.tsv` conserva soltanto metadati opachi necessari a contare eventi distinti.
- Nessun file della fabbrica deve contenere identificatori, URL, percorsi o dati del progetto.

La nuova history Git inizializzata dopo il refactor è il confine della policy corrente. Un eventuale remoto con la history precedente deve essere sostituito separatamente; non dichiararlo risanato finché non è avvenuto.

## Ledger append-only

Il ledger usa nove colonne TSV:

```text
schema_version event_id date cycle_id agent_type variant_id event_kind real draft_state
```

Regole:

- `event_id` e `cycle_id` sono identificatori opachi, non derivati da nomi o path;
- `variant_id` è uno slug canonico stabile, scelto una volta e riusato;
- `event_kind` è `generation`, `update`, `post_run`, `provider_test`, `proposal`, `approval` o `promotion`;
- `real` è `true` solo per cicli reali, mai per fixture, simulazioni o collaudi provider;
- `draft_state` è `none`, `proposed`, `approved` o `rejected`;
- le righe si aggiungono in fondo e non si riscrivono;
- ogni evento deve passare `bash scripts/lessons-ledger.sh validate`.

In CI `LESSONS_BASE_REF` punta al tip del branch base o al commit precedente al push: il controllo copre così l'intero range, non soltanto l'ultimo commit. Se il ref configurato non è disponibile localmente il gate fallisce invece di degradare silenziosamente.

Se il ledger non è scrivibile, lascia l'evento nel report del workspace come feedback pendente. Non bloccare un workspace già valido e non dichiarare aggiornato il contatore.

## Soglie

Conta soltanto eventi `generation` con `real=true`, deduplicati per `cycle_id` e `variant_id`.

- Prima occorrenza: registra la lezione, nessuna generalizzazione automatica.
- Seconda occorrenza: la variante è candidabile a una bozza; proponila all'utente, senza creare file.
- Terza occorrenza: la promozione è eleggibile solo se esiste un evento `approval` con `draft_state=approved` per la stessa variante.
- Guide, checklist e blueprint generici cambiano solo dopo segnale in almeno tre cicli reali distinti e approvazione esplicita.

`bash scripts/lessons-ledger.sh summary` mostra i conteggi; `eligible` mostra le azioni possibili. Il risultato è un segnale, non un'autorizzazione a scrivere.

## Preflight Git per una proposta approvata

1. Esegui `git status --short` e fermati se esistono cambi estranei.
2. Crea un branch o worktree dedicato quando l'ambiente lo supporta.
3. Limita il diff ai file approvati.
4. Esegui `bash scripts/validate-factory.sh` e `bash scripts/test-validators.sh`.
5. Mostra il diff e chiedi conferma prima del commit.
6. Stagia solo i path approvati; non eseguire push automatici.
7. Appendi l'evento `promotion` soltanto dopo l'applicazione riuscita.

## Livelli di protezione

- **Rilevamento automatico:** conteggi e candidabilità, senza scritture.
- **Modifica su approvazione:** blueprint, indice, guide, checklist, template e validatori.
- **Protetti:** `skills/agent-workspace-builder/SKILL.md` e `AGENTS.md`; richiedono una richiesta utente esplicita e specifica.

Una soglia non autorizza commit, push, installazioni, spese o accessi esterni.
