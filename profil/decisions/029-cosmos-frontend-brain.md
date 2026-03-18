---
scope: kernel
name: ADR-029
title: "Cosmos — frontend du brain : séparabilité kernel/instance, vue owner vs fork"
status: accepted
date: 2026-03-18
deciders: [<owner>]
---

# ADR-029 — Cosmos : frontend du brain

## Principe fondateur

> Tu utilises le kernel. Tu ne vois pas ses internals.
> Comme Linux — l'utilisateur interagit avec le système,
> pas avec le code source du kernel.

Cosmos est le frontend de CORTEX. Il rend le brain configurable et visible
sans jamais exposer ce qui doit rester invariant.

---

## Ce que Cosmos EST

```
Cosmos = UI layer au-dessus de CORTEX
       = l'interface entre l'humain et le brain
       = éditeur de la partie configurable (×, sessions, gates, ambient)
       ≠ le kernel (jamais)
       ≠ accès fichier direct (jamais)
```

Toute écriture passe par `brain_write()` — jamais d'accès fichier direct.
Cosmos lit via MCP (`brain_boot`, `brain_search`, `brain_agents`).
Cosmos écrit via `brain_write()` uniquement.

---

## Séparabilité — la règle kernel/instance

**Ce que Cosmos expose :**

| Couche | Éditable | Visible |
|--------|----------|---------|
| Routing table `×` | ✓ instance | ✓ |
| Sessions (`session-*.yml`) | ✓ instance | ✓ |
| Feature gates (`brain-compose.yml`) | ✓ owner only | ✓ |
| Ambient workflows | ✓ instance | ✓ |
| Proposals learning loop | ✓ approve/reject | ✓ |
| Brain state (claims, now.md) | ✗ lecture seule | ✓ |
| Agents Protocol (`agents/*.md`) | ✗ | ✓ lecture seule |
| Kernel files (KERNEL.md, PATHS.md) | ✗ jamais | ✗ jamais |

**Règle absolue** : zone:kernel → invisible dans Cosmos.
L'utilisateur sait que le kernel existe. Il ne le voit pas. Il ne le touche pas.

---

## Vue owner vs vue fork

### Owner — vue complète

```
Agent graph 3D (ThreeJS)
  ├── Kernel layer     → visible (agents kernel, routing kernel)
  ├── Project layer    → visible + éditable
  └── Personal layer   → visible + éditable

Feature gates          → brain-compose.yml éditable
BACT dashboard         → progression accumulée, milestones
Distillation panel     → activation / config
```

### Fork — vue instance

```
Agent graph 3D (ThreeJS)
  ├── "CORTEX core"    → boîte noire (nom + version, pas d'internals)
  └── Project layer    → visible + éditable

Feature gates          → lecture seule (tier affiché, pas éditable)
BACT dashboard         → leur propre BACT uniquement
Distillation           → visible si tier le permet, sinon locked
```

**La boîte noire** : le fork voit "CORTEX v0.9.0 — kernel" comme un bloc.
Il sait ce qu'il fait (les agents qu'il peut invoquer).
Il ne sait pas comment c'est construit à l'intérieur.
C'est le fossé concurrentiel rendu visible.

---

## Les panels Cosmos

### 1. Agent Graph (ThreeJS 3D)
Visualisation du routing table `×` (ADR-026).
Nœuds = agents. Arêtes = IPC connections.
Couleur par zone (kernel/project/personal).
Clic sur un agent → fiche PCG (Protocol lu depuis agents/*.md, Context, Gate).
**Owner** : graph complet. **Fork** : project layer + CORTEX core opaque.

### 2. Session Builder
Éditeur visuel des `session-*.yml`.
Drag & drop des fichiers L1. Mesure footprint en temps réel.
Alerte si > seuil défini dans `profil/session-footprint.md`.

### 3. Proposals Panel
Interface de la boucle d'apprentissage (ADR-028).
Liste des propositions générées par pattern-scribe + ambient.
Approve / Reject / Modify. Historique des décisions.

### 4. Ambient Board
État des workflows en cours (`workflows/*.yml`).
Statut par step (SPAWN envoyé, RETURN reçu, ESCALATE en attente).
Toggle on/off des agents ambient.
Visualisation des run records.

### 5. Brain State
Live : claims BSI ouverts, session active, now.md last update.
Lecture seule. Le cerveau en temps réel.

### 6. Feature Gates (owner only)
Éditeur `brain-compose.yml` — tier, coach_level, sessions disponibles.
Visualisation des agents unlockés par tier.

---

## Proactif local — angle produit (tier pro/full)

Le brain peut pousser des notifications sans que l'utilisateur soit dans Cosmos :

```
ollama (phi-3-mini) + ambient daemon → 0 token API
Morning briefing, workflow status, pattern alert → Telegram / Cosmos notif panel
GPU episodique — pas continu
```

C'est le brain hors du dev — accompagnement quotidien, zéro friction.
Disponible en tier pro/full. Infrastructure déjà posée (`ambient/daemon.py`).

---

## Ce que Cosmos ne fait JAMAIS

- Accès direct aux fichiers kernel
- Modification du Protocol d'un agent (`agents/*.md` contenu)
- Exposition des secrets / MYSECRETS
- Écriture BSI hors `brain_write()` contrôlé
- Affichage du BACT d'un autre utilisateur

---

## Stack pressenti

- **ThreeJS** — agent graph 3D
- **brain_write() MCP** — toutes les écritures
- **brain_boot() / brain_search()** — lecture contexte
- **WebSocket brain-engine** — live state (claims, ambient status)

---

## Changelog

| Date | Note |
|------|------|
| 2026-03-18 | Création — frontend CORTEX, séparabilité kernel/instance, boîte noire fork, vue owner vs fork ThreeJS, 6 panels, proactif local comme angle produit tier pro/full |
