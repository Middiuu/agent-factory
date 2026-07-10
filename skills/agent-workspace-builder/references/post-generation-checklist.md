# Checklist: validazione post-generazione

Eseguila dopo ogni generazione (o aggiornamento) di un workspace, prima di finalizzare e consegnare il report corrente. Ogni punto va verificato davvero — aprendo i file, lanciando i comandi — non spuntato di fiducia.

In caso di aggiornamento di un agente esistente, i punti su posizione del workspace e comandi di setup si verificano solo se toccati dal cambiamento: sono fatti pre-esistenti, non scelte dell'aggiornamento.

## Struttura

- [ ] Il workspace è in una cartella dedicata fuori da agent-factory (idealmente sorella); se l'ambiente non lo permetteva, la posizione alternativa è stata segnalata all'utente.
- [ ] La base esiste: `README.md`, `AGENTS.md`, `skills/`, `reports/`.
- [ ] `skills/` puo' essere vuota solo se discovery e report motivano la copertura tramite capacita' native verificate; ogni skill locale presente deve coprire una procedura specifica non duplicata.
- [ ] Ogni file oltre la base ha uno scopo operativo che la base non copre, ed è motivabile nel report (es. `RESEARCH.md` per discovery non banale, `ROADMAP.md` per progetti lunghi, `.mcp.json` per MCP configurati, `.gitignore`/`.gitkeep` se versionato). Nessun file creato per completezza o abitudine.

## Contenuti

- [ ] `README.md` spiega a un umano: cos'è l'agente, setup obbligatorio vs opzionale, come usarlo, cosa produce.
- [ ] `AGENTS.md` dà istruzioni operative al coding agent ed è coerente col README su ogni requisito e fallback: ciò che il README promette all'utente, AGENTS.md deve dire all'agente come usarlo.
- [ ] Ogni `SKILL.md` ha frontmatter `name` + `description`, con `name` uguale al nome della directory; i passi sono verificabili (output osservabile, soglia concreta o comando eseguibile), non principi vaghi.
- [ ] `RESEARCH.md` (se presente) ha sezioni esplicite per cercato / trovato / scelto / scartato / comandi eseguiti, con esiti, motivazioni e limiti; i comandi sono sufficienti a ripetere la verifica.
- [ ] I riferimenti incrociati interni si risolvono: ogni file, skill o cartella citata nei documenti esiste davvero nel workspace.
- [ ] I blocchi di codice nei documenti sono validi: il JSON passa `jq -e`, i comandi shell sono completi e copia-incollabili, URL/file/directory sono passati tramite variabili dichiarate invece di pseudo-placeholder.
- [ ] Le date nei documenti sono coerenti con la data di generazione o dell'ultimo aggiornamento.
- [ ] Nessun percorso assoluto di progetto, dati, home, mount o directory temporanea è trafilato nei file del workspace. Sono ammessi solo device/eseguibili di sistema intrinsecamente portabili e necessari, per esempio `/dev/null` o `/usr/bin/env`.
- [ ] Il report corrente ha nome univoco `YYYY-MM-DD-HHMMSS-generation.md` o `YYYY-MM-DD-HHMMSS-update.md` (con `-2`, `-3`, ... prima del tipo in caso di collisione), timestamp UTC realmente valido e coerente nel contenuto, copertura delle capacità, commit breve e stato clean/dirty della fabbrica; la validazione riporta comando esatto, `PASS`/`FAIL` ed exit code reali.

## Tool

- [ ] Ogni skill, MCP e CLI citata esiste: le verifiche della discovery sono riproducibili dai comandi registrati in `RESEARCH.md`, e almeno una per categoria (una CLI, un pacchetto, una query al registry) è stata ri-eseguita ora, in fase di validazione. Nessuna citazione a memoria.
- [ ] MCP configurati localmente (`.mcp.json` di progetto); nessuna installazione globale non dichiarata come requisito.
- [ ] Nessun segreto in nessun file del workspace (cerca con grep pattern come `api[_-]?key|secret|token|password|sk-|AKIA|ghp_`); le variabili d'ambiente richieste sono documentate nel README.

## Copertura dell'obiettivo

- [ ] Per ogni capacità richiesta dall'utente esiste una skill, un tool o un'istruzione in `AGENTS.md` che la copre.
- [ ] I comandi di setup del README funzionano, oppure sono dichiarati esplicitamente come requisiti a carico dell'utente.
- [ ] Per workspace di sviluppo separati dal codice applicativo, `APP_ROOT` e il root del workspace agentico sono espliciti, verificati e usati nei comandi.
- [ ] Per automazioni con confronto, ogni run salva valori canonici e hash, cita la baseline e applica criteri dichiarati per distinguere cambiamenti significativi da variazioni tecniche.
- [ ] Se qualcosa manca o resta ambiguo, è segnalato all'utente, non taciuto.

## Chiusura

- [ ] Report finale scritto in `reports/` **del workspace generato** con nome univoco, provenienza completa della fabbrica e sezione "Lezioni per la fabbrica"; i report storici non sono stati riscritti per conformarli allo schema corrente.
- [ ] Lezioni generalizzate appese al registro `reports/lessons.md` della fabbrica: tipo e lezioni riusabili — mai nomi, obiettivi o dettagli del progetto.
