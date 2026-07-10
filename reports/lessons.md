# Registro lezioni della fabbrica

<!-- append-only-policy: 1 -->

Append-only. Contiene **solo conoscenza generalizzata**: tipo di agente e lezioni riusabili — mai nomi, obiettivi, dati o dettagli dei progetti generati. Il ledger opaco `lesson-events.tsv` è la fonte dei conteggi; questo file è la vista narrativa per gli umani.

Regole di scrittura:

- **Granularità: una voce per ciclo di lavoro su un progetto**, non una per singola operazione. Una generazione e i suoi aggiornamenti ravvicinati producono una voce sola: più voci in sequenza sullo stesso progetto ne ricostruiscono la storia e indeboliscono l'anonimizzazione. (Le voci precedenti a questa regola restano com'erano: il registro è append-only.)
- **Soglia di promozione**: una lezione ricorrente entra in guida/checklist solo dopo almeno tre cicli reali distinti nel ledger e approvazione esplicita; sotto soglia resta un'osservazione.
- Una lezione già applicata a guida, checklist o blueprint viene marcata con "→ Applicata a ...": è il suo stato d'archivio, non va riproposta.
- Le voci precedenti alla migrazione del 2026-07-10 sono legacy: restano per integrità storica, ma non governano più conteggi o promozioni.

---

## 2026-07-07 — generazione — tipo: research, variante directory/attività locali

- La ricerca di *attività su un territorio* è diversa dalla ricerca di *temi*: richiede tooling geografico (OSM/Overpass/Nominatim gratuiti senza chiave; Google Places a pagamento) e calcolo delle distanze. → Applicata al blueprint research.
- Quando l'output alimenta azioni reali (contatti, inviti, lead), la verifica dei contatti è una capacità a sé: skill dedicata. → Applicata al blueprint research.
- I database di contatti escono fisiologicamente a due livelli (verificato / da verificare): meglio onestà per-record che completezza finta. → Applicata al blueprint research.

## 2026-07-07 — revisione post-run — tipo: research, variante directory locale

- I calcoli deterministici (es. distanze geografiche) non si stimano col modello: vanno in uno script dentro la skill. → Applicata a `skill-selection-guide.md`.
- Le lezioni più preziose emergono dall'esecuzione, non dalla generazione: la revisione post-run è il punto di raccolta giusto. → Applicata come passo in `SKILL.md`.

## 2026-07-07 — aggiornamento — tipo: research, variante directory locale

- La procedura di aggiornamento regge su un caso reale senza improvvisazioni (discovery solo sulla parte nuova, RESEARCH in append, stato preservato).
- Nei siti delle PMI locali i certificati TLS scaduti sono ricorrenti: fallback utile = dominio del brand o pagine interne indicizzate. (2 occorrenze: sotto soglia per entrare in guida.)
- La regola "fonti discordanti → riportare entrambe con fonte" si è confermata necessaria sul campo.

## 2026-07-07 — generazione — tipo: research, variante news brief/email delivery

- Per agenti research con consegna email, separare raccolta fonti e delivery in due skill riduce il rischio di inviare sintesi non verificate.
- Quando manca un provider email scelto, uno script SMTP locale con dry-run di default e nessuna dipendenza è un buon compromesso: abilita l'invio senza vincolare il workspace a un provider specifico.
- La presenza di `mail` o `sendmail` non basta come discovery positiva per l'invio: va trattata come fallback finché il trasporto locale non è testato.

## 2026-07-07 — aggiornamento — tipo: research, variante MCP email/OAuth

- Quando un MCP ufficiale espone solo la creazione di bozze, il workspace deve chiamarla bozza e non invio: la semantica dell'azione conta quanto la configurazione.
- Per MCP remoti OAuth, `.mcp.json` puo' documentare endpoint e variabili, ma il report deve dichiarare che la verifica completa richiede autenticazione utente fuori dal workspace.
- Un'alternativa non ufficiale che promette piu' azioni non deve sostituire automaticamente un MCP ufficiale se aggiunge runtime o requisiti non presenti nell'ambiente.

## 2026-07-07 — aggiornamento — tipo: research, variante email send reale

- Se un utente chiede "email inviata" e il MCP ufficiale crea solo bozze, bisogna separare esplicitamente canale bozza e canale invio.
- Per invio reale minimale, SMTP con dry-run e log e' piu' verificabile di un MCP non ufficiale che promette invio ma aggiunge requisiti runtime.
- I report di delivery devono distinguere `dry-run`, `sent`, `failed` e `draft-created` per evitare ambiguita' operative.

## 2026-07-07 — aggiornamento — tipo: research, variante email editoriale

