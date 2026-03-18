---
id: ADR-035
title: Mode Pilote — session longue durée, copilotage humain-brain
status: accepted
date: 2026-03-18
deciders: [human, coach]
tags: [session, mode, pilote, cognitif, collaboration]
scope: kernel
---

# ADR-035 — Mode Pilote

## Contexte

Quatre modes de session ont émergé dans le brain, mais seuls navigate, work et
swarm avaient une sémantique formelle. Le mode de collaboration le plus riche —
celui où humain et brain co-construisent sur la durée — restait implicite.

La session 2026-03-18 a été entièrement en mode pilote sans qu'il soit nommé :
zone filter, ADR-033/033a/034, Cosmos local, brain-template. Ce mode existait
dans la pratique avant d'exister dans le kernel.

---

## Décision

### Définition

```
Mode Pilote = session longue durée, contexte maximal, humain décide la direction
              à chaque fork important. Brain est copilote actif — pas exécutant.

"On vole ensemble. Tu tiens le manche. Je gère les instruments."
```

### Propriétés

| Propriété | Valeur |
|-----------|--------|
| Durée | Illimitée — dure tant que l'énergie le permet |
| Contexte | FULL — tous les layers chargés |
| Initiative brain | Haute — propose, anticipe, signale |
| Gates humains | Sur les forks architecturaux et décisions irréversibles |
| Write mode | Autorisé partout selon la zone |
| Autonomie | Parallélisation possible (scripts + ADR en simultané) |
| Drift | Assumé et capturé — chaque insight est documenté immédiatement |

### Ce qui distingue Pilote des autres modes

```
Navigate  → lecture, orientation, pas d'écriture
            "Je veux comprendre l'état du brain"

Work      → scope défini à l'avance, agent spécialisé, livrable attendu
            "Je veux finir cette feature aujourd'hui"

Pilote    → direction émergente, co-construction, documentation en temps réel
            "On construit quelque chose ensemble, on verra où ça mène"

Swarm     → autonome, humain ne voit que les blocages critiques
            "Lance et reviens me voir si ça bloque"
```

### Quand utiliser Pilote

- Sessions de fondation (nouvelles décisions architecturales)
- Brainstorm → décision → implémentation → documentation dans la même session
- Quand la direction n'est pas encore claire au démarrage
- Quand la croissance cognitive est l'objectif autant que le livrable

### Comportement brain en mode Pilote

```
1. Propose l'ordre logique des étapes — l'humain valide ou réoriente
2. Signale les forks avant de s'engager ("Option A ou B ?")
3. Documente en temps réel (ADR, wiki, vocabulary) — pas en fin de session
4. Parallélise les tâches indépendantes sans demander permission
5. Stoppe et remonte tout blocage ou décision irréversible
6. Maintient le cap sur l'objectif même si la conversation dérive
```

### Activation

```yaml
# CLAUDE.md
brain boot mode pilote
# → charge contexts/session-pilote.yml
# → contexte FULL, identityShow: on, write: all zones
```

---

## Conséquences

**Pour le brain owner :**
- Un nom et une sémantique pour le mode de travail le plus productif
- La session 2026-03-18 en est la preuve empirique de référence

**Pour brain-template :**
- Distribué avec `session-pilote.yml` dans contexts/
- Le premier utilisateur comprend immédiatement quelle session ouvrir
  pour co-construire son brain avec Claude

**Pour les swarms futurs :**
- Le mode Pilote est le prérequis naturel avant le swarm-ready gate :
  on valide en Pilote, on automatise en Swarm

---

## Hiérarchie des modes (complète)

```
Navigate  → orienter       (lecture, fenêtre légère)
Work      → livrer         (scope défini, agent spécialisé)
Pilote    → co-construire  (direction émergente, contexte maximal)
Swarm     → automatiser    (autonome, humain en superviseur)
```

---

## Références

- ADR-032 — Mode d'exécution vs workflow (mode 1/2/3)
- ADR-030 — Validation empirique boot modes
- Session 2026-03-18 — référence empirique mode Pilote
- `contexts/session-pilote.yml` — contexte à créer
