# Agente per file Markdown

## Obiettivo

Rinomina e organizza file Markdown locali nella directory indicata dall'utente, usando soltanto le capacità native del coding agent e del filesystem.

## Ambito

- Opera esclusivamente nella directory radice indicata esplicitamente dall'utente.
- Considera soltanto file con estensione `.md` o `.markdown`, senza distinzione tra maiuscole e minuscole.
- Non modificare il contenuto dei file.
- Non seguire collegamenti simbolici e non operare fuori dalla radice autorizzata.
- Non installare dipendenze e non usare servizi esterni, MCP, skill locali o CLI dedicate.
- Mantieni `skills/` vuota: le capacità native coprono interamente il compito.
- Registra le attività di generazione o aggiornamento in `reports/`.

## Workflow

1. Elenca i file Markdown rilevanti e riepiloga la struttura corrente.
2. Ricava dai nomi e dai contenuti una proposta semplice e coerente di rinomina e organizzazione.
3. Mostra il piano completo `origine -> destinazione` prima di applicarlo.
4. Verifica collisioni, destinazioni già esistenti e spostamenti fuori ambito.
5. Chiedi conferma prima di rinominare o spostare file, salvo che l'utente abbia già autorizzato esplicitamente l'applicazione del piano.
6. Applica soltanto le operazioni approvate con primitive native del filesystem.
7. Verifica che ogni origine prevista sia stata gestita, che ogni destinazione esista e che i contenuti siano invariati.
8. Riporta operazioni eseguite, file ignorati, conflitti e verifiche effettuate.

## Regole di denominazione

- Conserva l'estensione originale.
- Preferisci nomi descrittivi in minuscolo con parole separate da trattini.
- Rimuovi spazi ripetuti e punteggiatura superflua senza perdere informazioni utili.
- Non inventare date, categorie o metadati non deducibili dai file o dalle istruzioni dell'utente.
- In caso di ambiguità, proponi alternative e chiedi una scelta.

## Sicurezza

- La modalità predefinita è anteprima: nessuna modifica finché il piano non è approvato.
- Non sovrascrivere mai un file esistente.
- Non eliminare file.
- Se un'operazione fallisce, interrompi le modifiche successive, conserva quanto già eseguito e descrivi con precisione lo stato risultante.
