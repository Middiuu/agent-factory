# Provider test — Codex

## Ambiente

- Codex desktop con CLI rilevata: `codex-cli 0.142.5`.
- Modello: GPT-5, come dichiarato dalle istruzioni di sistema/developer della sessione; non ho trovato un comando locale che esponga il model id runtime.
- `codex --version` ha emesso anche un warning: impossibile creare PATH aliases per permessi insufficienti.
- Sandbox: `workspace-write`; scrittura consentita nella root del repository e in temp, non nella cartella sorella ideale.
- Approvazioni: `auto_review`; escalation richieste e approvate per `git pull`, query `curl` esterne e `npm view`.
- Accesso rete: no nel sandbox normale per DNS esterno; si' con escalation, ma alcune query al registry MCP sono comunque andate in timeout.

## File letti

In ordine di lettura esplicita:

- `skills/agent-workspace-builder/SKILL.md`
- `skills/agent-workspace-builder/references/skill-selection-guide.md`
- `skills/agent-workspace-builder/references/mcp-selection-guide.md`
- `skills/agent-workspace-builder/references/local-installation-policy.md`
- `skills/agent-workspace-builder/references/post-generation-checklist.md`
- `skills/agent-workspace-builder/references/workspace-blueprint-research-agent.md`
- `templates/workspace-README.md`
- `templates/workspace-AGENTS.md`
- `templates/SKILL.md`
- `templates/RESEARCH.md`
- `templates/report-generation.md`
- `AGENTS.md`
- `skills/agent-workspace-builder/SKILL.md` riletto dopo `git pull`
- `skills/agent-workspace-builder/references/workspace-blueprint-research-agent.md` riletto dopo `git pull`
- `skills/agent-workspace-builder/references/skill-selection-guide.md` riletto dopo `git pull`
- `skills/agent-workspace-builder/references/mcp-selection-guide.md` riletto dopo `git pull`
- `reports/lessons.md`
- `skills/agent-workspace-builder/references/local-installation-policy.md` riletto dopo `git pull`
- `skills/agent-workspace-builder/references/post-generation-checklist.md` riletto dopo `git pull`
- `templates/workspace-README.md` riletto dopo `git pull`
- `templates/workspace-AGENTS.md` riletto dopo `git pull`
- `templates/SKILL.md` riletto dopo `git pull`
- `templates/RESEARCH.md` riletto dopo `git pull`
- `templates/report-generation.md` riletto dopo `git pull`
- `scripts/validate-workspace.sh`
- `reports/lessons.md` riletto dopo modifica

Letti indirettamente dagli script di validazione: `online-research-reporter-agent/README.md`, `online-research-reporter-agent/AGENTS.md`, `online-research-reporter-agent/RESEARCH.md`, `online-research-reporter-agent/skills/web-research/SKILL.md`, `online-research-reporter-agent/skills/report-writer/SKILL.md`, `online-research-reporter-agent/reports/2026-07-07-generation.md` e i file/template controllati da `scripts/validate-factory.sh`.

## Domande e assunzioni

- Domande di chiarimento all'utente: nessuna, perche' scopo, output e tipo di agente erano sufficienti e le istruzioni del repository consentono assunzioni minime in modalita' non interattiva.
- Richieste di approvazione: accesso rete per `git pull`, query registry via `curl` e verifica `npm view`.
- Assunzioni prese: nuovo workspace, non aggiornamento; tipo agente `research`; lingua predefinita italiano; nessun provider obbligatorio; report Markdown in `reports/`; nessun MCP locale senza discovery completa; workspace creato dentro il repository per limite sandbox.

## Comandi eseguiti

