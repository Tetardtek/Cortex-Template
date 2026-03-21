# PATHS.md — Résolution des chemins machine

> ⚠️ Fichier machine-spécifique — seul fichier à mettre à jour lors d'un export ou changement de machine.
> Tous les agents utilisent les noms sémantiques ci-dessous. Ne jamais hardcoder un chemin absolu ailleurs.

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

## Procédure — nouvelle machine

```bash
# 1. Cloner le brain + tous les satellites
git clone <GIT_HOST>:<ORG>/Cortex-Template.git <BRAIN_ROOT>
# ... (voir ci-dessus pour chaque satellite)

# 2. Installer CLAUDE.md
cp <BRAIN_ROOT>/profil/CLAUDE.md.example ~/.claude/CLAUDE.md
sed -i 's|<BRAIN_ROOT>|<CHEMIN_REEL>|g' ~/.claude/CLAUDE.md

# 3. Déployer le global memory Claude (layer cognitif)
ln -s <BRAIN_ROOT>/memory-global ~/.claude/memory

# 4. Mettre à jour ce fichier PATHS.md avec les chemins réels
# 5. Done — le brain est opérationnel
```

---

## Historique machines

| Machine | OS | `brain/` | Actif |
|---------|----|----------|-------|
| *(à remplir)* | | | |
