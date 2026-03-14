# Brief — brain-compose

> Document de préparation à la forge. À lire par `recruiter` avant la session.
> Décisions actées en session 2026-03-13 — ne pas re-débattre.

---

## L'intention

Le brain est un OS. Jusqu'ici il tournait en mono-instance — une machine, une config, un
contexte. C'est suffisant pour commencer. Ce n'est pas suffisant pour grandir.

`brain-compose` est la couche qui rend le brain **modulaire** : plusieurs instances du même
kernel, chacune avec sa propre config et son propre état, sur une ou plusieurs machines.

Ce n'est pas une feature. C'est une architecture.

---

## Le problème qu'il résout

```
Aujourd'hui                        Avec brain-compose
────────────────────────────────   ──────────────────────────────────
1 machine = 1 brain                1 machine = N brains indépendants
1 contexte à la fois               Sessions parallèles possibles
Infra hardcodée dans les Sources   Config par instance, kernel propre
Fork = tout reconfigurer à la main Fork = kernel + config-scribe → opérationnel
Pas de portabilité entre machines  brain-compose.local.yml = registre machine
```

---

## L'architecture — trois couches, une règle

```
KERNEL         agents/, profil/, templates/
               Universel. Partagé entre toutes les instances.
               Mis à jour une fois → profite à tout le monde.
               Versionné dans le repo principal.

INSTANCE       infrastructure/*.md, PATHS.md, projets/, todo/, focus.md
               Personnel. Propre à chaque instance.
               Écrit par config-scribe et les scribes métier.
               Jamais dans le kernel.

PERSONNEL      progression/, capital.md
               Intime. Jamais partagé, jamais exporté.
               Appartient à une personne, pas à un brain.
```

**La règle :** le kernel ne connaît pas les instances. Les instances connaissent le kernel.
Dépendance unidirectionnelle. C'est ce qui permet de mettre à jour le kernel sans casser
quoi que ce soit en dessous.

---

## Kernel partagé — comment concrètement

**Décision actée :** le kernel est partagé, pas dupliqué.

```
~/Dev/
├── Docs/               ← kernel + instance perso (brain principal)
│   ├── agents/         ← kernel
│   ├── profil/         ← kernel
│   ├── infrastructure/ ← instance perso (écrit par config-scribe)
│   ├── projets/        ← instance perso
│   └── PATHS.md        ← instance perso
│
├── client-xyz/         ← instance client
│   ├── agents/         → symlink vers ~/Dev/Docs/agents/  (kernel partagé)
│   ├── profil/         → symlink vers ~/Dev/Docs/profil/
│   ├── infrastructure/ ← config propre (écrit par config-scribe)
│   ├── projets/        ← état propre
│   └── PATHS.md        ← chemins propres
│
└── brain-compose.local.yml   ← registre de toutes les instances sur cette machine
```

**Pourquoi symlinks plutôt que clones ?**
Un `git pull` sur le kernel = toutes les instances à jour instantanément.
Pas de sync manuel. Pas de divergence silencieuse.

**Limite à documenter :** sur Windows ou certains systèmes de fichiers, les symlinks ont
des contraintes. À vérifier lors de la forge.

---

## Les deux fichiers clés

### `brain-compose.yml` — la spec (versionnée dans le kernel)

Ce fichier définit ce qu'une instance brain PEUT être. C'est le schema, pas l'état.

```yaml
# brain-compose.yml
version: "1.0"

# Agents disponibles dans ce kernel
agents:
  core:
    - scribe
    - coach
    - recruiter
    - config-scribe
    - helloWorld
  metier:
    - vps
    - mail
    - ci-cd
    - debug
    - security
    - testing
    - refacto
    - monitoring
    - optimizer-backend
    - optimizer-db
    - optimizer-frontend
    - pm2
    - migration
    - frontend-stack
    - i18n
    - doc
  scribes:
    - todo-scribe
    - toolkit-scribe
    - coach-scribe
    - capital-scribe
    - git-analyst
  meta:
    - orchestrator
    - agent-review
    - mentor
    - interprete
    - brainstorm

# Feature flags — quels agents sont actifs selon le tier
features:
  free:
    - core
    - debug
  pro:
    - core
    - metier
    - scribes
  full:
    - core
    - metier
    - scribes
    - meta
```

