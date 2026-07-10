# mobile-dev-agent

Workspace esempio autonomo per guidare task Flutter, test e verifiche target senza incorporare l'app mobile.

## Prompt iniziale

```text
Voglio un agente mobile che mi aiuti con Flutter, simulatore e test.
```

## Quickstart

1. Dalla root dell'app Flutter esegui `export APP_ROOT="$PWD"`.
2. Apri questo workspace nello stesso ambiente con un coding agent che legge `AGENTS.md`.
3. L'agente verifica SDK, `APP_ROOT` e target prima di usare le skill in `skills/`.
4. Codice e test restano nell'app; esiti e limiti vengono salvati in `reports/` del workspace agentico.

## Setup obbligatorio

- Un'app Flutter esistente indicata da `APP_ROOT`, con `pubspec.yaml`.
- Flutter SDK installato dall'utente come requisito di piattaforma.

Verifica:

```bash
APP_ROOT="${APP_ROOT:?run export APP_ROOT from the Flutter application root}"
test -f "$APP_ROOT/pubspec.yaml"
command -v flutter
flutter --version
```

Il builder non installa SDK globali e non modifica configurazioni di piattaforma.

## Setup opzionale

- Android: Android SDK, un device/emulatore e `adb`, verificati con `command -v adb` e `adb devices`.
- iOS: macOS con Xcode e un simulatore, verificati con `command -v xcrun` e `xcrun simctl list devices`.
- Device reale, firme, provisioning e procedure store soltanto quando esplicitamente richiesti.
- Appium e MCP non sono necessari per unit/widget test Flutter.

## Struttura

```text
README.md
AGENTS.md
skills/
  flutter-dev/SKILL.md
  mobile-testing/SKILL.md
reports/
  2026-07-10-074530-generation.md
RESEARCH.md
```

## Output attesi

Codice e test nell'app `APP_ROOT`; report `reports/YYYY-MM-DD-HHMMSS-mobile-task.md` con target, comandi, exit code, test passati/falliti, verifiche saltate e limiti.

## Validazione autonoma

```bash
AGENT_WORKSPACE_ROOT="${AGENT_WORKSPACE_ROOT:-$PWD}"
APP_ROOT="${APP_ROOT:?set APP_ROOT before validation}"
test -f "$AGENT_WORKSPACE_ROOT/AGENTS.md"
test -f "$AGENT_WORKSPACE_ROOT/RESEARCH.md"
test -d "$AGENT_WORKSPACE_ROOT/skills"
test -d "$AGENT_WORKSPACE_ROOT/reports"
test -f "$APP_ROOT/pubspec.yaml"
```
