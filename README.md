# brain-template

> Système de coordination multi-instances pour Claude — protocole BSI-v3.
> Forke ce repo pour démarrer ton propre brain.

---

## Ce que c'est

Un brain est un **système de contexte persistant et coordonné** pour Claude.
Chaque session repart d'un état connu. Plusieurs instances peuvent travailler en parallèle sans conflit.

```
Git (MVCC) + Agents calibrés + Protocole BSI-v3
= Claude qui ne répète pas les mêmes erreurs
  qui coordonne plusieurs instances simultanées
  qui respecte ton périmètre de travail
```

---

## Tiers

| Tier | Accès | Activation |
|------|-------|-----------|
| **free** | Kernel complet + BSI-v3 + agents fondamentaux | Fork public — aucune clé |
| **pro** | + Agents métier (code-review, security, vps, ci-cd…) | Clé API `tier: pro` |
| **full** | + Distillation locale (brain-engine) + instances rendering | Clé API `tier: full` |

### Tier free — ce que tu as sans rien demander

```
Agents : coach, scribe, debug, mentor, helloWorld, brainstorm, orchestrator,
         todo-scribe, interprete, aside, recruiter, agent-review

Protocole BSI-v3 complet :
  - Multi-instances sans conflit (file-lock.sh + preflight-check.sh)
  - Human gate + pause cascade (human-gate-ack.sh)
  - Vue live multi-instances (brain-status.sh)
  - Theme branches + workflows déclarés
  - Tiered-close + exit triggers

Modes brain-compose : prod, dev, brainstorm, coach, debug, HANDOFF…
```

### Tier pro — avec clé API

```
Agents supplémentaires : code-review, security, testing, refacto,
                         vps, ci-cd, monitoring, pm2, migration,
                         frontend-stack, optimizer-*, toolkit-scribe,
                         coach-scribe, git-analyst, capital-scribe,
                         i18n, doc, mail, config-scribe

→ Ajouter dans brain-compose.yml :
    brain_api_key: bk_live_<ta-clé>
```

### Tier full — avec clé API full

```
Tout pro +
  - brain-engine en local (distillation 2-pass, résumés compressés)
  - Mode rendering : instances autonomes sur tes projets
  - RAG sur l'historique brain
  - Toutes les optimisations de contexte (BE-*)

→ brain-engine s'installe localement
→ Sans clé valide : brain fonctionne en free, distillation inactive
→ Clé liée à ton fork — non redistribuable
```

> **Obtenir une clé :** contact@<OWNER_DOMAIN> *(beta privée — partage limité)*

---

## Brain API Key — configuration

### Ajouter une clé

```bash
# Dans brain-compose.yml — champ déjà présent, remplacer null :
brain_api_key: bk_live_<ta-clé>

# Ou via brain-setup.sh (nouvelle machine) — étape 3.5 le demande automatiquement
```

La clé est validée au boot par `key-guardian` (silencieux, timeout 3s) :
- **Succès** → `feature_set` mis à jour dans `brain-compose.local.yml`
- **VPS down** → grace period 72h depuis dernière validation — tier conservé
- **Clé absente/invalide** → tier free, aucun blocage, aucune erreur

### Format des clés

| Format | Usage | Tier |
|--------|-------|------|
| `bk_live_<32chars>` | Production | pro ou full selon la clé |
| `bk_test_<32chars>` | Dev/test local | free forcé (toujours valide) |

### Tester sans clé

```bash
# Clé test — tier free garanti, pas de réseau requis
brain_api_key: bk_test_local_dev_key_xxxxxxxxxxxxxxxx
```

---

## Installation — 15 minutes

### Prérequis

- Git
- Claude Code CLI
- Un repo Git (Gitea, GitHub…)

### 1. Forker le template

```bash
git clone git@<TON_GITEA>:<USERNAME>/brain-template.git ~/Dev/Brain
cd ~/Dev/Brain
git remote rename origin upstream   # garder le lien vers les updates kernel
git remote add origin git@<TON_GITEA>:<USERNAME>/mon-brain.git
git push -u origin main
```

### 2. Configurer CLAUDE.md

```bash
# Copier vers le profil global Claude
cp profil/CLAUDE.md.example ~/.claude/CLAUDE.md

# Éditer ~/.claude/CLAUDE.md :
#   brain_root: /home/<user>/Dev/Brain
#   brain_name: prod
```

