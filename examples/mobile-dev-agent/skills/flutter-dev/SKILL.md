---
name: flutter-dev
description: Use this skill when working on Flutter application code and project conventions.
---

# Flutter Dev

## Procedura

1. Richiedi `APP_ROOT="${APP_ROOT:?set APP_ROOT to the Flutter repository}"`, verifica `test -f "$APP_ROOT/pubspec.yaml"` e `command -v flutter`.
2. Entra in `APP_ROOT` e registra `flutter --version`; se fallisce, fermati e segnala il requisito all'utente.
3. Usa la struttura esistente (`lib/`, `test/`, `pubspec.yaml`); non inventare layout alternativi.
4. Esegui `flutter pub get` solo se il task modifica dipendenze o la risoluzione e' necessaria; non cambiare il lockfile incidentalmente.
5. Dopo ogni modifica esegui `flutter analyze`: zero errori prima di proseguire.
6. Documenta nel report i comandi di run/build realmente eseguiti, non quelli teorici.
7. Passa a `skills/mobile-testing/SKILL.md` per la validazione.

## Validazione

- `flutter analyze` senza errori.
- I comandi citati nel report sono stati eseguiti davvero (output incluso).
- Tutti i comandi applicativi hanno come directory di lavoro `APP_ROOT`.
