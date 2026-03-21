# PATHS.md — Résolution des chemins machine

> **Fichier de reference** — les agents utilisent les noms semantiques ci-dessous pour resoudre les chemins.
> Les placeholders (`<BRAIN_ROOT>`, `<GIT_HOST>`, `<ORG>`) sont remplaces automatiquement par `setup.sh`
> dans `brain-compose.local.yml`. Ce fichier reste avec des placeholders dans le template — c'est normal.
> Ne jamais hardcoder un chemin absolu dans les agents — toujours utiliser les noms semantiques.

---

## Chemins actifs

| Nom sémantique | Chemin réel | Remote | Gitignored dans brain |
|----------------|-------------|--------|----------------------|
| `brain/` | `<BRAIN_ROOT>` | `<GIT_HOST>/<ORG>/Cortex-Template` | — (repo racine) |
| `toolkit/` | `<BRAIN_ROOT>/toolkit/` | `<GIT_HOST>/<ORG>/Cortex-Toolkit` | ✅ |
| `progression/` | `<BRAIN_ROOT>/progression/` | `<GIT_HOST>/<ORG>/Cortex-Progression` | ✅ |
| `reviews/` | `<BRAIN_ROOT>/reviews/` | `<GIT_HOST>/<ORG>/Cortex-Reviews` | ✅ |
| `profil/` | `<BRAIN_ROOT>/profil/` | `<GIT_HOST>/<ORG>/Cortex-Profil` | ✅ |
| `todo/` | `<BRAIN_ROOT>/todo/` | `<GIT_HOST>/<ORG>/Cortex-Todo` | ✅ |
| `projects/` | `<PROJECTS_ROOT>` | GitHub / Gitea | — |
| `home/` | `<HOME>` | — | — |

## Architecture satellite repos

Les repos gitignorés dans `brain/` sont des **satellites autonomes** — chacun a son propre remote.

```bash
git clone <GIT_HOST>:<ORG>/Cortex-Template.git <BRAIN_ROOT>
git clone <GIT_HOST>:<ORG>/Cortex-Toolkit.git <BRAIN_ROOT>/toolkit
git clone <GIT_HOST>:<ORG>/Cortex-Progression.git <BRAIN_ROOT>/progression
git clone <GIT_HOST>:<ORG>/Cortex-Reviews.git <BRAIN_ROOT>/reviews
git clone <GIT_HOST>:<ORG>/Cortex-Profil.git <BRAIN_ROOT>/profil
git clone <GIT_HOST>:<ORG>/Cortex-Todo.git <BRAIN_ROOT>/todo
```

---

## Règle anti-hallucination — obligatoire pour tous les agents

> Si un chemin n'est pas dans cette table → **ne pas deviner**.
> Écrire : `"Information manquante — vérifier PATHS.md"`

---

## Procedure — nouvelle machine

```bash
# 1. Cloner le brain
git clone <GIT_HOST>:<ORG>/Cortex-Template.git <BRAIN_ROOT>
cd <BRAIN_ROOT>

# 2. Lancer setup.sh — clone les satellites, build le dashboard, init brain-engine
bash setup.sh

# 3. Configurer Claude Code
cp profil/CLAUDE.md.example ~/.claude/CLAUDE.md
# Editer brain_root et brain_name dans ~/.claude/CLAUDE.md

# 4. (Optionnel) Deployer le global memory Claude
ln -s <BRAIN_ROOT>/memory-global ~/.claude/memory

# 5. Lancer brain-engine + brain boot
bash brain-engine/start.sh
# Dans un autre terminal : claude → brain boot
```

> Guide detaille : [docs/getting-started.md](docs/getting-started.md)

---

## Historique machines

| Machine | OS | `brain/` | Actif |
|---------|----|----------|-------|
| *(à remplir)* | | | |
