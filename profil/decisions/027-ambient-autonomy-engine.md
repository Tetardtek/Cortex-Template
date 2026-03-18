---
scope: kernel
name: ADR-027
title: "Ambient layer — autonomy engine : workflows, signals, human-as-escalation-only"
status: accepted
date: 2026-03-18
deciders: [<owner>]
---

# ADR-027 — Ambient layer : autonomy engine

## Vision fondatrice

> Le brain exécute. L'humain décide uniquement ce qui est vraiment indécidable.
> Sur le long terme, le brain connaît l'infra, les préférences, les patterns —
> il agit seul sur le routine. L'humain est décisionnaire final, pas opérateur.

---

## Ce que l'ambient layer est

Extension du daemon Python existant (`ambient/daemon.py`) —
même pattern prouvé (conditions YAML → actions → notify),
étendu au domaine agent workflows.

```
Aujourd'hui  :  identity/*.yml  → conditions → actions → notifie brain-ui
Demain       :  workflows/*.yml → signals IPC → spawn agents → RETURN → itère
```

L'ambient layer est un **event loop autonome** :
1. Évalue les workflow specs à chaque tick
2. Spawn les agents nécessaires (signal SPAWN, ADR-026)
3. Collecte les RETURN
4. Continue, ou ESCALATE si vraiment indécidable
5. Log tout pour la boucle d'apprentissage (ADR-028)

---

## Format workflow spec

```yaml
# workflows/deploy-batch.yml
workflow: deploy-batch
description: "Déployer N instances identiques"

for_each:
  items: [instance-01, instance-02, ..., instance-10]
  spawn: deploy
  scope:
    zone: project
    files: [vps/configs/{{item}}.yml]
  on_return:
    success: → next_item
    fail:    → ESCALATE pilote
    error:   → ERROR + log + ESCALATE pilote

on_complete:
  signal: RETURN
  to: orchestrator
  payload:
    result: "{{success_count}}/{{total}} instances déployées"

on_escalate:
  notify: [telegram, brain-ui]
  wait: human_decision
```

---

## Règle humain-as-escalation-only

```
routine   →  ambient exécute seul
ambigu    →  ESCALATE → humain décide → ambient reprend
bloquant  →  BLOCKED_ON → humain débloque → ambient reprend
```

L'humain ne voit jamais les étapes techniques. Il voit :
- Le résultat final (tout s'est bien passé)
- L'ESCALATE (une décision est requise)
- Le résumé de progression si il le demande

---

## Connexion au daemon existant

Le daemon `ambient/daemon.py` ajoute un evaluator :

```
TriggerEngine.tick()
  ├── _eval_frigo()     (existant — vie perso)
  ├── _eval_courses()   (existant — vie perso)
  ├── _eval_budget()    (existant — vie perso)
  └── _eval_workflows() (nouveau  — agent orchestration)
        ├── charge workflows/*.yml
        ├── évalue état courant
        ├── spawn agents via IPC (ADR-026)
        └── collecte RETURN → feed learning loop (ADR-028)
```

---

## Données collectées par workflow run

Chaque exécution produit un run record :

```yaml
run:
  workflow: deploy-batch
  started_at: ISO8601
  completed_at: ISO8601
  steps:
    - item: instance-01
      agent: deploy
      signal_out: SPAWN
      signal_in: RETURN
      result: success
      duration_ms: 1240
    - item: instance-02
      ...
  escalations: 0
  errors: 0
  outcome: success
```

Ces records alimentent directement ADR-028 (boucle d'apprentissage).

---

## Vision long terme

> Le brain connaît le VPS. Il connaît les préférences. Il connaît les patterns d'erreur.
> Avec le temps, les ESCALATEs deviennent rares — le brain a appris quoi faire
> dans chaque situation déjà rencontrée.

Chaque run = un exemple d'entraînement.
Chaque ESCALATE résolu = une règle apprise.
Chaque ERROR récurrente = un pattern à corriger.

---

## Ce que cet ADR ne définit pas

- Format exact des run records persistés → à préciser à l'implémentation
- Fréquence tick workflow vs tick identity (peut être différente) → config
- Boucle d'apprentissage complète → ADR-028

---

## Changelog

| Date | Note |
|------|------|
| 2026-03-18 | Création — autonomy engine, workflow spec format, human-as-escalation-only, extension daemon existant, run records pour learning loop |