- `sed -n '1,240p' skills/agent-workspace-builder/SKILL.md` -> riuscito.
- `sed -n '241,520p' skills/agent-workspace-builder/SKILL.md` -> riuscito, nessun output.
- `sed -n '1,240p' skills/agent-workspace-builder/references/workspace-blueprint-research.md` -> fallito, file non presente.
- `sed -n '1,260p' skills/agent-workspace-builder/references/skill-selection-guide.md` -> riuscito.
- `sed -n '1,260p' skills/agent-workspace-builder/references/mcp-selection-guide.md` -> riuscito.
- `rg --files skills/agent-workspace-builder/references` -> riuscito, ha mostrato che il blueprint corretto e' `workspace-blueprint-research-agent.md`.
- `sed -n '1,260p' skills/agent-workspace-builder/references/local-installation-policy.md` -> riuscito.
- `sed -n '1,260p' skills/agent-workspace-builder/references/post-generation-checklist.md` -> riuscito.
- `sed -n '1,260p' skills/agent-workspace-builder/references/workspace-blueprint-research-agent.md` -> riuscito.
- `sed -n '1,260p' templates/workspace-README.md` -> riuscito.
- `sed -n '1,260p' templates/workspace-AGENTS.md` -> riuscito.
- `sed -n '1,260p' templates/SKILL.md` -> riuscito.
- `sed -n '1,260p' templates/RESEARCH.md` -> riuscito.
- `sed -n '1,260p' templates/report-generation.md` -> riuscito.
- `git pull` -> riuscito con rete approvata: repository gia' aggiornato.
- `sed -n '1,260p' AGENTS.md` -> riuscito.
- `sed -n '1,260p' skills/agent-workspace-builder/SKILL.md` -> riuscito.
- `git status --short` -> riuscito, nessun output in quel momento.
- `sed -n '1,260p' skills/agent-workspace-builder/references/workspace-blueprint-research-agent.md` -> riuscito.
- `sed -n '1,260p' skills/agent-workspace-builder/references/skill-selection-guide.md` -> riuscito.
- `sed -n '1,260p' skills/agent-workspace-builder/references/mcp-selection-guide.md` -> riuscito.
- `sed -n '1,220p' reports/lessons.md` -> riuscito.
- `sed -n '1,260p' skills/agent-workspace-builder/references/local-installation-policy.md` -> riuscito.
- `sed -n '1,260p' skills/agent-workspace-builder/references/post-generation-checklist.md` -> riuscito.
- `sed -n '1,220p' templates/workspace-README.md` -> riuscito.
- `sed -n '1,220p' templates/workspace-AGENTS.md` -> riuscito.
- `sed -n '1,220p' templates/SKILL.md` -> riuscito.
- `sed -n '1,220p' templates/RESEARCH.md` -> riuscito.
- `sed -n '1,220p' templates/report-generation.md` -> riuscito.
- `which curl` -> riuscito; path macchina redatto prima della nuova history.
- `which jq` -> riuscito; path macchina redatto prima della nuova history.
- `which tvly` -> riuscito.
- `curl --max-time 20 https://api.github.com/repos/anthropics/skills/contents/skills` -> fallito nel sandbox per DNS.
- `curl --max-time 20 https://registry.modelcontextprotocol.io/v0.1/servers?search=search&limit=10` -> fallito per URL non quotato in zsh.
- `curl --max-time 20 https://registry.modelcontextprotocol.io/v0.1/servers?search=fetch&limit=10` -> fallito per URL non quotato in zsh.
- `tvly --version` -> riuscito: `tavily-cli 0.1.4`.
- `which npm` -> riuscito.
- `curl --max-time 20 https://api.github.com/repos/anthropics/skills/contents/skills` con rete approvata -> riuscito.
- `curl --max-time 20 'https://registry.modelcontextprotocol.io/v0.1/servers?search=search&limit=10'` con rete approvata -> timeout dopo 20 secondi.
- `curl --max-time 20 'https://registry.modelcontextprotocol.io/v0.1/servers?search=fetch&limit=10'` con rete approvata -> riuscito.
- `npm view @modelcontextprotocol/server-filesystem version` con rete approvata -> riuscito: `2026.7.4`.
- `curl --max-time 20 'https://registry.modelcontextprotocol.io/v0.1/servers?search=tavily&limit=10'` con rete approvata -> timeout dopo 20 secondi.
- `tvly search --help` -> riuscito.
- `which python3` -> riuscito; path macchina redatto prima della nuova history.
- `date +%F` -> riuscito: `2026-07-07`.
- `tvly extract --help` -> riuscito.
- `test -e online-research-reporter-agent` -> exit 1, il workspace non esisteva ancora.
- `mkdir -p online-research-reporter-agent/skills/web-research online-research-reporter-agent/skills/report-writer online-research-reporter-agent/reports` -> riuscito.
- `sed -n '1,260p' scripts/validate-workspace.sh` -> riuscito.
- `sed -n '261,520p' scripts/validate-workspace.sh` -> riuscito.
- `bash scripts/validate-workspace.sh online-research-reporter-agent` -> riuscito, validazione superata.
- `sed -n '1,260p' reports/lessons.md` -> riuscito; ho visto una duplicazione della tabella contatori introdotta dal mio patch.
- `bash scripts/validate-workspace.sh online-research-reporter-agent` -> riuscito, validazione superata dopo il report di generazione.
- `find online-research-reporter-agent -maxdepth 4 -type f -print` -> riuscito, ha elencato 6 file.
- `git status --short` -> riuscito, mostrava `M reports/lessons.md` e `?? online-research-reporter-agent/`.
- `which codex` -> riuscito.
- `codex --version` -> riuscito con warning, versione `codex-cli 0.142.5`.
- `bash scripts/validate-factory.sh` -> riuscito, validazione superata.
- `apply_patch` -> usato per creare i file del workspace, creare il report di generazione, aggiornare `reports/lessons.md`, correggere la duplicazione del contatore e creare questo report.

