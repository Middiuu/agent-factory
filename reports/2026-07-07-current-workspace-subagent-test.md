# Current workspace subagent test - 2026-07-07

## Obiettivo

Avviare un workflow con subagent per testare i workspace esempio correnti in `examples/`.

## Subagent avviati

- Fermat: `examples/research-agent` e `examples/automation-agent`.
- Bernoulli: `examples/web-dev-agent` e `examples/mobile-dev-agent`.
- Maxwell: revisione sistemica di validator, CI ed esempi.

## Esiti

- `examples/research-agent`: validazione passata; skill citate esistenti; nessun placeholder, path locale o file vietato.
- `examples/automation-agent`: validazione passata; skill citata esistente; trigger settimanale esplicitato dopo la revisione.
- `examples/web-dev-agent`: validazione passata; skill citate esistenti; roadmap coerente.
- `examples/mobile-dev-agent`: validazione passata; skill citate esistenti; roadmap coerente.

## Problemi emersi

- I `RESEARCH.md` degli esempi research e automation erano troppo sintetici e non mostravano comandi di discovery.
- L'esempio automation citava un controllo settimanale senza spiegare che lo scheduler non e' configurato nell'esempio.
- I report dentro `examples/*-agent/reports/` erano chiamati `generation`, creando ambiguita' con i report finali della fabbrica.
- La GitHub Action validava la fabbrica ma non i workspace esempio.
- `validate-workspace.sh` non controllava riferimenti espliciti a `skills/*/SKILL.md`.

## Correzioni applicate

- Aggiunti comandi di discovery minimi nei `RESEARCH.md` degli esempi research e automation.
- Esplicitato il trigger settimanale non configurato nell'esempio automation.
- Rinominati i report degli esempi come `example-run`.
- Estesa la GitHub Action con la validazione dei quattro workspace esempio.
- Aggiunto a `validate-workspace.sh` un controllo leggero dei riferimenti espliciti a `skills/*/SKILL.md`.

## Validazione finale

Comandi eseguiti con esito positivo:

```bash
bash -n scripts/validate-factory.sh
bash -n scripts/validate-workspace.sh
bash scripts/validate-factory.sh
bash scripts/validate-workspace.sh examples/research-agent
bash scripts/validate-workspace.sh examples/web-dev-agent
bash scripts/validate-workspace.sh examples/mobile-dev-agent
bash scripts/validate-workspace.sh examples/automation-agent
git diff --check
```

## Lezioni per la fabbrica

Il workflow con subagent trova problemi che il validator strutturale non vede. I validator devono restare leggeri, ma conviene aggiungere controlli puntuali quando un falso verde e' confermato da esempi reali.