> Ce fichier est exportable. Il fait partie du `claude-brain-template`.
> Il définit les possibilités — `brain-compose.local.yml` définit l'état réel.

---

### `brain-compose.local.yml` — le registre machine (non versionné, gitignored)

Ce fichier enregistre les instances actives sur cette machine.

```yaml
# brain-compose.local.yml
# Ne pas versionner — contient des chemins et configs locaux

machine: <nom-machine>

instances:
  perso:
    path: ~/Dev/Docs/
    kernel: ~/Dev/Docs/
    feature_set: full
    config_status: hydrated   # ou: empty, partial
    last_setup: 2026-03-13

  client-xyz:
    path: ~/Dev/client-xyz/
    kernel: ~/Dev/Docs/        # pointe vers le même kernel
    feature_set: pro
    config_status: partial
    last_setup: ~

active: perso
```

---

## Les opérations (via l'agent brain-compose)

```
brain-compose new <nom>       Crée une nouvelle instance :
                               → crée le dossier
                               → symlink vers le kernel
                               → invoque config-scribe pour hydrater la config
                               → ajoute l'entrée dans brain-compose.local.yml

brain-compose list             Liste toutes les instances avec leur statut

brain-compose status [<nom>]   État d'une instance :
                               → config complète ou placeholders résiduels ?
                               → kernel à jour ?

brain-compose sync kernel      Met à jour le kernel (git pull)
                               → toutes les instances profitent instantanément

brain-compose diff <A> <B>     Compare les configs de deux instances
                               → utile avant de migrer un projet d'une instance à l'autre
```

> **Convention plutôt que CLI** : ces opérations sont réalisées par l'agent brain-compose
> via Claude Code. Pas d'outil externe à installer. Claude Code est le runtime.

---

## Relation avec config-scribe

`brain-compose` et `config-scribe` sont des partenaires, pas des concurrents.

```
brain-compose new <nom>
    │
    ├── crée la structure (dossier, symlinks, brain-compose.local.yml)
    │
    └── invoque config-scribe
            │
            └── wizard par catégories → hydrate infrastructure/*.md + PATHS.md
                → confirme : "Instance <nom> opérationnelle"
```

config-scribe ne sait pas qu'il est dans une instance. Il fait son travail.
brain-compose orchestre. config-scribe exécute.

---

## Feature gating — la vision produit

```
claude-brain-template (open-source)
    → brain-compose.yml livré avec feature_set: free
    → agents core + debug disponibles
    → les autres agents existent dans le kernel mais ne sont pas invoquables

Fork personnel
    → feature_set: full
    → tout est disponible, aucune restriction

Brain-as-a-Service
    → feature_set par compte utilisateur
    → tier free → pro → full selon l'abonnement
    → brain-compose.yml est le contrat de service
```

> Les agents "bloqués" ne sont pas absents — ils sont dans le kernel.
> C'est `brain-compose.yml` qui contrôle l'accès, pas la présence des fichiers.
> Même kernel pour tout le monde. Personnalité différente par les feature flags.

---

## Ce qui reste à décider en session forge

1. **Symlinks vs autre mécanisme** — valider que les symlinks tiennent sur toutes les
   plateformes cibles. Alternative : git submodules, git worktrees.

2. **brain-compose.yml dans CLAUDE.md** — comment helloWorld lit les feature flags pour
   savoir quels agents proposer au démarrage.

3. **Scope exact de l'agent brain-compose** — agent Claude pur, ou besoin de scripts bash
   pour créer les symlinks / dossiers ?

4. **Que se passe-t-il si le kernel évolue et casse une instance ?** — stratégie de
   migration (semver sur brain-compose.yml ?).

---

## Plan de la session forge