## Risultato

Workspace creato in:

`online-research-reporter-agent/` (il percorso assoluto legacy è stato rimosso nella migrazione privacy del 2026-07-10)

Albero dei file generati:

```text
online-research-reporter-agent/
|-- README.md
|-- RESEARCH.md
|-- AGENTS.md
|-- skills/
|   |-- report-writer/
|   |   `-- SKILL.md
|   `-- web-research/
|       `-- SKILL.md
`-- reports/
    `-- 2026-07-07-generation.md
```

Dentro questo repository ho scritto o modificato:

- creato `online-research-reporter-agent/README.md`;
- creato `online-research-reporter-agent/AGENTS.md`;
- creato `online-research-reporter-agent/RESEARCH.md`;
- creato `online-research-reporter-agent/skills/web-research/SKILL.md`;
- creato `online-research-reporter-agent/skills/report-writer/SKILL.md`;
- creato `online-research-reporter-agent/reports/2026-07-07-generation.md`;
- modificato `reports/lessons.md` con lezioni generalizzate e contatore aggiornato;
- creato `reports/2026-07-07-provider-test-codex.md`.

## Attriti

- Il primo turno e' stato interrotto dall'utente prima di qualsiasi scrittura; erano stati letti file e lanciati alcuni comandi di ispezione.
- La procedura citava il pattern `workspace-blueprint-<tipo>.md`; cercando `workspace-blueprint-research.md` ho avuto errore per file mancante. Il file reale e' `workspace-blueprint-research-agent.md`, individuato con `rg --files`.
- Lo script/checklist parla di "report finale scritto in reports/ di agent-factory", mentre la skill principale richiede il report finale dentro il workspace generato e solo le lezioni generalizzate in `reports/lessons.md`. Ho seguito la skill principale e AGENTS.md.
- Il sandbox non consentiva scrittura in una cartella sorella; ho creato il workspace dentro agent-factory, segnalando la deviazione.
- La rete era bloccata nel sandbox normale: la query GitHub e' fallita per DNS finche' non ho usato escalation.
- Due query MCP sono fallite inizialmente per URL non quotato in zsh; le ho ripetute con quoting corretto.
- Le query MCP `search` e `tavily` sono andate in timeout anche con rete approvata; ho evitato di configurare MCP non verificati.
- Il primo patch a `reports/lessons.md` ha duplicato la tabella contatori; l'ho corretto dopo ispezione.
- `codex --version` ha funzionato ma ha mostrato un warning sui PATH aliases, probabilmente legato ai permessi del sandbox/app.

## Autovalutazione

Esito di:

```bash
bash scripts/validate-workspace.sh online-research-reporter-agent
```

Risultato: superato. Lo script ha confermato file base, riferimenti a `skills/` e `reports/`, frontmatter skill, assenza di placeholder template, assenza di percorsi assoluti locali nel workspace e assenza di pattern semplici di segreti.

Punti checklist non pienamente soddisfatti o soddisfatti con deviazione:

- Il workspace non e' fuori da agent-factory: deviazione dovuta ai limiti di scrittura del sandbox.
- Discovery MCP incompleta per le query `search` e `tavily`: entrambe in timeout; nessun MCP selezionato.
- Il punto della checklist sul report in `reports/` di agent-factory e' ambiguo rispetto alla skill principale; ho scritto il report di generazione nel workspace e questo report di collaudo in `reports/` come richiesto dall'utente.

Ho eseguito anche:

```bash
bash scripts/validate-factory.sh
```

Risultato: superato.
