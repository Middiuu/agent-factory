---
name: mobile-testing
description: Use this skill when validating mobile changes on tests, simulators, or devices.
---

# Mobile Testing

## Procedura

1. Richiedi `APP_ROOT`, entra in `APP_ROOT` e verifica il target prima di usarlo: `adb devices` per Android, `xcrun simctl list devices` per simulatori iOS.
2. Imposta facoltativamente `TEST_FILE`; se valorizzato esegui `flutter test "$TEST_FILE"`, altrimenti esegui `flutter test`.
3. Leggi l'output reale e registra test passati, falliti ed exit code.
4. Con test falliti il task non è completo.
5. Registra in `reports/` del workspace agentico i target non disponibili e le verifiche saltate, con il comando che lo dimostra.

## Validazione

- L'output di `adb devices` o `simctl list` è riportato quando si dichiara un target usato o assente.
- Zero test falliti al momento della dichiarazione di completamento.
- Ogni comando viene eseguito da `APP_ROOT` e il report indica il target effettivo.
