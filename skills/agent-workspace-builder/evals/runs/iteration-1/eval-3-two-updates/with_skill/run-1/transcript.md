# Eval 3 — two updates (`with_skill`)

Prompt eseguito: “Aggiorna due volte nello stesso giorno un workspace research esistente: prima aggiungi un formato executive summary, poi un controllo di qualità delle fonti. Preserva report e discovery precedenti.”

Metodo: `rubric_hidden_with_skill`. La definizione dell'eval, le rubriche, i grading, i transcript e gli output di run preesistenti non sono stati letti. L'unico input di workspace è stato `skills/agent-workspace-builder/evals/files/research-seed`, copiato in una directory temporanea prima delle modifiche.

## Timeline UTC

- `2026-07-11T07:43:27Z`: avvio della run operativa e copia del seed nel workspace temporaneo.
- `2026-07-11T07:44:16Z`: creazione del primo report update, `reports/2026-07-11-074416-update.md`.
- `2026-07-11T07:45:10Z`: primo validator del ciclo 1, `PASS` con exit code `0`; dopo la registrazione dell'esito nel report, il validator è stato rilanciato ed è rimasto `PASS`/`0`.
- `2026-07-11T07:46:13Z`: creazione del secondo report update, `reports/2026-07-11-074613-update.md`.
- `2026-07-11T07:47:24Z`: primo validator del ciclo 2, `PASS` con exit code `0`; dopo la registrazione dell'esito nel report, il rilancio finale è rimasto `PASS`/`0`.
- `2026-07-11T07:48:26Z`: sostituzione autorizzata di `outputs/workspace`, validator della copia confezionata `PASS`/`0` e confronto del manifest `IDENTICAL`.
- `2026-07-11T07:49:09Z`: scrittura degli artefatti descrittivi della run.
- `2026-07-11T07:51:22Z`: verifica finale di JSON, hash e seed, ulteriore validator `PASS`/`0` sul workspace confezionato e completamento della run.

## Step 1 — formato executive summary

Sono stati modificati `README.md`, `AGENTS.md` e `skills/web-research/SKILL.md`. Il formato rende `## Executive summary` la prima sezione del corpo e richiede, nell'ordine, risposta breve, 2-4 evidenze decisive citate, 1-3 implicazioni e livello di confidenza con limite principale.

È stato aggiunto un solo report univoco. `RESEARCH.md` e il report di generazione sono rimasti byte-identici al seed. Non è stata eseguita nuova discovery perché non sono state introdotte capacità esterne, skill nuove, MCP o CLI.

Il controllo mirato iniziale ha restituito `FAIL` per una regex locale troppo restrittiva sul titolo e sulla formulazione di `AGENTS.md`; non era il validator del workspace. L'ispezione puntuale ha confermato il contenuto richiesto e il controllo è stato corretto senza alterare lo scopo dell'update. Entrambi i tentativi del validator effettivo hanno restituito exit code `0`.

## Step 2 — controllo qualità delle fonti

Gli stessi tre file operativi sono stati estesi con un registro per fonte e claim. Il controllo assegna punteggi `0-2` a provenienza, supporto diretto, attualità e indipendenza, classifica il totale `0-8` e applica soglie osservabili: una fonte con `0` in provenienza o supporto non sostiene claim centrali; un claim decisivo richiede una fonte alta oppure due fonti almeno medie e indipendenti, altrimenti resta `[incerto]`.

È stato aggiunto il secondo report univoco. `RESEARCH.md`, il report di generazione e il report del primo update sono rimasti byte-identici rispetto allo stato immediatamente precedente. Anche questo update non ha richiesto nuova discovery o tooling.

## Validazione osservata

Comando dei due cicli temporanei:

```bash
bash "$FACTORY_ROOT/scripts/validate-workspace.sh" "$WORKSPACE_ROOT"
```

Comando della copia confezionata:

```bash
bash scripts/validate-workspace.sh "$TARGET_WORKSPACE"
```

| Fase | Tentativi validator | Esito finale | Exit code finale |
|---|---:|---|---:|
| Update 1 | 2 | PASS | 0 |
| Update 2 | 2 | PASS | 0 |
| Workspace confezionato | 2 | PASS | 0 |

Il validator finale ha riconosciuto tre report formali preservati, riferimenti interni risolti, nessun placeholder, nessun percorso assoluto locale, nessun segreto e salvaguardie web semantiche complete.

## Hash e confronti

Algoritmo: SHA-256. Gli hash di stato sono calcolati sul manifest ordinato delle righe `<sha256-file>  ./<path-relativo>`.

| Evidenza | SHA-256 / confronto |
|---|---|
| Manifest seed, 5 file | `a0773fc63ae29211ff93446dfeae5c9586643ce9a0ac203dd2aaa2d3e8eaa9ef` |
| Manifest dopo update 1, 6 file | `6c2e64024fc4242e81910912a32aef8965e6dca8949e8ae8e4bfd578c9a53601` |
| Manifest finale, 7 file | `4e0da3fd796234ba5f2d41673c4ef2885dc13db6c58bb0009a439eb16201c512` |
| Manifest workspace confezionato | `4e0da3fd796234ba5f2d41673c4ef2885dc13db6c58bb0009a439eb16201c512` (`IDENTICAL` al finale temporaneo) |
| `RESEARCH.md` seed/finale | `5f0145e8c7ed935933f11bdd0d5eb2a7fb9b5c6606c5d7587d03acc636dff2ad` (`IDENTICAL`) |
| Report generazione seed/finale | `09794ff407c94ce2b124917eee18e781be1c3430f910a8841bc01418983a51f0` (`IDENTICAL`) |
| Report update 1 dopo step 1/finale | `9b7637c9f41026399bc528fa86df32b739f1d3eeb47f8e32ff2537d94106d919` (`IDENTICAL`) |
| Report update 2 finale | `7d4c63ddbb8cb107562cc66ed86aef365db8b083e707e7cf6d23222f91796e78` |

Confronto dei path: dal seed al primo update sono cambiati `README.md`, `AGENTS.md` e `skills/web-research/SKILL.md`, con l'aggiunta del primo report; dal primo al secondo update sono cambiati gli stessi tre file, con l'aggiunta del secondo report. Nessun altro file del workspace è cambiato.

Esito della run: `passed`, determinato esclusivamente dagli exit code `0` osservati dopo entrambi gli update e confermato sul workspace confezionato. Grading indipendente ancora pendente; metriche provider non disponibili.
