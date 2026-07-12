# Eval della skill

`evals.json` definisce tre scenari sintetici e le aspettative verificabili. Il protocollo usa lo stesso prompt/input in `with_skill` e `without_skill` e richiede che rubriche, grading e output precedenti non siano mostrati agli esecutori. Run e transcript lo auto-attestano; senza trace raw del provider, l'isolamento non è verificabile indipendentemente.

## Evidenza persistita

```text
files/                         input sintetici dedicati
runs/iteration-1/
  eval-*/eval_metadata.json    prompt e aspettative correnti
  eval-*/with_skill/run-1/     output, transcript, run e grading
  eval-*/without_skill/run-1/  output, transcript, run e grading
  benchmark.json               risultati derivati dai grading
  benchmark.md                 riepilogo leggibile
  analysis-notes.json          osservazioni dell'analizzatore
  review.html                  viewer statico offline
results/
  2026-07-11-paired-benchmark.json  manifest canonico degli hash e dei limiti
```

Il vecchio file in `results/2026-07-10-minimal-native.json` resta uno snapshot storico esplicitamente non riproducibile; non è usato dal benchmark corrente.

## Procedura

1. Esegui ogni prompt con e senza skill da contesti puliti e senza mostrare `evals.json`, grading o output precedenti; conserva output, transcript e `run.json`.
2. Applica le aspettative correnti con un grader separato e salva `grading.json` usando i campi `text`, `passed` ed `evidence`.
3. Esegui il validator corrente su ogni workspace; non inferire timing, token o tool-call non esposti.
4. Genera benchmark e viewer tramite l'adattatore: l'aggregatore ufficiale di `skill-creator` viene eseguito come controllo di compatibilità, mentre il benchmark canonico è derivato direttamente dai grading; il template viewer ufficiale viene appiattito ricorsivamente e irrigidito con CSP, escaping e modalità offline.
5. Esegui l'analisi comparativa, rigenera il viewer con le note e scrivi il manifest degli hash.

Comandi dalla root della fabbrica:

```bash
SKILL_CREATOR_ROOT="${SKILL_CREATOR_ROOT:-$HOME/.agents/skills/skill-creator}"
bash scripts/build-eval-artifacts.sh --skill-creator-root "$SKILL_CREATOR_ROOT" \
  --notes skills/agent-workspace-builder/evals/runs/iteration-1/analysis-notes.json
bash scripts/validate-evals.sh --write-manifest
bash scripts/validate-evals.sh
bash scripts/test-evals.sh
```

La validazione richiede Bash, Python 3, utility Unix di base e il repository; la review usa un browser. `build-eval-artifacts.sh` serve solo per rigenerare benchmark e viewer e richiede anche una copia locale già installata di `skill-creator`, indicata da `SKILL_CREATOR_ROOT`.

## Limiti

- Una run per configurazione copre gli scenari ma non misura varianza statistica.
- La dispersione riportata descrive scenari eterogenei, non repliche dello stesso scenario.
- `output_chars` è usato come proxy deterministico nel campo `tokens` richiesto dal viewer; non è un conteggio token del provider.
- `time_seconds: 0` significa metrica non disponibile, non esecuzione istantanea.
- `tool_calls: 0` significa conteggio non disponibile, non assenza osservata di tool.
- `errors` conta i tentativi falliti del validator poi corretti; il PASS finale è verificato separatamente.
- Identificatori dei modelli, token, timing e tool call non osservati non vengono ricostruiti.
- I transcript sono resoconti manualmente persistiti, non trace raw del provider: isolamento e storia completa dei tool non sono dimostrabili in modo indipendente.
- Le eval sono sintetiche e non contano come generazioni reali per la governance dei blueprint.
