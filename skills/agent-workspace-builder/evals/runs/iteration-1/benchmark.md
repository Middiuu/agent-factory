# Skill Benchmark: agent-workspace-builder

**Evidence class**: exploratory paired evidence
**Executor model**: not captured per run
**Grader model**: not captured per grading
**Analyzer model**: not captured in persisted analyzer notes
**Evidence timestamp**: 2026-07-11T07:55:38Z
**Evals**: 1, 2, 3
**Runs per configuration**: 1

## Summary

| Metric | With skill | Without skill | Delta |
|---|---:|---:|---:|
| Pass rate | 100.0% | 80.6% | +19.0 pp |
| Output characters (token proxy) | 29809 | 20380 | +9429 |
| Provider timing | not captured | not captured | — |

The reported standard deviation is descriptive dispersion across heterogeneous eval scenarios, not replicate variance.

## Per-eval results

| Eval | Configuration | Passed | Total | Pass rate |
|---:|---|---:|---:|---:|
| 1 — minimal-native | with_skill | 9 | 9 | 100.0% |
| 1 — minimal-native | without_skill | 6 | 9 | 66.7% |
| 2 — weekly-web-monitor | with_skill | 8 | 8 | 100.0% |
| 2 — weekly-web-monitor | without_skill | 6 | 8 | 75.0% |
| 3 — two-updates | with_skill | 8 | 8 | 100.0% |
| 3 — two-updates | without_skill | 8 | 8 | 100.0% |

## Analysis notes

- [Dati osservati] Sulle 25 aspettative correnti, with_skill ne supera 25 e without_skill 20. Il divario è concentrato in cinque aspettative degli eval 1 e 2; le altre 20 passano in entrambe le configurazioni. Nessuna aspettativa passa soltanto senza_skill e nessuna fallisce in entrambe.
- [Potere discriminante — eval 1 minimal-native] Il risultato è 9/9 con_skill contro 6/9 senza_skill. Le tre aspettative discriminanti sono il preflight esplicito insieme agli altri gate operativi, la gestione dei collegamenti Markdown relativi durante gli spostamenti e la sezione README di validazione con comando autonomo; le altre sei passano in entrambe le configurazioni.
- [Potere discriminante — eval 2 weekly-web-monitor] Il risultato è 8/8 con_skill contro 6/8 senza_skill. Le due aspettative discriminanti sono la distinzione in RESEARCH.md fra fonti non raggiungibili e zero risultati e il rifiuto, prima della persistenza, sia della userinfo sia dei parametri query simili a credenziali; le altre sei passano in entrambe.
- [Potere discriminante — eval 3 two-updates] Il risultato è 8/8 in entrambe le configurazioni. Passano su entrambi i rami sia le due aspettative semantiche aggiunte — executive summary applicato da ogni nuovo report e gate verificabile sulla qualità delle fonti — sia le sei aspettative di integrità, append condizionale, modifica minima, naming e validazione; questa singola coppia di run non distingue quindi il contributo della skill.
- [Differenza tra output non riflessa dal punteggio — eval 3] Entrambe le configurazioni producono due report con `## Executive summary` e un gate documentato sulla qualità delle fonti. Il confronto con il seed mostra però che with_skill aggiorna README.md, AGENTS.md e la skill locale web-research, mentre without_skill aggiorna README.md e AGENTS.md lasciando la skill locale byte-identica; entrambe ottengono comunque 8/8.
- [Dispersione cross-eval] I pass rate with_skill sono 100%, 100% e 100%, mentre quelli without_skill sono 66,7%, 75% e 100% negli eval 1, 2 e 3. La deviazione riportata nel riepilogo descrive la dispersione fra tre scenari eterogenei, non varianza fra repliche dello stesso scenario.
- [Pattern di validazione] Il campo errors registra 2, 1 e 0 tentativi di validator falliti nelle run with_skill e 1, 1 e 0 nelle run without_skill: tre contro due complessivi. Le evidenze registrano separatamente il validator finale PASS per tutte e sei le run, quindi questi valori rappresentano iterazioni corrette durante l'esecuzione e non fallimenti finali.
- [Caratteri di output] Il proxy vale 12.520 contro 6.151 nell'eval 1, 59.649 contro 39.541 nell'eval 2 e 17.258 contro 15.454 nell'eval 3 (with_skill contro without_skill). With_skill è più esteso in tutti e tre gli scenari; l'aumento medio di 9.427 caratteri è concentrato soprattutto nell'eval 2, dove la differenza è 20.108 caratteri.
- [Limiti delle metriche] Il campo tokens contiene caratteri di output e non token del provider; time_seconds pari a 0 significa durata non catturata; tool_calls pari a 0 non dimostra assenza di uso di tool perché il conteggio non è stato esposto. Anche i modelli di executor, grader e analyzer non sono stati catturati negli artefatti, quindi non è possibile attribuire o confrontare i risultati per identità del modello.
- [Limiti dell'evidenza] Esiste una sola run per ogni coppia eval/configurazione, perciò stabilità, flakiness e varianza entro lo stesso scenario non sono osservabili. L'isolamento delle rubriche è documentato tramite auto-attestazioni `rubric_visibility` nei run e nei transcript, ma non sono disponibili raw provider traces: l'esecuzione rubric-hidden non è quindi verificabile indipendentemente oltre agli artefatti persistiti.

## Method and metric limits

Provider model identifiers, token counts, tool-call counts and wall-clock duration were not captured and are not inferred. The `tokens` field required by the standard viewer contains output character counts as a deterministic proxy; `time_seconds: 0` means unavailable, not zero execution time.

There is one run per configuration. Transcripts are manually persisted execution summaries rather than raw provider traces, so execution isolation and complete tool history are not independently provable.
