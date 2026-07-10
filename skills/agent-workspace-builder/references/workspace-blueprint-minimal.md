# Blueprint: workspace minimale

## Purpose

Punto di partenza per agenti semplici o non coperti dai blueprint dedicati. Resta adattabile: non copiare sezioni inutili nel workspace finale.

## When to use

- L'obiettivo non corrisponde a research, web dev, mobile dev o automation.
- L'agente ha una capacita' principale e nessun tool esterno indispensabile.
- Non e' ancora chiaro quali MCP/CLI serviranno.
- L'utente chiede esplicitamente una base leggera.

## Typical inputs

- "Voglio un agente che mi aiuti con una procedura specifica."
- Una procedura ricorrente ma circoscritta.
- Un progetto con pochi vincoli tecnici.

## Expected outputs

- `README.md` con scopo, uso e output.
- `AGENTS.md` con procedura operativa e limiti.
- `skills/`, anche vuota quando la capacita' e' gia' coperta da istruzioni o tool nativi verificati.
- `reports/` per output futuri.

## Recommended structure

```text
README.md
AGENTS.md
skills/
reports/
```

## Recommended local skills

Prima esegui la discovery come da `skill-selection-guide.md`. Crea una sola skill locale quando serve una procedura ripetibile specifica del progetto; altrimenti lascia `skills/` vuota e documenta in `RESEARCH.md` o nel report quale capacita' nativa la rende superflua.

Non aggiungere skill generiche che il coding agent sa gia' eseguire.

## Possible tools / MCP / CLI

- Capacita' native del coding agent.
- CLI gia' presenti e verificate con `which`.
- MCP solo se la discovery mostra un'integrazione mantenuta e realmente necessaria.

## Validation criteria

- Esistono `README.md`, `AGENTS.md`, `skills/` e `reports/`.
- Ogni skill presente ha frontmatter `name` e `description`; zero skill e' valido quando la copertura nativa e' verificata e motivata.
- L'obiettivo dell'utente e' coperto da una procedura chiara.
- Ogni file oltre la base ha uno scopo operativo chiaro; nessun tool citato senza verifica.

## Mistakes to avoid

- Creare piu' skill per una capacita' semplice.
- Aggiungere roadmap, MCP o script "per dopo".
- Usare il blueprint come template rigido invece di adattarlo.
- Omettere discovery solo perche' il workspace e' minimale.
