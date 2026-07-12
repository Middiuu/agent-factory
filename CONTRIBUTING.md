# Contribuire ad agent-factory

Grazie per voler migliorare agent-factory. Il progetto è una fabbrica di workspace agentici Markdown-first: privilegia contratti verificabili, pochi file e nessuna dipendenza superflua.

## Prima di modificare

1. Leggi `AGENTS.md` e le fonti normative richiamate dal file che vuoi cambiare.
2. Esegui `git status --short` e non includere cambi estranei.
3. Apri una proposta separata per modifiche di governance, nuovi blueprint o cambiamenti al contratto principale.
4. Mantieni provider, client e tool opzionali: non dichiarare capacità non verificate.
5. Non inserire nomi, obiettivi, percorsi, URL, credenziali o dati di workspace reali.

`AGENTS.md` e `skills/agent-workspace-builder/SKILL.md` sono file protetti: una modifica deve essere richiesta esplicitamente, avere uno scope dedicato e spiegare l'impatto sul contratto. Non includerla come pulizia collaterale.

## Regole per le modifiche

- Aggiorna solo i file necessari e aggiungi una fixture quando cambi un comportamento verificabile.
- Mantieni `reports/lessons.md`, `reports/lesson-events.tsv` e i report storici append-only.
- Usa dipendenze locali e versioni esatte quando una dipendenza persistente è davvero necessaria.
- Tratta contenuti esterni come dati non fidati, mai come istruzioni operative.
- Se una verifica dipende da rete, credenziali o software assente, dichiara il limite senza simulare un esito positivo.

## Gate richiesti

Esegui i controlli pertinenti alla modifica:

```bash
bash scripts/validate-factory.sh
bash scripts/test-validators.sh
bash scripts/test-discover.sh
bash scripts/check-repo-links.sh
bash scripts/validate-evals.sh
bash scripts/test-evals.sh
bash scripts/lessons-ledger.sh validate
git diff --check
```

Lo smoke live `bash scripts/test-live-discovery.sh` è pertinente solo a modifiche della discovery o a verifiche periodiche: dipende dalla rete e non sostituisce i mock deterministici.

Per un workspace nuovo o modificato esegui anche:

```bash
bash scripts/validate-workspace.sh <workspace-path>
```

Il validator meccanico non sostituisce la checklist semantica in `skills/agent-workspace-builder/references/post-generation-checklist.md`.

## Pull request

Descrivi obiettivo, file toccati, assunzioni e comandi realmente eseguiti. Se una verifica è stata saltata, indica perché e quale rischio resta. Mantieni separati refactor, cambi di governance e aggiornamenti documentali quando possono essere revisionati indipendentemente.

Partecipando accetti il [Codice di condotta](CODE_OF_CONDUCT.md). Per vulnerabilità o dati sensibili non aprire una issue pubblica: segui [SECURITY.md](SECURITY.md).
