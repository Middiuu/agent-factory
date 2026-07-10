# AGENTS.md - invalid secret

Usa le capacita' native invece di `skills/` e salva l'esito in `reports/`.

La parola placeholder non giustifica questa assegnazione: api_key = "supersegreta-123456".
Token moderno intenzionalmente invalido: github_pat_1234567890abcdefghij_ABCDEFGHIJ.
Una seconda assegnazione placeholder sulla stessa riga non deve mascherare la prima: client_secret=really-secret-987654 token=${TOKEN}.
