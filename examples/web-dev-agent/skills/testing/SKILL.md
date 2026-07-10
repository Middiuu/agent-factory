---
name: testing
description: Use this skill when validating web development changes with tests or checks.
---

# Testing

## Procedura

1. Richiedi `APP_ROOT` e `PACKAGE_MANAGER`, entra in `APP_ROOT` e imposta `TEST_SCRIPT="${TEST_SCRIPT:-test}"`.
2. Verifica che `TEST_SCRIPT` esista in `package.json`; se `TEST_TARGET` e' valorizzato esegui `"$PACKAGE_MANAGER" run "$TEST_SCRIPT" -- "$TEST_TARGET"`, altrimenti esegui `"$PACKAGE_MANAGER" run "$TEST_SCRIPT"`.
3. Leggi l'output reale: conta i test passati e falliti, non fidarti dell'exit code da solo.
4. Con test falliti il task non è completo: correggi o segnala, mai dichiarare completo.
5. Se il codice modificato non ha alcun test, scrivine almeno uno per il comportamento principale o registra l'assenza in `reports/` con motivazione.

## Validazione

- Output del comando di test riportato nel report (numero passati/falliti).
- Zero test falliti al momento della dichiarazione di completamento.
- Comando, directory `APP_ROOT`, package manager ed exit code sono registrati.
