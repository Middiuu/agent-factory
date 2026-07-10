# automation-agent

Workspace esempio autonomo per monitorare pagine web, confrontare run e conservare un audit log riproducibile.

## Prompt iniziale

```text
Voglio un agente che controlli pagine web ogni settimana, segnali cambiamenti e salvi un log.
```

## Quickstart

1. Apri la root del workspace con un coding agent che legge `AGENTS.md`.
2. Esegui `skills/site-monitor/SKILL.md` manualmente per creare la prima baseline.
3. Nelle run successive confronta valori canonici e hash con l'ultimo report `run` in `reports/`.
4. Configura uno scheduler solo dopo una run manuale riuscita e con approvazione dell'utente.

## Setup obbligatorio

Servono `curl` e almeno un comando SHA-256. Verifica:

```bash
command -v curl
curl --version
command -v shasum || command -v sha256sum
```

Questo esempio effettua al massimo una richiesta per target per run e non richiede credenziali.

## Setup opzionale

- Scheduler locale o della piattaforma agentica per il trigger settimanale; non viene configurato automaticamente.
- Browser automation soltanto per un target futuro che non sia leggibile via fetch semplice.
- Canale di notifica soltanto dopo conferma esplicita; senza canale, il report locale resta l'output completo.

## Trigger

L'obiettivo e' un controllo settimanale. In questo esempio lo scheduler non e' configurato: esegui manualmente la skill oppure configura uno scheduler locale approvato dall'utente.

## Target e criteri

| ID | URL | Valori canonici | Cambiamento significativo |
|---|---|---|---|
| `example-home` | `https://example.com/` | stato HTTP, titolo pagina | cambia stato HTTP o titolo |
| `iana-example-domains` | `https://www.iana.org/help/example-domains` | stato HTTP, titolo pagina | cambia stato HTTP o titolo |

Un hash SHA-256 diverso con valori canonici invariati e' una `variazione-tecnica`, non una modifica significativa. Una run e' `invariata` solo quando coincidono valori canonici e hash.

## Struttura

```text
README.md
AGENTS.md
skills/
  site-monitor/SKILL.md
reports/
  2026-07-10-074530-generation.md
RESEARCH.md
```

## Output attesi

Report `reports/YYYY-MM-DD-HHMMSS-run.md` con target, URL, timestamp UTC, stato HTTP, titolo normalizzato, hash SHA-256, baseline usata, classificazione ed errori.

## Validazione autonoma

```bash
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$PWD}"
test -f "$WORKSPACE_ROOT/AGENTS.md"
test -f "$WORKSPACE_ROOT/RESEARCH.md"
test -f "$WORKSPACE_ROOT/skills/site-monitor/SKILL.md"
test -d "$WORKSPACE_ROOT/reports"
```
