---
id: ADR-033a
title: Embedding zone filter — quoi indexer, quand, jusqu'à quand
status: accepted
date: 2026-03-18
deciders: [human, coach]
tags: [embedding, zone-filter, brain-engine, indexing]
scope: kernel
---

# ADR-033a — Embedding zone filter

## Contexte

Le brain-engine embède aujourd'hui tout le contenu sans filtre.
Dès que brain-template est distribué et que la confidentialité compte,
indexer aveuglément devient un problème :

- Du contenu personnel (bact, collaboration, progression) entre dans l'index
- Des sessions fermées depuis 6 mois restent dans le Cosmos
- Des claims BSI structurés polluent la recherche sémantique

Il faut une règle claire : **quoi** indexer, **quand** le retirer.

---

## Décision

### Règles zone par zone

| Contenu | Zone | Règle | Raison |
|---------|------|-------|--------|
| `agents/`, `contexts/`, `workflows/`, `KERNEL.md`, `wiki/` | kernel | **Toujours indexé** | Vocabulaire de base — haute valeur sémantique permanente |
| `toolkit/` | kernel/project | **Toujours indexé** | Patterns réutilisables — valeur inter-sprints |
| `profil/decisions/` (ADRs) | déclaré par fichier | **Selon `scope` frontmatter** | Certains ADRs sont kernel (archi brain), d'autres project (décision produit) |
| `projets/`, `handoffs/`, `workspace/<sprint>/` | project | **TTL 60 jours** depuis dernier git commit | Pertinent pendant le sprint, bruit ensuite |
| `now.md`, `checkpoint.md` | session | **Indexé tant qu'actif**, supprimé au close claim | Utile en cours de session, obsolète après |
| `claims/` | session | **Jamais** | Trop structuré, zéro valeur sémantique prose |
| `profil/bact/`, `profil/collaboration.md` | personal | **Jamais** | Privé — ne sort pas même dans le Cosmos owner |
| `progression/` | personal | **Jamais** | Journal personnel — hors embedding |

---

### Mécanisme de décision — hybride

```
Règle 1 — Répertoire (défaut)
  agents/      → kernel  → toujours
  toolkit/     → kernel  → toujours
  wiki/        → kernel  → toujours
  projets/     → project → TTL
  workspace/   → project → TTL
  handoffs/    → project → TTL
  claims/      → session → jamais
  profil/bact/ → personal → jamais
  progression/ → personal → jamais

Règle 2 — Frontmatter scope (override sur Règle 1)
  scope: kernel  → toujours indexé (même si dans profil/)
  scope: project → TTL 60 jours
  scope: personal → jamais
  scope: session  → indexé tant qu'actif

Règle 2 prend la main sur Règle 1 si scope est déclaré.
```

**Application concrète aux ADRs :**
```
profil/decisions/adr-003-scribe-pattern.md
  scope: kernel → toujours indexé — archi brain permanente

profil/decisions/adr-008-superoauth-multitenant.md
  scope: project → TTL — décision produit spécifique, pas archi brain
```

---

### TTL — Option A : git-based

```
TTL = date du dernier git commit sur le fichier + 60 jours

Si file.last_commit + 60j < today → retirer de l'index
                                   → ne pas supprimer le fichier
                                   → juste dé-indexer

Implémentation : brain-engine lit git log --follow -- <file>
                 compare la date au seuil
                 décision locale, aucun couplage externe
```

**Upgrade path BSI-based (non activé) :**
Si un jour le TTL git s'avère insuffisant (fichier non commité mais sprint actif),
le BSI peut fournir un signal d'activité. Déclenché sur besoin concret — pas avant.
Le BSI ne pilote pas l'embedding aujourd'hui : deux couches, deux responsabilités.

---

### Frontmatter ADR — champ scope obligatoire

À partir d'aujourd'hui, tout nouvel ADR déclare son scope :

```yaml
---
id: ADR-NNN
title: ...
status: accepted
date: YYYY-MM-DD
scope: kernel | project | personal
---
```

**Règle de classification ADR :**
```
scope: kernel  → décision sur l'architecture du brain lui-même
                 (agents, protocoles, zones, embedding, distribution)

scope: project → décision sur un projet produit spécifique
                 (SuperOAuth, OriginsDigital, Cosmos features...)
```

**Patch ADRs existants (001-033a) :**
Opération batch — ajouter `scope: kernel | project` selon la règle ci-dessus.
Les ADRs 001-022 sont majoritairement kernel (fondations du brain).
Les ADRs 023-033 sont à classifier au cas par cas.

---

## Conséquences

**Immédiat :**
- brain-engine reçoit les règles de zone → filtre à implémenter
- Template ADR mis à jour (`scope` obligatoire)
- 33 ADRs existants à annoter (opération batch)

**Cosmos :**
- Nébuleuse plus propre — plus de bruit session/claims/personal
- Zones visuellement distinctes : kernel (dense, stable), project (dynamique, TTL), session (éphémère)

**Confidentialité :**
- Contenu personal ne sort jamais de l'index, même en mode debug
- Valide pour distribution brain-template : un utilisateur qui clone ne voit jamais le bact owner

---

## Ce qui n'est PAS décidé ici

- Taille des chunks (séparé — brain-engine config)
- Fréquence de re-indexing (séparé — cron brain-engine)
- Format du vecteur index (séparé — brain-engine schema)
- Multilinguisme embedding (ADR-033 — déjà acté)

---

## Références

- ADR-033 — Stratégie embedding multilinguisme (Option D + upgrade path A)
- ADR-005 — Zones typées + protection graduée
- ADR-022 — Modèle de distribution open-core
- `wiki/brain-engine.md` — pipeline embedding actuel
- `wiki/cosmos.md` — visualisation UMAP
