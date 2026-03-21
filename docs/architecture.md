# Architecture du brain

> Comment les pieces s'assemblent. Version humaine — pas la spec technique.

---

## Vue d'ensemble

Le brain c'est 3 couches :

**1. Le kernel** — l'identite
- Les regles qui ne changent pas (KERNEL.md, constitution, PATHS.md)
- Les agents specialises (~81 fichiers .md)
- Le profil de collaboration
- Le brain-compose.yml (config, tiers, modes)

**2. Les satellites** — la memoire
- `todo/` — les intentions et taches
- `progression/` — ta progression, tes skills, ton metabolisme
- `toolkit/` — les patterns valides en prod, reutilisables
- `reviews/` — les audits d'agents
- `profil/` — ton identite, tes objectifs

Chaque satellite est un repo Git independant. Le kernel les ignore (gitignore). Ils vivent leur vie.

**3. L'instance** — le runtime
- `claims/` — quelle session est active, sur quoi
- `workspace/` — les sprints en cours, checkpoints
- `brain-compose.local.yml` — config machine (tier, cle API, peers)
- `brain.db` — base SQLite pour BSI et etat live

---

## Comment une session fonctionne

```
Tu tapes "brain boot mode work/mon-projet"
          |
          v
    helloWorld lit ta config
          |
          v
    Charge le minimum (L0 : kernel + paths + config)
          |
          v
    Lit le manifest de session (contexts/session-work.yml)
          |
          v
    Charge les agents pertinents (L1 : debug, coach-boot, scribe)
          |
          v
    Charge le projet si declare (L2 : projets/mon-projet.md + todo/mon-projet.md)
          |
          v
    Ouvre un claim BSI (trace de session)
          |
          v
    "Pret." → tu travailles
          |
          v
    Tu dis "on wrappe"
          |
          v
    Close sequence : metriques → todos → scribe → coach → BSI close
```

---

## Les 4 couches de chargement

Le brain ne charge pas tout. Il utilise 4 couches, du plus leger au plus complet :

**L0 — Toujours charge** (~5%)

3 fichiers. L'identite du brain. Jamais retire.

**L1 — Selon la session** (~15%)

Les agents et fichiers specifiques au type de session. `work` charge debug + coach. `deploy` charge vps + ci-cd. Deterministe : meme session = meme chargement.

**L2 — Selon le projet** (~10%)

Si tu declares un projet dans ta commande, ses fichiers sont charges. Silencieux si le projet n'existe pas.

**L3 — Sur demande** (0% au boot)

Tout le reste. Tu demandes "Charge l'agent testing" → il arrive. Jamais proactif.

**Resultat** : ~25% du contexte au boot, pas 80%. Le brain demarre vite.

---

## Les zones — qui ecrit ou

Le brain a des zones protegees. Chaque session sait ou elle peut ecrire :

**Zone kernel** — protection maximale

KERNEL.md, CLAUDE.md, agents/, profil/. Aucune modification sans decision humaine. Session `edit-brain` requise.

**Zone satellites** — vie libre

todo/, toolkit/, progression/, reviews/. Les scribes ecrivent librement. Promotion vers le kernel possible.

**Zone instance** — etat runtime

claims/, workspace/, brain.db. Geree automatiquement par les agents systeme.

**Zone projet** — code externe

Ton code, tes repos. Le brain y travaille en session `work`/`debug`/`deploy` mais ne melange jamais avec le kernel.

> Regle : une feature grandit dans un satellite → elle peut etre promue dans le kernel. Le kernel ne derive jamais vers un satellite.

---

## Les tiers — qui a acces a quoi

Le brain a 4 niveaux d'acces. Chaque tier debloque des agents et des sessions :

> 🟢 **free** — le brain fonctionne. Debug, brainstorm, scribes, protection secrets.

> 🔵 **featured** — le brain te connait. Coach complet, distillation RAG, progression.

> 🟠 **pro** — l'atelier complet. Review, securite, tests, deploy, perf, infra.

> 🟣 **full** — ton brain. Modification kernel, pilotage long, supervision.

Detail complet → voir les Vues par tier dans la sidebar.

---

## Les agents — comment ils s'organisent

Chaque agent a un fichier `.md` avec :
- Un **boot-summary** (~25 lignes) — charge au demarrage de session
- Un **detail** (reste du fichier) — charge quand l'agent est actif

Les agents se declenchent automatiquement (domaine detecte) ou sur invocation explicite. Ils se delegent entre eux — chaque agent connait ses limites.

**4 familles :**
- **Metier** — debug, review, securite, tests, refacto, perf, infra
- **Scribes** — scribe, todo-scribe, metabolism-scribe, wiki-scribe
- **Presences** — coach, secrets-guardian, helloWorld, session-orchestrator
- **Systeme** — key-guardian, pre-flight, feature-gate, hypervisor

---

## Multi-instance

Le brain peut tourner sur plusieurs machines et plusieurs sessions en parallele.

- Chaque session a un **claim BSI** — les sessions se voient entre elles
- Les **peers** se declarent dans brain-compose.local.yml
- La **synchronisation** passe par Git (push/pull) et brain.db (SQLite replique)

Si deux sessions veulent ecrire au meme endroit → conflit detecte, resolution humaine.

---

## Pour aller plus loin

- **Detail technique** : wiki/ — session-matrix, context-loading, agents-architecture
- **Agents par famille** : Code & Qualite, Infra & Deploy, Brain & Systeme dans la sidebar
- **Recettes** : Workflows dans la sidebar
