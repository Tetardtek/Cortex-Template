# Brain-engine — guide pratique

> Demarrer, arreter, diagnostiquer. Les commandes du quotidien.

---

## C'est quoi brain-engine ?

Brain-engine c'est le serveur local de ton brain. Il fait 3 choses :

1. **Dashboard web** — tes docs, tes workflows, la visualisation 3D de ton corpus
2. **API locale** — les agents et scripts du brain l'utilisent pour chercher du contexte
3. **Recherche semantique** — tu poses une question, il trouve les fichiers pertinents

> Brain-engine n'est **pas obligatoire** pour utiliser le brain avec Claude Code.
> C'est un bonus. `brain boot` fonctionne sans.

---

## Demarrer

```bash
cd ~/Dev/Brain
bash brain-engine/start.sh
```

Le script :
1. Cree l'environnement Python (une seule fois)
2. Installe les dependances (une seule fois)
3. Init brain.db si absent
4. Indexe le corpus si Ollama est disponible
5. Lance le serveur sur le port 7700

**Le terminal reste occupe.** Ouvre un autre terminal pour Claude Code.

---

## Verifier que ca tourne

```bash
# Health check
curl http://localhost:7700/health

# Dashboard
# Ouvre dans ton navigateur :
http://localhost:7700/ui/
```

---

## Arreter

### Premier plan (cas normal)

Tu as lance `bash brain-engine/start.sh` dans un terminal → **Ctrl+C** dans ce terminal.

### Arriere-plan

Si tu l'as lance avec `nohup` :

```bash
kill $(cat /tmp/brain-engine.pid)
```

### Dernier recours

```bash
pkill -f 'python3.*server.py'
```

---

## Lancer en arriere-plan

Si tu ne veux pas bloquer un terminal :

```bash
cd ~/Dev/Brain
nohup bash brain-engine/start.sh > /tmp/brain-engine.log 2>&1 &
echo $! > /tmp/brain-engine.pid
```

Verifier les logs :

```bash
tail -f /tmp/brain-engine.log
```

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
cd ~/Dev/Brain
brain-engine/.venv/bin/python3 brain-engine/embed.py
```

Apres l'indexation, la recherche fonctionne :

```bash
curl "http://localhost:7700/search?q=comment+fonctionnent+les+sessions"
```

### Re-indexer apres des modifications

```bash
brain-engine/.venv/bin/python3 brain-engine/embed.py
```

> L'indexation est incrementale — seuls les fichiers modifies sont re-indexes.

---

## Connexion MCP (Claude Code)

Brain-engine expose un serveur MCP pour que Claude Code puisse chercher dans ton brain :

```bash
# Lancer le MCP server (port 7701)
brain-engine/.venv/bin/python3 brain-engine/mcp_server.py

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
# Verifier que le port n'est pas deja utilise
lsof -i :7700

# Verifier les logs
cat /tmp/brain-engine.log
```

### "no such table: embeddings"

Normal si Ollama n'est pas installe. La recherche ne fonctionne pas mais le dashboard et l'API oui.

### Le dashboard affiche une page blanche

```bash
# Verifier que brain-ui est build
ls ~/Dev/Brain/brain-ui/dist/index.html

# Si absent, rebuild :
bash brain-ui/build.sh
# Puis relancer brain-engine
```

---

## Ports

| Service | Port | Usage |
|---------|------|-------|
| brain-engine | 7700 | API + dashboard |
| MCP server | 7701 | Connexion Claude Code |
