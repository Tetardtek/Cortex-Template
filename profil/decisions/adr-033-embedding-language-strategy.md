---
scope: kernel
id: ADR-033
title: Stratégie embedding — multilinguisme et distribution brain-template
status: accepted
date: 2026-03-18
deciders: [human, coach]
tags: [embedding, distribution, multilingual, brain-template]
---

# ADR-033 — Stratégie embedding : multilinguisme et distribution brain-template

## Contexte

Le brain-engine embarque un pipeline d'embedding (chunks → vecteurs → UMAP → Cosmos).
Tout le contenu actuel est en FR. Brain-template (ADR-031) sera distribué à des utilisateurs
potentiellement non-FR.

Deux problèmes distincts ont émergé lors du brainstorm 2026-03-18 :

1. **Problème de distribution** : un utilisateur EN installe brain-template → peut-il avoir
   un brain opérationnel dans sa langue ?

2. **Problème de collaboration** : deux instances brain (FR + EN) veulent co-travailler
   sémantiquement → leurs espaces embedding sont-ils commensurables ?

---

## Options explorées

| Option | Description | Verdict |
|--------|-------------|---------|
| A — Modèle multilingue (multilingual-e5) | Un espace commun FR+EN+… | Upgrade path v2 |
| B — Modèles séparés par langue | Silos, pas de cross-lingual | ❌ Éliminé |
| C — Kernel traduit EN+FR en parallèle | Double maintenance garantie | ❌ Éliminé |
| D — Template structurel, contenu souverain | Chaque instance dans sa langue | ✅ Retenu v1 |

---

## Décision

### V1 — Option D : template structurel, instances souveraines

**brain-template distribue :**
- Schéma frontmatter (language-agnostic)
- Scripts bash/Python (language-agnostic)
- Workflow templates (structure)
- Agents `.md` en FR (langue du kernel owner)

**Chaque instance :**
- Forge ses agents dans sa langue dès le premier sprint
- Embarque son propre pipeline embedding avec le modèle de son choix
- Est sémantiquement souveraine — aucune dépendance au brain FR d'origine

**Un utilisateur EN installe brain-template :**
```
1. Clone le template (agents FR comme référence de structure)
2. Forge ses agents EN via recruiter (le FR est un exemple, pas une contrainte)
3. Son brain est 100% EN, embedding 100% EN, Cosmos 100% EN
4. Opérationnel — aucune rupture sémantique
```

**Ce qui ne change pas pour le brain FR owner :**
- Le brain existant n'est pas re-embeddé
- Le modèle embedding actuel reste en place
- Aucune action requise à la distribution du template

---

### V2 — Option A : upgrade multilingual (condition d'activation)

**Condition de déclenchement :**
> Première instance non-FR qui veut co-travailler sémantiquement avec le brain FR.
> Pas avant.

**Quand ce moment arrive :**
```
1. Migrer brain-engine vers multilingual-e5-large (ou équivalent)
2. Re-embedder tous les chunks existants (~30 min, opération batch)
3. Les deux instances partagent désormais un espace embedding commun
4. Cross-lingual search actif : query EN trouve contenu FR et vice-versa
```

**Ce que ça débloque :**
- Brain A (FR) et Brain B (EN) cherchent dans un espace commun
- Cosmos multi-instance : deux nébuleuses dans le même espace UMAP
- Collaboration sémantique sans perdre la souveraineté de chaque instance

---

## Zone filter — découplé (ADR-033a, sujet séparé)

La question du **zone filter** (quels contenus sont indexés selon leur zone) est indépendante
du choix de modèle. Elle sera traitée dans un brainstorm dédié.

Hypothèse de départ pour ADR-033a :
```
kernel   → toujours indexé (open-core, vocabulaire partagé)
project  → TTL basé sur l'activité du sprint
personal → jamais indexé (bact, collaboration, progression)
session  → sélectif (checkpoint utile, contenu brut non)
```

---

## Conséquences

**Immédiat (V1) :**
- Brain-template peut être distribué sans changer l'infrastructure embedding actuelle
- Aucun re-embedding du brain FR owner requis
- Les utilisateurs non-FR sont pleinement autonomes dans leur langue

**Futur (V2) :**
- Migration multilingual-e5 planifiée — opération batch de ~30 min
- Déclenchée sur signal concret (premier besoin de collaboration cross-lingual)
- Pas d'over-engineering préventif

**Philosophie retenue :**
> Chaque brain est souverain dans sa langue. La collaboration sémantique est une
> option d'upgrade, pas un prérequis à la distribution.

---

## Références

- ADR-031 — Distribution model (brain-template)
- ADR-029 — Cosmos frontend brain
- `wiki/brain-engine.md` — pipeline embedding actuel
- `wiki/cosmos.md` — visualisation UMAP
