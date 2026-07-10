# RESEARCH.md - mobile-dev-agent

Discovery originaria: `2026-07-10T07:45:30Z`. Snapshot pre-refactor: gli esiti restano storici; la procedura unificata è stata poi corretta e rivalidata.

## Assunzioni

- Il workspace contiene istruzioni agentiche, non una copia dell'app Flutter.
- Android e iOS sono target opzionali: i requisiti diventano obbligatori solo quando il task li richiede.

## Cercato

| Capacita' richiesta | Fonte | Query o verifica | Esito |
|---|---|---|---|
| Flutter SDK | PATH e Homebrew | verifica `flutter`, ricerca formula/cask | SDK assente; pacchetto reperibile |
| target Android | PATH locale | verifica `adb` | assente |
| target iOS | PATH locale | verifica `xcrun` | comando presente, simulatore non verificato |
| skill mobile pubbliche | registry ufficiale | elenco delle skill pubblicate | nessuna skill Flutter equivalente |
| app e test reali | repository target | verifica `APP_ROOT/pubspec.yaml` | non verificabile: app non inclusa |

## Trovato

- Flutter SDK non era installato nell'ambiente di generazione.
- `brew search flutter` mostrava un'opzione installabile, ma una SDK globale resta responsabilita' dell'utente.
- `xcrun` era presente; `adb` era assente. La presenza del comando non prova che esista un simulatore avviabile.
- Nessuna app o target e' incorporato nell'esempio.

## Scelto

- Flutter SDK e `APP_ROOT` come prerequisiti obbligatori dichiarati, non installati dal builder.
- Skill locali `flutter-dev` e `mobile-testing` per root, target e soglie di validazione specifiche.
- Tool Android/iOS come setup opzionale condizionato dal target.

## Scartato

- Installazione automatica di Flutter, Android SDK o Xcode: scartata perche' globale e dipendente dalla piattaforma.
- Appium: non adottato perche' unit e widget test Flutter coprono il minimo.
- MCP mobile/build: non adottato senza un servizio richiesto.
- Creazione di un'app demo: scartata per non confondere workspace e codice applicativo.

## Comandi eseguiti

Primo passaggio obbligatorio dalla root della fabbrica:

```bash
DISCOVERY_TERM="flutter mobile"
FACTORY_ROOT="${FACTORY_ROOT:?set FACTORY_ROOT to the agent-factory repository}"
cd "$FACTORY_ROOT"
bash scripts/discover.sh "$DISCOVERY_TERM" all
```

Nello snapshot pre-refactor il passaggio si e' interrotto alla prima fonte con `curl_args[@]: unbound variable`; sono state completate verifiche locali:

```bash
command -v flutter || true
TOOL_NAME="flutter"
brew search "$TOOL_NAME"
```

```bash
command -v adb || true
command -v xcrun || true
```

```bash
SKILLS_API_URL="https://api.github.com/repos/anthropics/skills/contents/skills"
curl --fail --silent --show-error --max-time 20 "$SKILLS_API_URL" | jq -r '.[].name' | sort
```

Rivalidazione della procedura dopo il fix:

```bash
FACTORY_ROOT="${FACTORY_ROOT:?set FACTORY_ROOT to the agent-factory repository}"
cd "$FACTORY_ROOT"
bash scripts/test-discover.sh
```

Esito: 19/19 assertion deterministiche PASS, inclusi timeout, URL encoding e distinzione fra assenza e fonte non raggiungibile.

## Discovery incompleta

Flutter, app, device ed emulatori non erano disponibili insieme, quindi build e test non sono dichiarati verificati. La disponibilita' di Xcode e dei simulatori va controllata sul sistema che eseguira' il task.

## Note di sicurezza

- SDK e tool globali restano requisiti espliciti dell'utente.
- Certificati, keystore, provisioning e credenziali non entrano nel workspace.
- Release e pubblicazione richiedono sempre conferma umana.
