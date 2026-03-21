# Demarrer avec le brain — le vrai tuto

> Du fork au premier `brain boot`. 10 minutes (prerequis deja installes).
> Envie de comprendre le projet avant de fork ? → [story.tetardtek.com](https://story.tetardtek.com)

---

## Etape 1 — Forker et cloner

**Sur Gitea / GitHub :** clique "Fork" sur le repo brain-template.

**Sur ta machine :**

```bash
git clone <URL_DE_TON_FORK> ~/Dev/Brain
cd ~/Dev/Brain
```

> Exemple : `git clone https://git.example.com/mon-user/brain-template.git ~/Dev/Brain`

---

## Etape 2 — Installer les prerequis

Le brain a besoin de :

- **Python 3.10+** — pour brain-engine (API, search, embeddings)
- **Node.js 18+ et npm** — pour brain-ui (dashboard web)
- **Claude Code** — pour les sessions

```bash
# Ubuntu / Pop!_OS / Debian
sudo apt install -y python3 python3-pip python3-venv nodejs npm

# Claude Code
npm install -g @anthropic-ai/claude-code
```

**Recommande (recherche semantique + RAG) :**

```bash
# Ollama — active brain_search et le RAG au boot
# Sans Ollama le brain fonctionne mais la recherche semantique est desactivee
curl -fsSL https://ollama.com/install.sh | sh
ollama pull nomic-embed-text
```

---

## Etape 3 — Lancer le setup

```bash
cd ~/Dev/Brain
bash setup.sh
```

Le script fait tout automatiquement :

1. **Cree `brain-compose.local.yml`** — ta config machine (chemins auto-detectes)
2. **Clone les satellites git** — profil/, todo/, progression/, toolkit/, reviews/ (depuis ton fork GitHub)
3. **Cree les dossiers internes** — claims/, handoffs/, workspace/
4. **Copie `profil/collaboration.md`** — regles de travail
5. **Build le dashboard** — `brain-ui/` (npm install + vite build)
6. **Init brain-engine** — cree l'environnement Python + brain.db

Tu n'as rien a repondre — tout est automatique.

A la fin tu vois :

```
===========================================
  ✅ Brain installe !
===========================================
```

---

## Etape 4 — Configurer Claude Code

Claude Code a besoin de savoir ou est ton brain :

```bash
cp profil/CLAUDE.md.example ~/.claude/CLAUDE.md
```

**Edite `~/.claude/CLAUDE.md`** — remplace les 2 placeholders :

```
brain_root: /home/<ton-user>/Dev/Brain
brain_name: prod
```

> C'est le seul fichier a editer a la main. Tout le reste est automatique.

---

## Etape 5 — Lancer brain-engine

Brain-engine c'est le serveur local qui fait tourner l'API, le dashboard, et la recherche semantique.

### Demarrer

```bash
cd ~/Dev/Brain
bash brain-engine/start.sh
```

Tu vois :

```
=== Lancement brain-engine sur port 7700 ===
  Health : http://localhost:7700/health
  Dashboard : http://localhost:7700/ui/
```

> **Le terminal reste occupe** — brain-engine tourne au premier plan. Ouvre un autre terminal pour la suite.

### Verifier

Ouvre ton navigateur : `http://localhost:7700/ui/`
Tu vois le dashboard avec l'onglet Docs — c'est cette documentation.

### Arreter

Reviens dans le terminal ou brain-engine tourne et fais `Ctrl+C`. C'est tout.

> Brain-engine n'est pas obligatoire pour utiliser le brain avec Claude Code.
> C'est un bonus (dashboard, search, API). Tu peux faire `brain boot` sans.

### Lancer en arriere-plan (optionnel)

Si tu ne veux pas bloquer un terminal :

```bash
cd ~/Dev/Brain
nohup bash brain-engine/start.sh > /tmp/brain-engine.log 2>&1 &
echo $! > /tmp/brain-engine.pid
```

Pour l'arreter :

```bash
kill $(cat /tmp/brain-engine.pid)
```

---

## Etape 6 — Premier brain boot

Ouvre un **nouveau terminal** (brain-engine tourne dans l'autre) :

```bash
claude
```

Claude Code s'ouvre. Tape :

```
brain boot
```

> Tu n'as pas besoin d'etre dans le dossier brain. `brain boot` fonctionne depuis n'importe quel repertoire — les chemins dans `~/.claude/CLAUDE.md` sont absolus.

### Ce que tu dois voir

```
Bonjour. Voici l'etat du systeme — <date>.
Instance : prod@<ta-machine>  [free]  kernel v0.9.0
Mode actif : prod

Projets actifs
  Aucun focus defini — fresh fork.

Prochain todo prioritaire
  (aucun todo enregistre)

Quelle session aujourd'hui ?
```

**C'est normal que ce soit vide** — c'est un brain neuf. Il n'a pas encore de projets, de todos, ni de focus.

### Ce que tu peux repondre

- `brain boot mode work/<ton-projet>` — si tu veux coder sur un projet
- `brain boot mode brainstorm/<sujet>` — si tu veux explorer une idee
- `brain boot mode brain` — si tu veux travailler sur le brain lui-meme
- Ou simplement decrire ce que tu veux faire — le brain detecte le type de session

---

## Etape 7 — Fermer une session

Quand tu as fini, tape :

```
on wrappe
```

Le brain ferme proprement : metriques capturees, todos mis a jour, claim BSI ferme.

> Ne ferme pas Claude Code avec Ctrl+C avant que le wrap soit termine.

---

## Resume — les 4 commandes

```bash
# 1. Setup (une seule fois)
bash setup.sh

# 2. Config Claude Code (une seule fois)
cp profil/CLAUDE.md.example ~/.claude/CLAUDE.md
# Editer brain_root et brain_name

# 3. Lancer le dashboard (optionnel, a chaque session)
bash brain-engine/start.sh

# 4. Lancer Claude Code (a chaque session, depuis n'importe ou)
claude
# Puis : brain boot
```

---

## FAQ

### Brain-engine tourne encore en fond, comment l'arreter ?

Si tu l'as lance au premier plan : `Ctrl+C` dans son terminal.
Si tu l'as lance en arriere-plan : `kill $(cat /tmp/brain-engine.pid)`
En dernier recours : `pkill -f 'python3.*server.py'`

### Je vois "MYSECRETS absent" — c'est grave ?

Non. MYSECRETS c'est pour les projets qui ont des secrets (tokens API, mots de passe). Si tu n'en as pas besoin, ignore le message. Le brain fonctionne sans.

### Je vois des fichiers "non trackes" au boot — c'est normal ?

Oui. `focus.md`, `workspace/`, `claims/` sont crees localement par setup.sh. Les satellites (`profil/`, `todo/`, `toolkit/`, etc.) sont des repos git autonomes gitignores dans le kernel — c'est intentionnel. Ne les ajoute pas au kernel avec `git add`.

### Plusieurs forks du brain sur la meme machine ?

Un seul `~/.claude/CLAUDE.md` par machine. Si tu as plusieurs brains, utilise `brain-compose.local.yml` section `instances` pour les declarer. `brain_root` dans CLAUDE.md pointe vers le brain actif.

### Comment mettre a jour le kernel depuis l'upstream ?

```bash
git remote add upstream <URL_DU_TEMPLATE_ORIGINAL>
git fetch upstream
git merge upstream/main
```

### J'utilise Gitea self-hosted et git clone echoue ?

Gitea en Docker ecoute souvent sur un port SSH non standard (2222 au lieu de 22). Ajoute dans `~/.ssh/config` :

```
Host git.example.com
    HostName git.example.com
    Port 2222
    User git
    IdentityFile ~/.ssh/id_ed25519
```

Puis ajoute la host key : `ssh-keyscan -p 2222 git.example.com >> ~/.ssh/known_hosts`

### Ou est la documentation complete ?

- Dashboard : `http://localhost:7700/ui/` → onglet Docs
- Ou directement dans `docs/` du repo
