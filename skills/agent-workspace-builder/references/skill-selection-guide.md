# Guida: scegliere o creare skill locali

## Prima la discovery, poi la creazione

Ordine obbligatorio: (1) cerca tra le skill già installate nel coding agent; (2) cerca in marketplace/registry di skill e nei registry MCP; (3) valuta le CLI esistenti; (4) solo per ciò che resta scoperto, crea skill locali nuove. Documenta cosa hai valutato, scelto e scartato in `RESEARCH.md`.

Per i punti 2 e 3, il primo passaggio standard parte dalla root della fabbrica con una variabile esplicita:

```bash
DISCOVERY_TERM="web research"
bash scripts/discover.sh "$DISCOVERY_TERM" all
```

Lo script interroga registry di skill, registry MCP, npm, Homebrew, PyPI e PATH con timeout, e stampa i comandi esatti da registrare in `RESEARCH.md`. Il punto 1 resta manuale: lo script non può vedere le skill installate nel coding agent.

## Dove cercare (fonti concrete)

1. **Skill già installate nel coding agent.** Ogni ambiente le espone a modo suo: in Claude Code sono elencate nel contesto di sessione (skill disponibili, plugin, comandi `/`); in altri coding agent controlla la configurazione equivalente del progetto e dell'utente. Non citare a memoria: usa solo skill che risultano davvero disponibili.
2. **Registry pubblici di skill.** Il repository ufficiale Anthropic [github.com/anthropics/skills](https://github.com/anthropics/skills) raccoglie skill open source riusabili; per elencarne il contenuto senza clonare:

   ```bash
   SKILLS_API_URL="https://api.github.com/repos/anthropics/skills/contents/skills"
   curl --fail --silent --show-error --max-time 20 "$SKILLS_API_URL" | jq -r '.[].name'
   ```

   Nota: senza autenticazione l'API GitHub ha un rate limit di ~60 richieste/ora per IP; se disponibile, esporta `GITHUB_TOKEN` e aggiungi `-H "Authorization: Bearer $GITHUB_TOKEN"`. Un 403 improvviso è quasi sempre rate limit, non assenza del registry: dichiaralo come discovery incompleta, non come "0 risultati".

   I marketplace di plugin del coding agent, se presenti, sono la seconda fonte.
3. **Registry MCP e CLI** (vedi `mcp-selection-guide.md`): spesso il compito è già coperto da un MCP o da una CLI, e la skill non serve affatto.
4. **Fallback: ricerca web.** Se i registry non danno risultati, combina i termini del compito con `SKILL.md site:github.com`. Prima di adottare un risultato verifica che esista, sia mantenuto e sia ispezionabile.

L'ordine è vincolante: si passa alla fonte successiva solo se la precedente non copre il compito. Se nessuna copre, si crea la skill locale. Se una fonte non è raggiungibile, non citare a memoria: segnala in `RESEARCH.md` che la discovery è incompleta.

## Quando usare skill esistenti

Se il coding agent dell'utente ha già una skill adatta (nativa, installata o disponibile in un marketplace affidabile), usala e documentala nel README del workspace. Non duplicare in locale ciò che esiste già, a meno che serva una variante specifica del progetto.

La directory `skills/` resta parte della struttura base, ma puo' essere vuota. Un workspace senza skill locali e' corretto quando `RESEARCH.md` o il report dimostrano quale capacita' nativa verificata copre il lavoro e `AGENTS.md` contiene le sole regole specifiche del progetto.

## Quando crearne una nuova

Crea una skill locale solo dopo la discovery, quando il progetto ha una procedura ripetibile e specifica che nessuna skill esistente copre: un formato di report, una convenzione di codice, un flusso di verifica. Se la conoscenza serve una volta sola, mettila in `AGENTS.md`; se è una procedura riusabile, è una skill.

## Come scrivere SKILL.md

```md
---
name: nome-skill
description: Use this skill when... (cosa fa e quando attivarla)
---

# Titolo

## Quando usarla
## Procedura
1. ...
2. ...
## Regole
```

Frontmatter con `name` e `description`, poi istruzioni procedurali concrete: passi numerati, comandi reali, criteri di completamento. Preferire istruzioni verificabili ("lancia `npm test`, tutti verdi") a principi vaghi ("assicurati della qualità").

## Quando la skill include uno script

Una skill può contenere una cartella `scripts/` accanto a `SKILL.md`, con un piccolo script che il coding agent esegue. Usala per **trasformazioni deterministiche ricorrenti** che il modello non deve stimare "a occhio": parsing di un formato, normalizzazioni, deduplica o calcoli propri del dominio. "Markdown-first" non è "Markdown-only": il lavoro deterministico ripetuto va affidato a codice verificabile. Regola: se ogni esecuzione della skill rifà manualmente la stessa trasformazione, valuta uno script minimale, senza dipendenze pesanti, richiamato dalla `SKILL.md` con comando esatto e fixture nota.

## Come definire una descrizione utile

La `description` è ciò che fa attivare la skill: deve dire cosa fa E quando usarla, con i termini che l'utente userebbe. Buona: "Use this skill to generate a weekly Markdown report from monitoring logs in reports/". Cattiva: "Helps with reports".

Policy lingua: la `description` si scrive in inglese anche se il resto del workspace è in un'altra lingua — il matching delle skill è più affidabile in inglese. Il corpo della skill e tutti gli altri file seguono la lingua dell'utente.

## Come evitare skill troppo generiche

Una skill per capacità, non una skill "tuttofare". Se la procedura vale per qualsiasi progetto, probabilmente non serve scriverla: i coding agent la sanno già. Il valore di una skill locale sta nelle specificità del progetto: formati, convenzioni, comandi, vincoli.

## Come mantenere skill locali al workspace

Le skill vivono nella directory `skills/`, ciascuna in una sottodirectory con il proprio `SKILL.md`, e si versionano con il workspace. Non installarle globalmente: resterebbero orfane del contesto di progetto e inquinerebbero gli altri progetti. Se una skill si rivela utile ovunque, la promozione a skill globale è una scelta esplicita dell'utente, non del builder.
