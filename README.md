# brain-template

> Système de mémoire versionnée pour Claude — template universel.
> Cloner ce repo pour démarrer un brain depuis zéro.

---

## Ce que c'est

Un brain est un **système de contexte persistant** pour les sessions Claude — git + agents calibrés + gestion de contexte. Chaque session repart d'un état connu, pas de zéro.

```
MVCC (git) + agents calibrés + gestion de contexte
= IA qui ne répète pas les mêmes erreurs
  et devient plus précise avec le temps
```

---

## Installation — 15 minutes

### Prérequis

- Git
- Claude Code (ou Claude avec accès aux fichiers)
- Un compte Gitea ou GitHub (pour les remotes)

### Étape 1 — Cloner le template

```bash
git clone git@<GITEA_URL>:<USERNAME>/brain-template.git ~/Dev/Docs
cd ~/Dev/Docs
```

### Étape 2 — Configurer CLAUDE.md

```bash
cp profil/CLAUDE.md.example ~/.claude/CLAUDE.md
# Remplacer les deux variables machine
sed -i 's|<BRAIN_ROOT>|/home/<user>/Dev/Docs|g' ~/.claude/CLAUDE.md
sed -i 's|<BRAIN_NAME>|prod|g' ~/.claude/CLAUDE.md
# Choisir un nom parlant : prod / dev-laptop / template-test
# Ce nom identifie l'instance — critique si plusieurs brains sur la même machine
```

### Étape 3 — Configurer PATHS.md

Ouvrir `PATHS.md` et remplacer tous les placeholders :

| Placeholder | Remplacer par |
|-------------|---------------|
| `<BRAIN_ROOT>` | Chemin absolu du brain (ex: `/home/alice/Dev/Docs`) |
| `<GITEA_URL>` | URL de ton Gitea (ex: `git@git.example.com`) |
| `<USERNAME>` | Ton username Gitea |
| `<PROJECTS_ROOT>` | Dossier de tes projets (ex: `/home/alice/Dev/Github`) |
| `<HOME>` | Ton home (ex: `/home/alice`) |

### Étape 4 — Configurer la collaboration

```bash
cp profil/collaboration.md.example profil/collaboration.md
# Éditer profil/collaboration.md — personnaliser langue, ton, règles spécifiques
```

### Étape 5 — Créer les satellites (optionnel mais recommandé)

```bash
# Créer sur Gitea : brain-profil, brain-todo, toolkit, brain-agent-review, progression-coach
# Puis :
git clone <GITEA_URL>:<USERNAME>/toolkit.git ~/Dev/Docs/toolkit
git clone <GITEA_URL>:<USERNAME>/brain-profil.git ~/Dev/Docs/profil
git clone <GITEA_URL>:<USERNAME>/brain-todo.git ~/Dev/Docs/todo
git clone <GITEA_URL>:<USERNAME>/brain-agent-review.git ~/Dev/Docs/reviews
git clone <GITEA_URL>:<USERNAME>/progression-coach.git ~/Dev/Docs/progression
```

### Étape 6 — Vérification cold boot

Ouvrir une session Claude et vérifier :
```
Bonjour — démarre le brain (helloWorld)
```

Signal de succès : contexte posé en < 3 échanges sans redemander qui tu es.

---

## Structure

```
brain/
├── README.md                    ← ce fichier
├── PATHS.md                     ← chemins machine (à personnaliser)
├── BRAIN-INDEX.md               ← registre BSI (locking sessions parallèles)
├── agents/
│   ├── _template.md             ← template pour créer un agent
│   ├── AGENTS.md                ← index complet des agents
│   ├── coach.md                 ← présence permanente — coaching progression
│   ├── scribe.md                ← gardien du brain
│   ├── brainstorm.md            ← exploration et décisions
│   ├── aside.md                 ← convention /btw
│   └── [30+ agents spécialisés]
└── profil/
    ├── CLAUDE.md.example        ← bootstrap Claude (copier vers ~/.claude/)
    ├── collaboration.md.example ← règles de travail (à personnaliser)
    ├── memory-architecture.md   ← TTL, Sectionnarisation, Stratification
    ├── bsi-spec.md              ← Brain Session Index — spec locking sessions
    ├── context-hygiene.md       ← chargement sélectif du contexte
    ├── anti-hallucination.md    ← règles globales anti-hallucination
    ├── memory-integrity.md      ← règles d'écriture dans le brain
    ├── scribe-pattern.md        ← pattern Scribe — agents écrivants
    └── scribe-system.md         ← cartographie des scribes
```

---

## Agents inclus

| Catégorie | Agents |
|-----------|--------|
| **Présence permanente** | `coach` |
| **Brain maintenance** | `scribe`, `todo-scribe`, `toolkit-scribe`, `coach-scribe` |
| **Navigation** | `orchestrator`, `interprete`, `aside`, `helloWorld` |
| **Exploration** | `brainstorm`, `mentor`, `recruiter`, `agent-review` |
| **Code** | `code-review`, `security`, `testing`, `debug`, `refacto` |
| **DevOps** | `vps`, `ci-cd`, `monitoring`, `pm2`, `migration` |
| **Frontend** | `frontend-stack`, `optimizer-frontend`, `i18n`, `doc` |
| **Backend** | `optimizer-backend`, `optimizer-db` |
| **Infrastructure mail** | `mail` |
| **Capital / CV** | `capital-scribe`, `git-analyst` |
| **Configuration** | `config-scribe`, `brain-compose` |

---

## Architecture — pourquoi ça marche

**3 couches combinées :**

1. **Git = MVCC gratuit** — toute décision versionnée, traçable, réversible
2. **Agents calibrés** — chaque agent a un scope déclaré, des sources conditionnelles, un cycle de vie
3. **Brain = couche de coordination** — chargement sélectif, mémoire sectionnarisée, procédures de reprise

Voir `profil/memory-architecture.md` pour les 3 piliers (TTL, Sectionnarisation, Stratification).

---

## Personnalisation

Après installation, créer à la racine :

```
focus.md        ← état de tes projets actifs
projets/        ← une fiche par projet (template dans profil/memory-architecture.md)
infrastructure/ ← config VPS, Docker, etc.
```

---

## Brain Session Index (BSI)

Le `BRAIN-INDEX.md` permet de travailler sur plusieurs machines en parallèle sans collision.
Le scribe gère les claims — voir `profil/bsi-spec.md`.

---

## Licence

MIT — utilise, forke, adapte.
