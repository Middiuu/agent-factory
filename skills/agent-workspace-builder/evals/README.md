# Eval della skill

`evals.json` definisce gli scenari e le aspettative stabili. `results/` conserva manifest revisionabili, ma un manifest senza output, hash e baseline raggiungibile è uno **snapshot auto-dichiarato**, non una prova riproducibile. Output temporanei e viewer locali non sono evidenza persistente.

## Procedura

1. Esegui lo stesso prompt con la skill corrente e con la baseline dichiarata nel manifest.
2. Salva gli output in directory separate.
3. Esegui il validator appartenente a ciascuna configurazione.
4. Valuta ogni aspettativa con evidenza osservabile, senza inferire risultati mancanti.
5. Registra modello, numero di run, dati non catturati e limiti.

Un singolo scenario dimostra soltanto la regressione che copre. Non autorizza affermazioni generali su provider o modelli.

Per dichiarare un risultato riproducibile, una run futura deve conservare output redatti, hash dei file, comandi, validator usato e una baseline raggiungibile nella history corrente.
