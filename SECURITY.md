# Security policy

## Versioni supportate

La sola linea supportata è l'ultima revisione pubblicata di `main`. Snapshot storici, fork e workspace generati con revisioni precedenti non ricevono correzioni automatiche.

## Segnalare una vulnerabilità

Non pubblicare credenziali, exploit funzionanti, percorsi locali, dati di progetto o altri dettagli sensibili in una issue.

Usa il canale privato **Report a vulnerability** nella sezione Security del repository GitHub. Il canale è abilitato per il repository corrente e il collegamento diretto è disponibile nella configurazione delle issue.

Se l'interfaccia privata non è raggiungibile, usa esclusivamente il form pubblico **Canale sicurezza non disponibile** per segnalare il problema di accesso. Non inserire vulnerabilità, riproduzioni, credenziali o altri dettagli sensibili nel form: serve soltanto a ristabilire un canale privato.

Una segnalazione utile include:

- revisione o commit interessato;
- componente e comportamento osservato;
- impatto e prerequisiti;
- riproduzione minima redatta;
- mitigazione suggerita, se nota.

Non viene promesso un tempo di risposta fisso. I maintainer confermeranno il canale, valuteranno impatto e riproducibilità e pubblicheranno una correzione o una spiegazione quando la verifica è conclusa.

## Ambito di sicurezza

agent-factory non è un runtime applicativo, ma i suoi script e le istruzioni generate possono influenzare shell, filesystem, rete e tool esterni. Sono quindi in scope, tra gli altri:

- command injection o quoting non sicuro negli script;
- escape tramite path, link o symlink;
- persistenza di segreti, dati o percorsi macchina-specifici;
- prompt injection che trasformi contenuti esterni in istruzioni;
- installazioni, invii o scritture remote senza conferma;
- dipendenze persistenti non pinning o supply-chain non dichiarata;
- bypass dei validator con impatto sulle garanzie documentate.

Richieste generiche, incompatibilità dichiarate e problemi che richiedono già un'azione esplicitamente autorizzata non sono automaticamente vulnerabilità; possono comunque essere proposti come hardening tramite il normale flusso di contribuzione.
