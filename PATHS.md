# PATHS.md — Résolution des chemins machine

> ⚠️ Fichier machine-spécifique — seul fichier à mettre à jour lors d'un export ou changement de machine.
> Tous les agents utilisent les noms sémantiques ci-dessous. Ne jamais hardcoder un chemin absolu ailleurs.

---

## Chemins actifs

| Nom sémantique | Chemin réel | Remote | Gitignored dans brain |
|----------------|-------------|--------|----------------------|
| `brain/` | `<BRAIN_ROOT>` | `<GITEA_URL>/<USERNAME>/brain` | — (repo racine) |
| `toolkit/` | `<BRAIN_ROOT>/toolkit/` | `<GITEA_URL>/<USERNAME>/toolkit` | ✅ |
| `progression/` | `<BRAIN_ROOT>/progression/` | `<GITEA_URL>/<USERNAME>/progression-coach` | ✅ |
| `reviews/` | `<BRAIN_ROOT>/reviews/` | `<GITEA_URL>/<USERNAME>/brain-agent-review` | ✅ |
| `profil/` | `<BRAIN_ROOT>/profil/` | `<GITEA_URL>/<USERNAME>/brain-profil` | ✅ |
| `todo/` | `<BRAIN_ROOT>/todo/` | `<GITEA_URL>/<USERNAME>/brain-todo` | ✅ |
| `projects/` | `<PROJECTS_ROOT>` | GitHub | — |
| `home/` | `<HOME>` | — | — |

## Architecture satellite repos

Les repos gitignorés dans `brain/` sont des **satellites autonomes** — chacun a son propre remote.

```bash
git clone <GITEA_URL>:<USERNAME>/brain.git <BRAIN_ROOT>
git clone <GITEA_URL>:<USERNAME>/toolkit.git <BRAIN_ROOT>/toolkit
git clone <GITEA_URL>:<USERNAME>/progression-coach.git <BRAIN_ROOT>/progression
git clone <GITEA_URL>:<USERNAME>/brain-agent-review.git <BRAIN_ROOT>/reviews
git clone <GITEA_URL>:<USERNAME>/brain-profil.git <BRAIN_ROOT>/profil
git clone <GITEA_URL>:<USERNAME>/brain-todo.git <BRAIN_ROOT>/todo
```

---

## Règle anti-hallucination — obligatoire pour tous les agents

> Si un chemin n'est pas dans cette table → **ne pas deviner**.
> Écrire : `"Information manquante — vérifier PATHS.md"`

---

## Procédure — nouvelle machine

```bash
# 1. Cloner brain-template ou tous les satellites
git clone <GITEA_URL>:<USERNAME>/brain.git <BRAIN_ROOT>
# ... (voir ci-dessus)

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
