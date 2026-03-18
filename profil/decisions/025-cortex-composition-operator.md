---
scope: kernel
name: ADR-025
title: "CORTEX — opérateur de composition × et frontière kernel/instance"
status: accepted
date: 2026-03-18
deciders: [<owner>]
---

# ADR-025 — CORTEX : opérateur de composition × et frontière kernel/instance

## Formule canonique

```
Cosmos = CORTEX( Brain(tier | featureFlags) × (satellites + BE + distillation + RAG + coach + BACT) )
```

| Composant | Ce que c'est | Vit où |
|-----------|-------------|--------|
| **CORTEX** | Kernel forkable — invariant, contractuel | `brain-template/` |
| **Brain(tier\|flags)** | CORTEX instancié — config user, gates | `brain-compose.yml` |
| **`×`** | Opérateur de composition — contrat entre CORTEX et ses services | `profil/routing.yml` (à définir) |
| **satellites** | Repos projets qui orbitent le brain | instance locale |
| **BE** | brain-engine — MCP, RAG, embed | VPS / local |
| **distillation** | Fine-tuning local sur contenu propre | instance locale |
| **RAG** | Recherche sémantique sur les fichiers brain | brain-engine |
| **coach** | Agent coach (speech + contextuel + BACT) | kernel + tier |
| **BACT** | Brain Accumulation & Context Transfer — progression long-terme | **instance-local uniquement** |
| **Cosmos** | UI — interface de configuration et d'expérience | brain-ui / SaaS |

---

## Règle BACT — non négociable

> **BACT est toujours instance-local. Il ne se distribue jamais dans un fork.**

Chaque owner construit son propre BACT depuis zéro.
Le BACT du propriétaire (l'owner) ne shippe pas dans brain-template.
Double bénéfice : vie privée préservée + fossé concurrentiel impossible à cloner.

---

## Cas d'usage — frontière par tier

### Owner (l'owner)
```
Cosmos = CORTEX(
  Brain(tier=full, featureFlags=*)
  × (satellites_perso + BE + distillation + RAG + coach[L2] + BACT[accumulé])
)
```
- BACT accumulé depuis le début — exclusif, non transférable
- Distillation activée sur tout
- Coach L2 — connaît l'historique complet
- Cosmos — routing configurable via UI

### fork(user × tier=free)
```
CORTEX_fork(
  Brain(tier=free)
  × (leurs_satellites + RAG[local] + coach_boot)
)
```
- Kernel identique — même protocoles, mêmes agents libres
- Distillation : logique présente dans le kernel, **activation bloquée**
- Coach-boot — speech protocol, zéro contexte accumulé
- BACT : commence à zéro, leur appartient, peut croître si tier upgrade
- Pas de Cosmos

### fork(user × tier=pro)
```
Cosmos_light = CORTEX_fork(
  Brain(tier=pro)
  × (leurs_satellites + BE + RAG + coach[full] + distillation[coach_only] + BACT[le leur])
)
```
- Coach full — speech + contexte session
- Distillation activée sur le coach uniquement
- BACT démarre vide, accumule leur progression
- Cosmos light — UI routing disponible

### fork(user × tier=full)
```
Cosmos = CORTEX_fork(
  Brain(tier=full)
  × (leurs_satellites + BE + distillation[tout] + RAG + coach[L2] + BACT[le leur])
)
```
- Distillation sur tout leur contenu
- Coach L2 alimenté par leur propre BACT
- Cosmos complet

---

## PCG appliqué à la distillation

Le modèle PCG (Protocol × Context × Gate) s'applique à chaque service :

```
Distillation (P) = la logique, l'algorithme    → kernel, shippe dans tout fork
Distillation (C) = sur quoi elle s'applique    → dépend du tier
Distillation (G) = peut-on l'activer           → gated par tier
```

Principe : les free users reçoivent la **transparence** — ils voient la logique,
ils ne peuvent pas l'allumer. Open-source dans l'esprit, sustainable dans le modèle.

---

## L'opérateur × — pièce manquante

Le `×` est le composant le moins défini du système.
C'est lui qui transforme une liste de services en un système cohérent.

**Ce qu'il définit :**
- Qui peut spawner qui (routing inter-agents)
- Quel contexte passe d'un agent à l'autre (format du context packet)
- Quels signaux remontent et vers qui
- Comment Brain parle à ses satellites

**Où il vit :**
- Spec invariante (format) → kernel (`profil/ipc-spec.md` — à créer)
- Routing instance (qui parle à qui) → `profil/routing.yml` — **éditable via Cosmos**

**Ce que Cosmos expose pour `×` :**
- Agent graph — éditeur visuel du routing
- Session builder — contexte par session
- Ambient layer — agents background on/off
- Pattern review — approve/reject apprentissage

---

## Ce que cet ADR ne définit pas encore

- Format exact du context packet (IPC spec) → ADR-026
- Ambient layer — agents background protocol → ADR-027
- Boucle d'apprentissage complète (detect → approve → update) → ADR-028

---

## Changelog

| Date | Note |
|------|------|
| 2026-03-18 | Création — formule canonique Cosmos, règle BACT, cas d'usage par tier, PCG sur distillation, opérateur × identifié comme pièce manquante |
