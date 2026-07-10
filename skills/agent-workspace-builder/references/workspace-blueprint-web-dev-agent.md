# Blueprint: web development agent

## Purpose

Agente che assiste lo sviluppo di applicazioni web: codice, test, ricerca documentazione e automazione browser quando serve.

## When to use

- L'utente chiede un agente per sviluppare o mantenere una web app.
- Sono rilevanti framework, test, build, lint, browser automation o documentazione tecnica.
- Il workspace deve guidare un coding agent dentro un progetto web esistente o futuro.

## Typical inputs

- Stack richiesto, ad esempio React, Vue, Svelte, Next.js o backend collegato.
- Comandi attesi per dev, build, lint e test.
- Requisiti su browser, API, deploy o integrazioni.

## Expected outputs

Codice nel repository del progetto, test verdi, comandi documentati e report di avanzamento o review in `reports/` quando richiesti.

## Recommended structure

```text
README.md
AGENTS.md
skills/
reports/
ROADMAP.md
```

Il codice applicativo vive nella struttura standard del framework, ad esempio `src/`. Se il workspace agentico e il repository applicativo non coincidono, README e `AGENTS.md` definiscono `APP_ROOT`, lo verificano prima di ogni comando e mantengono i report nel workspace agentico. `ROADMAP.md` serve solo per progetti lunghi.

## Recommended local skills

Prima esegui la discovery come da `skill-selection-guide.md`: crea in locale solo cio' che non esiste gia'.

- `framework-dev`: solo se stack, convenzioni o comandi del progetto richiedono una procedura locale.
- `testing`: solo se la strategia e le soglie del progetto non sono gia' definite nelle istruzioni o negli script nativi.
- Skill di deploy o accessibility solo se richieste dal progetto.

## Possible tools / MCP / CLI

- Package manager locale al progetto (`npm`, `pnpm`, `yarn`) con dipendenze versionate.
- `git` e, se serve repository remoto, `gh`.
- Playwright come dipendenza locale per E2E sui flussi critici.
- MCP browser solo se serve interazione guidata oltre Playwright o capacita' native.
- Docs search via web search nativa o MCP mantenuto se il framework lo giustifica.

## Validation criteria

- Setup, build, lint e test sono documentati e verificabili.
- Ogni comando applicativo viene eseguito da `APP_ROOT`; il workspace non viene confuso con il repository dell'app.
- Ogni feature non banale ha almeno un test significativo.
- Non si dichiara completo un task con test falliti.
- README e `AGENTS.md` concordano su stack, comandi e fallback.

## Mistakes to avoid

- Aggiungere un package manager non richiesto.
- Installare CLI globalmente senza necessita'.
- Creare struttura applicativa inventata invece di seguire il framework.
- Confondere il workspace dell'agente con il codice applicativo da generare.