```
1. Recruiter lit ce brief
2. Questions QCM sur les 4 points ouverts ci-dessus
3. Forge brain-compose agent (depuis _template.md enrichi)
4. Mise à jour brain-compose.yml schema si nécessaire
5. Mise à jour config-scribe — ajouter la génération brain-compose.local.yml
6. Scribe → AGENTS.md + CLAUDE.md + todo brain-compose Phase 2 ✅
```

---

## Ce qu'on ne fera PAS dans cette session

- Écrire du code bash pour les symlinks → documenter le pattern, pas l'implémenter
- Décider du modèle économique Brain-as-a-Service → c'est une session séparée
- Toucher à helloWorld → découplé, session dédiée

---

## Vision produit — brain CLI (capturée 2026-03-13, à brainstormer)

> Ne pas implémenter dans cette session. Capturer l'intention complète.

```bash
brain new              # crée une instance locale, lance config-scribe
                       # opérationnel SANS connexion — kernel local

brain sync -p <pseudo> # prompt password → auth serveur Brain-as-a-Service
                       # valide l'abonnement → renvoie le feature_set
                       # sync contexte distant (progression/, positions, config)
                       # brain-compose.local.yml → tier mis à jour
                       # "Mode actif : pro. 12 agents débloqués."
```

**Ce que ça implique :**

- `brain new` = usage local pur, pas de compte requis. Le kernel est local.
- `brain sync` = pont entre l'instance locale et le service distant.
- Le serveur gère : auth, abonnements, feature_set par compte, sync contexte.
- L'instance locale tourne sans connexion — sync = optionnel, pas obligatoire.

---

## Modèle tokens — décision actée (BYOK)

**Le service ne gère pas les tokens Claude. TOTO apporte son propre accès Claude.**

```
TOTO → abonnement Claude.ai Pro/Max ou clé API Anthropic  (son affaire)
TOTO → abonnement Brain-as-a-Service                      (feature_set + sync)

Tokens Claude     →  100% sur le compte Claude de TOTO
Brain-as-a-Service →  vend les features et le sync, pas la puissance de calcul
```

**Ce que Brain-as-a-Service vend :**

```
✅ Accès aux features selon le tier (feature_set free / pro / full)
✅ Sync du contexte entre machines (progression/, positions, config)
✅ Kernel maintenu et mis à jour
✅ Structure brain prête à l'emploi

❌ Tokens Claude — jamais
❌ Transit de données utilisateur via la clé du service — jamais
```

**Parcours TOTO :**

```
1. TOTO a Claude.ai Pro (ou clé API Anthropic)
2. TOTO crée un compte Brain-as-a-Service
3. brain sync -p toto → auth Super-OAuth → valide abonnement → renvoie feature_set
4. brain-compose.local.yml → tier mis à jour
5. Tokens Claude → toujours sur le compte de TOTO. Le service n'y touche pas.
```

**Pourquoi BYOK est la seule direction raisonnable :**

```
Risque financier  →  zéro. Ce n'est pas le service qui paie les tokens de TOTO.
Risque légal      →  zéro. Pas de transit de données via une clé master.
Risque technique  →  zéro. Pas de quota à gérer, pas de billing tokens à implémenter.
Marge             →  100% prévisible. Abonnement = accès features. Point.
```

**CLI vs convention — réponse finale :**
```
Usage perso (power user)   →  convention pure + agent Claude. Pas de CLI.
Produit distribué          →  CLI `brain` obligatoire. brain new + brain sync.
Les deux coexistent.
```

**L'ironie magnifique :**
`brain sync` tourne sur Super-OAuth pour l'auth.
Le brain s'authentifie avec l'outil que tu as construit.
JWT + Redis + OAuth2 — déjà en prod. La boucle est bouclée.

**Prérequis pour cette vision :**
- brain-compose agent forgé et stable ✅ (cette session)
- config-scribe validé en conditions réelles
- Super-OAuth exposé comme fournisseur d'auth externe
- Serveur Brain-as-a-Service (API sync + gestion abonnements)
- CLI `brain` packagée (npm global ou binaire)
