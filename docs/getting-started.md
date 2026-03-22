# Demarrer avec le brain — le vrai tuto

> Du fork au premier `brain boot`. 10 minutes.
> Envie de comprendre le projet avant de fork ? → [story.tetardtek.com](https://story.tetardtek.com)

---

## Etape 1 — Forker et cloner

**Sur Gitea / GitHub :** clique "Fork" sur le repo brain-template.

**Sur ta machine :**

```bash
git clone <URL_DE_TON_FORK> ~/Dev/Brain
cd ~/Dev/Brain
```

> Exemple : `git clone https://github.com/mon-user/Cortex-Template.git ~/Dev/Brain`

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

**Optionnel mais recommande :**

```bash
# Ollama — active la recherche semantique dans le brain
curl -fsSL https://ollama.com/install.sh | sh
ollama pull nomic-embed-text
```

---

## Etape 3 — Lancer le setup

```bash
cd ~/Dev/Brain
bash scripts/brain-setup.sh mon-brain ~/Dev/Brain
```

Le script detecte automatiquement ta source git (GitHub ou Gitea) et :

1. **Clone les satellites** — profil/, toolkit/, todo/, progression/, reviews/
2. **Configure `~/.claude/CLAUDE.md`** — chemins auto-remplaces
3. **Cree `brain-compose.local.yml`** — config machine
4. **Installe brain-ui** — npm install + .env.local
5. **Installe brain-engine** — dependances Python

A la fin tu vois :

```
╔══════════════════════════════════════════════╗
║              Setup termine                   ║
╚══════════════════════════════════════════════╝
```

---

## Etape 4 — Lancer brain-engine

Brain-engine c'est le serveur local qui fait tourner l'API, le dashboard, et la recherche semantique.

```bash
bash scripts/brain-engine.sh start
```

Tu vois :

```
▶ brain-engine start
   mode : dev
   port : 7700
✅ brain-engine demarre (PID 12345, port 7700)
   logs : tail -f brain-engine.log
```

### Verifier

```bash
bash scripts/brain-engine.sh status
```

Ouvre ton navigateur : `http://localhost:7700/ui/`

### Arreter

```bash
bash scripts/brain-engine.sh stop
```

> Brain-engine n'est pas obligatoire pour utiliser le brain avec Claude Code.
> C'est un bonus (dashboard, search, API). Tu peux faire `brain boot` sans.

### Graduation — quand tu es pret

```bash
# Niveau 2 — restart on crash (pas au reboot)
bash scripts/brain-engine.sh install pm2

# Niveau 3 — survit au reboot, logs journald
bash scripts/brain-engine.sh install systemd
```

---

## Etape 5 — Premier brain boot

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
Instance : mon-brain@<ta-machine>  [free]  kernel v0.8.0
Mode actif : prod

Projets actifs
  Aucun focus defini — fresh fork.

Prochain todo prioritaire
  (aucun todo enregistre)

Quelle session aujourd'hui ?
```

**C'est normal que ce soit vide** — c'est un brain neuf. Il n'a pas encore de projets, de todos, ni de focus.

### Declaration d'ownership

A la fin du premier boot, le brain te propose la **declaration d'ownership** :

```
Ton brain est configure. On declare l'ownership ?
```

Dis **oui**. C'est ton premier commit — il marque la transition template → brain personnel.
Les satellites (profil/, toolkit/, todo/...) passent en gitignore et vivent dans leurs propres repos.

> Tu peux aussi le faire manuellement : `bash scripts/ownership.sh`

### Ce que tu peux repondre

- `brain boot mode work/<ton-projet>` — si tu veux coder sur un projet
- `brain boot mode brainstorm/<sujet>` — si tu veux explorer une idee
- `brain boot mode brain` — si tu veux travailler sur le brain lui-meme
- Ou simplement decrire ce que tu veux faire — le brain detecte le type de session

---

## Etape 6 — Fermer une session

Quand tu as fini, tape :

```
on wrappe
```

Le brain ferme proprement : metriques capturees, todos mis a jour, claim BSI ferme.

> Ne ferme pas Claude Code avec Ctrl+C avant que le wrap soit termine.

---

## Resume — les commandes essentielles

```bash
# 1. Setup (une seule fois)
bash scripts/brain-setup.sh mon-brain ~/Dev/Brain

# 2. Lancer brain-engine (a chaque session, optionnel)
bash scripts/brain-engine.sh start

# 3. Lancer Claude Code (a chaque session, depuis n'importe ou)
claude
# Puis : brain boot

# 4. Arreter brain-engine
bash scripts/brain-engine.sh stop

# 5. Voir l'etat
bash scripts/brain-engine.sh status
```

---

## FAQ

### Comment arreter brain-engine ?

```bash
bash scripts/brain-engine.sh stop
```

En dernier recours : `pkill -f 'python3.*server.py'`

### Je vois "MYSECRETS absent" — c'est grave ?

Non. MYSECRETS c'est pour les projets qui ont des secrets (tokens API, mots de passe). Si tu n'en as pas besoin, ignore le message. Le brain fonctionne sans.

### Comment mettre a jour le kernel depuis l'upstream ?

```bash
git remote add upstream <URL_DU_TEMPLATE_ORIGINAL>
git fetch upstream
git merge upstream/main
```

### Comment passer brain-engine en mode permanent ?

```bash
# pm2 — restart on crash
bash scripts/brain-engine.sh install pm2

# systemd — survit au reboot
bash scripts/brain-engine.sh install systemd
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