### 3. Configurer les chemins machine

```bash
# Éditer PATHS.md — remplacer les placeholders :
#   <BRAIN_ROOT>     → /home/<user>/Dev/Brain
#   <GITEA_URL>      → git@git.example.com
#   <USERNAME>       → ton username
#   <PROJECTS_ROOT>  → /home/<user>/Dev/Projects
```

### 4. Personnaliser brain-compose.local.yml

```bash
cp brain-compose.local.yml.example brain-compose.local.yml
# Éditer : kernel_path, instances, [api_key si tier pro/full]
```

### 5. Cold boot

Ouvrir Claude Code dans le dossier brain et taper :
```
Bonjour — démarre le brain (helloWorld)
```

Signal de succès : contexte posé en < 3 échanges, sans redemander qui tu es.

---

## Multi-instances — le protocole

Plusieurs fenêtres Claude Code sur le même brain, sans conflit :

```bash
# Fenêtre 1 — coach/discussion
bash scripts/brain-status.sh          # voit tout ce qui se passe

# Fenêtre 2 — travail terrain (ex: projet superoauth/)
# Elle ouvre un claim, pre-flight check avant chaque écriture,
# mutex si fichier partagé → BRAIN-INDEX.md synchronise tout
```

Guide complet : `wiki/multi-instance.md`

---

## Structure

```
brain/
├── agents/               ← 57 agents calibrés (index : agents/AGENTS.md)
├── scripts/              ← BSI-v3 protocol (index : scripts/README.md)
│   ├── brain-status.sh   ← vue live multi-instances
│   ├── preflight-check.sh← 6 checks avant écriture
│   ├── file-lock.sh      ← mutex fichier
│   ├── human-gate-ack.sh ← gate humain + pause cascade
│   └── ...
├── workflows/            ← chaînes de satellites déclarées
├── wiki/                 ← guides (multi-instance, patterns, concepts…)
├── locks/                ← registre mutex fichiers (BSI-v3-7)
├── claims/               ← sessions BSI (vide au démarrage)
├── BRAIN-INDEX.md        ← état global — lu par toutes les instances
├── KERNEL.md             ← loi des zones (ne pas modifier seul)
├── brain-compose.yml     ← modes, feature flags, agents autorisés
├── brain-compose.local.yml← config machine (non versionné)
└── PATHS.md              ← chemins machine (à personnaliser)
```

---

## BSI-v3 — protocole de coordination

Le protocole qui permet plusieurs instances sans collision :

| Composant | Rôle |
|-----------|------|
| `claims/*.yml` | Chaque session déclare son scope — visible par toutes |
| `BRAIN-INDEX.md` | Registre global — état en temps réel |
| `file-lock.sh` | Mutex fichier — empêche les écritures simultanées |
| `preflight-check.sh` | 6 checks avant d'écrire (scope, zone, lock, circuit breaker…) |
| `human-gate-ack.sh` | Pause planifiée ou urgence — cascade sur les instances enfants |
| `brain-status.sh` | Vue live : qui travaille où, quels fichiers lockés, quels signaux |

---

## Zones — ce que tu peux modifier

| Zone | Contenu | Règle |
|------|---------|-------|
| **kernel** | `agents/` `scripts/` `KERNEL.md` `brain-compose.yml` | Décision humaine — `preflight` bloque les agents |
| **project** | `todo/` `workspace/` `projets/` | Libre — rendering mode ici |
| **personal** | `profil/capital` `progression/` | Ton contenu, non distribué |

---

## Recevoir les updates kernel

```bash
git fetch upstream
bash scripts/kernel-update-check.sh --remote  # détecte conflits vs updates
# Appliquer les non-conflictuels :
bash scripts/kernel-update-check.sh --remote --apply
```

`kernel.lock` — checksums SHA-256 des fichiers kernel.
Permet de savoir exactement ce qui a divergé avant de puller.

---

## Roadmap

- [x] BSI-v3 multi-instances (v3-1b → v3-8)
- [x] Rendering mode — instances autonomes projet
- [x] kernel.lock + isolation check
- [x] Validation clé API (tier pro/full) — key-guardian + grace 72h
- [ ] kernel-orchestrator (v3-9) — routage autonome entre satellites
- [ ] brain-engine hosted (distillation managée)

---

## Licence

MIT — kernel libre. brain-engine (distillation) non inclus dans ce template.
