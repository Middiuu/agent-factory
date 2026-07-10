# AGENTS.md - mobile-dev-agent

## Workflow

1. Imposta `AGENT_WORKSPACE_ROOT` sulla root di questo workspace e richiedi `APP_ROOT` esplicito.
2. Verifica `test -f "$APP_ROOT/pubspec.yaml"`; non usare il workspace agentico come app di fallback.
3. Verifica Flutter SDK e il target richiesto prima di modificare codice.
4. Usa `skills/flutter-dev/SKILL.md` per task Flutter.
5. Usa `skills/mobile-testing/SKILL.md` per test e target.
6. Salva esiti importanti in `reports/` del workspace agentico con timestamp UTC.

## Root operative

```bash
AGENT_WORKSPACE_ROOT="${AGENT_WORKSPACE_ROOT:-$PWD}"
APP_ROOT="${APP_ROOT:?set APP_ROOT to the Flutter repository}"
test -f "$AGENT_WORKSPACE_ROOT/AGENTS.md"
test -f "$APP_ROOT/pubspec.yaml"
```

## Regole

- Verifica device o simulatore prima di usarli.
- Non committare certificati, keystore o provisioning.
- Dichiara requisiti locali invece di installarli automaticamente.
- Esegui `flutter`, Gradle, Xcode e test soltanto da `APP_ROOT`.
- Non modificare target, firme o lockfile incidentalmente.
- Non sovrascrivere report storici.

## Validazione

- Flutter SDK e `pubspec.yaml` sono verificati prima di ogni task.
- Il target dichiarato e' presente nell'output reale di `adb devices` o `xcrun simctl list devices`.
- `flutter analyze` ha zero errori e i test eseguiti hanno zero fallimenti prima del completamento.
- Il report registra target, comando, exit code e verifiche non eseguite.
