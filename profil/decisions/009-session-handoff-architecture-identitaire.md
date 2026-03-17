---
name: adr-009-session-handoff-architecture-identitaire
type: decision
context_tier: cold
status: brainstorm — à formaliser en ADR
date: 2026-03-15
session: sess-20260315-0851-bhp-phase2
---

# ADR-009 — Architecture identitaire : Session × Scope → Handoff Chain

> Statut : **brainstorm validé** — vision cohérente, architecture à spécifier
> Émergé : session BHP Phase 2 — coach brainstorm étendu
> Prérequis à : BHP Phase 2, brain-constitution.md, handoff-matrix.md

---

## Insight central

> *La todo ne liste pas des tâches — elle orchestre le niveau de continuité.*
> *Le brain fort ne dépend pas du FULL — il cold-start bien.*
> *L'identité = ce qui reste quand on enlève tout.*

---

## Le problème

Le brain charge du contexte sans modèle formel de continuité entre sessions.
Résultat : trop de contexte (bruit), pas assez (cold start subi), aucune prédictibilité.
Le brain n'a pas d'identité stable parce qu'il n't a pas de chaîne de continuité formalisée.

---

## L'architecture — 3 couches + 4 niveaux de handoff

### Les 3 couches

```
Layer 0  →  Identité     →  FIGÉ        →  qui le brain est — toujours vrai
Layer 1  →  État         →  dynamique   →  où on en est — sprint, projet, position
Layer 2  →  Mémoire      →  éphémère    →  ce qui vient de se passer — handoffs, RAM
```

### Les 4 niveaux de handoff

```
NO    →  Layer 0 uniquement          cold start — identité pure
SEMI  →  Layer 0 + Layer 1 partiel   position chargée
SEMI+ →  Layer 0 + Layer 1 complet   état projet chargé
FULL  →  Layer 0 + Layer 1 + Layer 2 continuité chirurgicale
```

### Le routeur : session_type × scope → handoff_level

```
brainstorm  × architecture  →  NO    (pensée claire, pas de bruit sprint)
debug       × SuperOAuth    →  SEMI  (position + domaine, pas de RAM)
work        × sprint        →  SEMI+ (état du sprint suffit, lundi matin)
work        × continuation  →  FULL  (coupure mid-task, reprise chirurgicale)
deploy      × infra         →  SEMI+ (état infra nécessaire)
coach       × progression   →  SEMI  (position + dernière session)
```

---

## L'inversion

On supposait : FULL HANDOFF = session optimale.

```
FULL  →  continuité maximale, clarté minimale  (bruit)
NO    →  continuité minimale, clarté maximale  (signal)
```

Le cold start n'est pas le mode le plus faible.
C'est l'expression la plus pure de l'identité du brain.

**Le KPI mesurable :** si NO HANDOFF est productif en < 2 minutes → Layer 0 est bon.

---

## Cas d'usage réels

### NO HANDOFF — le brain qui sait qui il est
Brainstorm architecture 7h du matin. Layer 0 seul.
Pas de bruit du sprint précédent. Pensée architecturale nette.

### SEMI — le chirurgien
Bug critique 22h. SuperOAuth. Layer 0 + position debug.
Contexte juste, sans friction. Fix en 30 secondes de boot.

### SEMI+ — lundi matin
TetaRdPG Sprint 4. 3 jours d'absence. Layer 0 + état sprint.
Pas besoin de handoff — l'état du projet suffit. Reprise en 2 minutes.

### FULL — continuation chirurgicale
Refacto coupée à 23h. Layer 0 + Layer 1 + workspace RAM.
Exactement là où on s'est arrêté. Pas de reconstruction.

### Gradient intelligent dans un sprint
```
Lundi matin     →  SEMI+   reprendre l'état
Lundi soir      →  FULL    continuation directe
Mardi matin     →  SEMI+   nouveau jour
Mercredi bug    →  SEMI    position debug uniquement
Vendredi close  →  FULL    wrap complet
```

### Multi-agent
Layer 0 : identique pour tous (identité commune)
Layer 1 : partagé (état de sprint, API contracts)
Layer 2 : isolé par agent (workspace RAM propre)
→ Agents qui partagent l'identité et l'état, pas la mémoire de travail.

### Brain-as-a-Service
`brain new` installe Layer 0. Première session = NO HANDOFF.
Productif immédiatement parce que Layer 0 est solide.
**Layer 0 est le produit.**

---

## Ce qui manque (livrables)

- `profil/brain-constitution.md` — frozen layer formalisée (Layer 0 complet)
- `profil/handoff-matrix.md` — matrice session_type × scope → handoff_level
- `profil/session-continuity-spec.md` — spec complète de la chaîne
- Convention todo → encoder le handoff_level sur chaque entrée
- KPI validation : NO HANDOFF < 2 min → Layer 0 OK

---

## Relation aux ADRs existants

| ADR | Relation |
|-----|----------|
| 002-session-as-identity | Layer 0 = identité de session — ce ADR l'étend |
| 004-trois-couches | Layer 0/1/2 raffine les 3 couches kernel/instance/personnel |
| 005-zones-typees | Frozen layer = zone kernel protégée |

