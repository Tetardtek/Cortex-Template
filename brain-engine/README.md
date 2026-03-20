---
name: brain-engine
type: reference
context_tier: cold
---

# brain-engine — Moteur local

> Le cerveau du brain. Recherche semantique, API locale, embeddings, BSI.

---

## Demarrage rapide

```bash
bash brain-engine/start.sh
```

Ca fait tout : installe les deps Python, cree brain.db, indexe le corpus si Ollama est present, et lance le serveur sur le port 7700.

---

## Prerequis

- **Python 3.10+** — `sudo apt install python3 python3-pip python3-venv`
- **Ollama** (optionnel mais recommande) — `curl -fsSL https://ollama.com/install.sh | sh`
  - Modele embedding : `ollama pull nomic-embed-text`
  - Sans Ollama : le serveur tourne mais la recherche semantique n'est pas disponible

---

## Architecture

```
brain-engine/
  start.sh          <- script de demarrage standalone
  server.py         <- API HTTP (FastAPI, port 7700)
  mcp_server.py     <- MCP server (FastMCP, port 7701)
  embed.py          <- pipeline embeddings (Ollama + nomic-embed-text)
  search.py         <- recherche cosine similarity + filtre scope
  rag.py            <- couche RAG (boot queries + ad-hoc)
  schema.sql        <- tables SQLite (claims, signals, embeddings, sessions)
  migrate.py        <- migration brain.db
  distill.py        <- distillation session memory (featured+)
  requirements.txt  <- dependances Python
```

---

## Endpoints principaux

- `GET /health` — statut du serveur
- `GET /search?q=` — recherche semantique dans le brain
- `GET /agents` — liste des agents disponibles
- `GET /boot` — contexte initial pour une session
- `GET /workflows` — claims BSI ouverts
- `GET /tier` — tier actif

---

## Mode standalone

Sans token configure, le serveur donne acces total en localhost. C'est le mode par defaut quand tu forkes le brain.

Sans cle API (`brain_api_key: null`), le tier est `free` — toutes les fonctionnalites fondamentales sont disponibles.

---

## Connexion Claude Code (MCP)

```bash
# Lancer le MCP server
python3 brain-engine/mcp_server.py

# Ajouter dans Claude Code
claude mcp add brain --transport http http://localhost:7701/mcp/
```