- Per agenti research con delivery email, HTML multipart opzionale migliora la leggibilita' senza introdurre un framework o una dipendenza provider-specific.
- Una skill email deve definire gerarchia editoriale e tono, non solo campi obbligatori: altrimenti la bozza tende a copiare il report invece di invitare alla lettura.
- Il fallback testo resta obbligatorio anche nelle email curate: rende il contenuto verificabile e compatibile con client che non rendono HTML.

## 2026-07-07 — test di compatibilità provider (Codex CLI / GPT-5) — tipo: research, variante report/fonti online

*(Workspace di collaudo, poi eliminato: non conta come generazione reale nel contatore.)*

- Separare metodo di ricerca e formato di output in due skill locali (`web-research` e `report-writer`) rende piu' verificabili fonti, citazioni e struttura del report.
- Per workspace research provider-agnostic, conviene preferire web search/fetch nativi quando disponibili e documentare una CLI verificata come fallback, senza configurare MCP se non sono essenziali.
- Timeout o discovery parziale su registry MCP non devono bloccare una generazione se il funzionamento minimo e' coperto da tool verificati e il limite e' documentato.

## 2026-07-07 — revisione del collaudo provider — lezioni per la fabbrica

- La catena AGENTS → SKILL → references → templates è eseguibile end-to-end da un coding agent non-Claude senza aiuto umano (primo collaudo: Codex CLI/GPT-5, validazione PASS).
- Le istruzioni che citano file per pattern (`<tipo>`) devono enumerare i nomi reali: un agent che deduce il nome sbaglia. → Corretta la sezione Reference della SKILL.
- Ogni regola enunciata in più file prima o poi drifta: al cambio di una policy, grep su tutti i punti che la enunciano (drift SKILL↔checklist accaduto due volte). → Checklist riallineata a "imparare senza conservare".
- In sandbox con rete off-by-default, la discovery degrada correttamente se le regole prevedono "dichiarare incompleto, mai inventare": confermato sul campo.

## 2026-07-08 — revisione critica della fabbrica — lezioni per la fabbrica

- Gli esempi driftano rispetto ai blueprint se nessun check meccanico li lega: le regole anti prompt-injection richieste dai blueprint mancavano in tutti gli esempi, e la CI passava. → Aggiunto check web-safety euristico a `validate-workspace.sh`.
- Un'automazione (Livello A) che per completarsi deve toccare un file protetto (Livello C) è un deadlock di design: la lista dei blueprint è uscita da `SKILL.md` verso `references/blueprint-index.md`, che il Livello A può aggiornare.
- Le soglie contano solo se l'unità di conteggio è definita: "stesso tipo" era ambiguo (tipo vs variante); ora conta la variante, cioè la riga del contatore.
- Ogni lista duplicata tra script e documenti drifta: i validatori ora derivano placeholder e blueprint da template e filesystem invece di enumerarli. → Riscritti `validate-factory.sh` e check documentali.
- Un validator senza test negativi è un quality gate di carta (bug reale già accaduto): fixture rotta + `test-validators.sh` in CI.
- Più voci di registro in sequenza sullo stesso progetto ricostruiscono la sua storia: l'anonimizzazione richiede granularità per ciclo, non per operazione. → Regola aggiunta in testa al registro.

## 2026-07-08 — generazione — tipo: web dev, variante sito statico vetrina deployabile

- Per un agente web dev orientato a un sito vetrina semplice, l'output statico senza dipendenze puo' essere piu' deployabile di un framework predefinito.
- La deploy-readiness va resa verificabile: cartella di pubblicazione, istruzioni di deploy, assenza di placeholder e dati reali non inventati.
- Skill di design e browser testing possono restare opzionali quando l'obiettivo minimo e' coperto da file statici e controlli manuali.

---

## Contatore legacy — archiviato il 2026-07-10

Questa tabella è uno snapshot storico e non va aggiornata. Usa `bash scripts/lessons-ledger.sh summary` e `eligible` per conteggi derivati e candidabilità.

| Tipo | Generazioni reali | Note |
|------|-------------------|------|
| research — directory/attività locali | 1 | +1 caso sintetico nei test pre-produzione |
| research — news brief/email delivery | 1 | primo caso reale |
| web dev — sito statico vetrina deployabile | 1 | primo caso reale |

## 2026-07-10 — revisione della governance e dei gate

- Un contatore modificato a mano non è una prova: gli eventi eleggibili ora vivono in un ledger TSV append-only con ID e varianti canonici.
- Il rilevamento automatico di una soglia non autorizza una modifica: proposta, approvazione e applicazione sono stati separati.
- I validator devono certificare anche il contratto semantico minimo; fixture verdi puramente strutturali non bastano.
- Gli esempi devono essere workspace sintetici completi e riproducibili, non documenti che affermano soltanto di passare il validator.
- La compatibilità si dichiara per capacità e client collaudati, mai come garanzia universale.
