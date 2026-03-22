# Brain-engine — guide pratique

> Demarrer, arreter, diagnostiquer, graduer. Les commandes du quotidien.

---

## C'est quoi brain-engine ?

Brain-engine c'est le serveur local de ton brain. Il fait 3 choses :

1. **Dashboard web** — tes docs, tes workflows, la visualisation 3D de ton corpus
2. **API locale** — les agents et scripts du brain l'utilisent pour chercher du contexte
3. **Recherche semantique** — tu poses une question, il trouve les fichiers pertinents

> Brain-engine n'est **pas obligatoire** pour utiliser le brain avec Claude Code.
> C'est un bonus. `brain boot` fonctionne sans.

---

## Commandes essentielles

Tout passe par une seule CLI : `bash scripts/brain-engine.sh`

```bash
brain-engine.sh start          # demarrer (background)
brain-engine.sh start --fg     # demarrer (foreground — Ctrl+C pour arreter)
brain-engine.sh stop           # arreter proprement
brain-engine.sh status         # PID, port, mode, uptime
brain-engine.sh embed          # lancer un embedding one-shot
brain-engine.sh logs           # tail des logs
brain-engine.sh install pm2    # installer via pm2
brain-engine.sh install systemd # installer via systemd
```

---

## Demarrer

```bash
bash scripts/brain-engine.sh start
```

```
▶ brain-engine start
   mode : dev
   port : 7700
✅ brain-engine demarre (PID 12345, port 7700)
   logs : tail -f brain-engine.log
```

Dashboard : `http://localhost:7700/ui/`

---

## Verifier que ca tourne

```bash
bash scripts/brain-engine.sh status
```

```
▶ brain-engine status
   mode : dev
   port : 7700
   pid  : 12345
   up   : 2h 15m
✅ en cours — /health OK
```

---

## Arreter

```bash
bash scripts/brain-engine.sh stop
```

En dernier recours : `pkill -f 'python3.*server.py'`

---

## Modes

Brain-engine detecte automatiquement son mode depuis `brain-compose.local.yml` ou la variable `BRAIN_MODE`.

| Mode | Usage | Write API | Secrets | Embed |
|------|-------|-----------|---------|-------|
| **dev** | Developpement local | oui | optionnels | manuel |
| **prod** | Instance personnelle en service | oui | requis | cron 6h |
| **demo** | Vitrine template | non (read-only) | non requis | desactive |

---

## Graduation — du manuel au permanent

Commence en manuel. Quand tu as confiance, monte d'un cran.

### Niveau 1 — Manuel (debut)

```bash
bash scripts/brain-engine.sh start    # quand tu en as besoin
bash scripts/brain-engine.sh stop     # quand tu as fini
```

Le serveur s'arrete si tu eteins la machine ou fermes le terminal.

### Niveau 2 — pm2 (restart on crash)

```bash
bash scripts/brain-engine.sh install pm2
```

pm2 relance automatiquement brain-engine si il crashe. Pas au reboot.

```bash
pm2 status                    # voir l'etat
pm2 logs brain-engine         # voir les logs
pm2 stop brain-engine         # arreter
```

### Niveau 3 — systemd (survit au reboot)

```bash
bash scripts/brain-engine.sh install systemd
```

brain-engine demarre au boot, survit aux reboots, logs dans journald.

```bash
sudo systemctl status brain-engine    # etat
sudo journalctl -u brain-engine -f    # logs
sudo systemctl stop brain-engine      # arreter
```

En mode prod, le script propose aussi d'activer le cron embed (toutes les 6h).

---

## Recherche semantique

La recherche necessite **Ollama** + le modele `nomic-embed-text`.

### Installer Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull nomic-embed-text
```

### Indexer le corpus

```bash
bash scripts/brain-engine.sh embed
```

> L'indexation est incrementale — seuls les fichiers modifies sont re-indexes.

### Automatiser (apres install systemd)

En mode prod, l'embedding tourne toutes les 6h via cron. Le script d'installation propose la commande.

En mode demo, l'embedding est desactive (donnees statiques).

---

## Connexion MCP (Claude Code)

Brain-engine expose un serveur MCP pour que Claude Code puisse chercher dans ton brain :

```bash
# Ajouter dans Claude Code
claude mcp add brain --transport http http://localhost:7701/mcp/
```

Puis en session Claude Code :

```
use brain_search to find context about <sujet>
```

---

## Diagnostiquer

### Le serveur ne demarre pas

```bash
# Voir les logs
bash scripts/brain-engine.sh logs

# Verifier que le port n'est pas deja utilise
lsof -i :7700
```

### "no such table: embeddings"

Normal si Ollama n'est pas installe. La recherche ne fonctionne pas mais le dashboard et l'API oui.

### Le dashboard affiche une page blanche

```bash
# Verifier que brain-ui est build
ls ~/Dev/Brain/brain-ui/dist/index.html

# Si absent, rebuild :
cd ~/Dev/Brain/brain-ui && npm run build
# Puis relancer brain-engine
bash scripts/brain-engine.sh stop && bash scripts/brain-engine.sh start
```

---

## Ports

| Service | Port | Usage |
|---------|------|-------|
| brain-engine | 7700 | API + dashboard |
| MCP server | 7701 | Connexion Claude Code |
