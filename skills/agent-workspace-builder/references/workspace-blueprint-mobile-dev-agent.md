# Blueprint: mobile development agent

## Purpose

Agente che assiste lo sviluppo di app mobile Android, iOS o cross-platform: codice, build, test su device/simulatore e ricerca documentazione.

## When to use

- L'utente chiede un agente per Flutter, React Native, Android nativo, iOS nativo o stack mobile simile.
- Servono comandi di build/run, device target, simulatori/emulatori o test mobile.
- Il workspace deve distinguere requisiti locali dell'utente da cio' che il builder puo' configurare.

## Typical inputs

- Stack mobile desiderato.
- Target supportati: Android, iOS, simulatore, device reale.
- Requisiti su test, build, release, store o integrazioni native.

## Expected outputs

Codice nel repository del progetto, build funzionanti, test verdi sui target dichiarati e report di stato in `reports/` quando richiesti.

## Recommended structure

```text
README.md
AGENTS.md
skills/
reports/
ROADMAP.md
```

Se il workspace agentico e il repository applicativo non coincidono, README e `AGENTS.md` definiscono `APP_ROOT`, lo verificano prima di build e test e mantengono i report nel workspace agentico. `ROADMAP.md` serve solo se il progetto e' lungo o prevede release progressive.

## Recommended local skills

Prima esegui la discovery come da `skill-selection-guide.md`: crea in locale solo cio' che non esiste gia'.

- `stack-dev`: solo se stack, struttura o comandi del progetto richiedono una procedura locale.
- `mobile-testing`: solo se target, soglie e matrice di test non sono gia' definiti dalle capacita' native o dal repository.
- Skill di release solo se store, firme o provisioning sono parte esplicita del lavoro.

## Possible tools / MCP / CLI

- CLI dello stack: `flutter`, `npx react-native`, Gradle wrapper `./gradlew`, `xcodebuild`.
- `adb` per Android e `xcrun simctl` per simulatori iOS.
- Framework nativi di test: XCTest, Espresso, `flutter test`, Jest/Detox.
- Appium solo se serve E2E cross-platform reale.
- MCP solo se aggiunge valore strutturato, ad esempio servizi di build o store.

## Validation criteria

- README dichiara requisiti reali: macOS/Xcode per iOS, Android SDK/emulatore per Android.
- Ogni comando applicativo viene eseguito da `APP_ROOT`; il workspace non viene confuso con il repository dell'app.
- L'agente verifica device o simulatori prima di usarli (`adb devices`, `xcrun simctl list`).
- Test e build hanno comandi documentati.
- Segreti, keystore, certificati e provisioning non sono nel repository.

## Mistakes to avoid

- Dare per scontato che un device sia collegato.
- Committare keystore, certificati o profili.
- Usare Appium quando i test nativi bastano.
- Installare SDK o tool globali senza trattarli come requisito dell'utente.
