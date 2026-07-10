---
name: react-dev
description: Use this skill when working on React application code and project conventions.
---

# React Dev

## Procedura

1. Richiedi `APP_ROOT="${APP_ROOT:?set APP_ROOT to the React repository}"` e verifica `test -f "$APP_ROOT/package.json"`.
2. Entra in `APP_ROOT`. Rileva il package manager dal lockfile: `pnpm`, `yarn` o `npm`; se manca un lockfile, chiedi una scelta.
3. Leggi gli script con `node -e 'const p=require(process.env.APP_ROOT + "/package.json"); console.log(p.scripts || {})'`; usa solo script che esistono.
4. Mantieni i componenti piccoli: un componente per file, e se un file supera circa 150 righe valuta di scomporlo in base alle responsabilita'.
5. Dopo ogni modifica esegui lo script `lint`, se presente, tramite `"$PACKAGE_MANAGER" run lint`; zero errori prima di proseguire.
6. Aggiorna documentazione o report se il task cambia workflow o comandi.
7. Rimanda a `skills/testing/SKILL.md` per la validazione: nessun task e' completo senza di essa.

## Validazione

- Gli script citati nel report esistono in `package.json`.
- Lint eseguito senza errori, oppure la sua assenza è dichiarata nel report.
- Tutti i comandi applicativi hanno come directory di lavoro `APP_ROOT`.
