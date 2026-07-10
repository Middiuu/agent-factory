# agent-factory — refactor 2026-07-10

Timestamp audit: `2026-07-10T08:47:05Z`

Provenienza iniziale: commit `76d41b7`, worktree dirty durante il refactor. La nuova history Git viene inizializzata soltanto dopo i gate finali; il commit radice risultante contiene questo report.

## Obiettivo

Portare la fabbrica da prototipo documentale avanzato a sistema con contratti coerenti, gate semantici, discovery bounded, feedback auditabile e privacy forward-safe.

## Ambito

- contratto principale e istruzioni operative;
- blueprint, guide, checklist, template ed esempi;
- discovery, validator, fixture negative e CI;
- ledger, soglie e governance delle modifiche;
- documentazione, compatibilità e privacy;
- eval sintetica della skill prima/dopo il refactor;
- ricreazione finale della history Git locale autorizzata dall'utente.

## Modifiche principali

- Le skill locali sono opzionali quando capacità native verificate coprono il task.
- I report formali usano timestamp UTC e nomi collision-resistant.
- `RESEARCH.md` distingue cercato, trovato, scelto, scartato, errori e comandi reali.
- La discovery applica timeout anche a npm e Homebrew e separa assenza, zero risultati ed errore di rete.
- I validator controllano setup, report, timestamp, riferimenti, placeholder, path macchina, segreti moderni e safety web-facing positiva.
- Il report corrente registra copertura e provenance clean/dirty; suffissi numerici evitano collisioni senza riscrivere report storici.
- Link e symlink restano confinati al workspace; safety e privacy coprono anche API/feed e la fabbrica stessa.
- Fixture isolate dimostrano i failure mode; la discovery usa mock deterministici.
- `lesson-events.tsv` sostituisce il contatore manuale con eventi opachi, deduplicazione e soglie derivate.
- Il gate append-only usa il base ref di PR/push e intercetta riscritture nascoste in range multi-commit.
- Le soglie producono candidabilità, mai auto-modifiche; ogni cambiamento generale richiede approvazione e preflight Git.
- Configurazioni MCP persistenti richiedono versioni esatte, dipendenze locali e threat review; invocazioni non pinning restano solo discovery isolata.
- I blueprint generici non contengono più conoscenza geospaziale derivata da un singolo caso.
- I quattro esempi sono fixture sintetiche complete, non dichiarazioni narrative di conformità.
- README e overview descrivono compatibilità per capacità, limiti dei client e distinzione fra history locale e remoto.
- Un path assoluto legacy rimasto nel working tree è stato redatto prima della nuova history.

## Validazione

Gate eseguiti durante il refactor:

```bash
bash -n scripts/*.sh
bash scripts/validate-factory.sh
bash scripts/test-validators.sh
bash scripts/test-discover.sh
bash scripts/lessons-ledger.sh validate
bash scripts/lessons-ledger.sh summary
bash scripts/lessons-ledger.sh eligible
git diff --check
```

Risultati dell'ultimo gate completo prima del re-init Git:

- factory validator: PASS;
- workspace validator: 4 fixture positive e 4 esempi PASS;
- failure mode workspace: 15/15 rilevati per il motivo previsto; regressioni factory dedicate: 3/3;
- ledger: fixture valida, duplicato ed enum invalido verificati; append valido, riscritture staged e range multi-commit coperti; comandi reali PASS;
- discovery mockata: 19/19 assertion PASS;
- sintassi shell e whitespace diff: PASS.

Un audit indipendente successivo al primo refactor ha individuato drift non intercettati dai gate iniziali (schema report, privacy, secret bypass, append-only multi-commit, indice blueprint e supply chain MCP). Le relative correzioni e regressioni sono incluse nei conteggi sopra; il gate completo è stato rilanciato dopo l'ultima modifica.

## Snapshot valutativo della skill

Scenario: workspace minimale per organizzare file Markdown con capacità native sufficienti.

| Configurazione | Esito |
|---|---|
| Skill refactor | 5/5 aspettative |
| Snapshot precedente `76d41b7` | 2/5 aspettative |

Lo snapshot indica che la skill refactor evita una skill locale ridondante e un `RESEARCH.md` artificiale, produce un report timestampato e ha passato il validator usato nella run. La baseline dichiarata passa il validator storico ma fallisce le tre nuove invarianti. Il successivo hardening dello schema report è dichiarato come limite; timing e token non erano esposti dal runner e non vengono confrontati.

Il manifest è in `skills/agent-workspace-builder/evals/results/2026-07-10-minimal-native.json`. È uno snapshot auto-dichiarato e direzionale: output e hash non sono persistiti e la baseline verrà esclusa dalla nuova history, quindi il confronto non è riproducibile né evidenza indipendente. Non viene usato come garanzia cross-provider.

## Privacy e Git

La nuova history locale rimuove la linea precedente dalla copia di lavoro. Questo non risana automaticamente il remoto, fork, cache o cloni. Nessun push o force-push è parte di questo refactor.

## Limiti e follow-up

- Eseguire un collaudo reale per mobile e automation prima di promuoverne lo stato nell'indice.
- Espandere le eval a più prompt e client quando il costo di esecuzione lo giustifica.
- Pubblicare la nuova history soltanto con un'operazione separata, coordinata e verificata.

## Lezioni per la fabbrica

- Le invarianti importanti devono essere condivise da contratto, template, fixture e validator.
- Un gate verde su documenti sintetici non prova utilità operativa; servono casi positivi completi e failure isolate.
- Privacy, feedback e auto-evoluzione richiedono strutture auditabili, non sole istruzioni prose.
- La portabilità è una matrice di capacità collaudate, non un'etichetta universale.
