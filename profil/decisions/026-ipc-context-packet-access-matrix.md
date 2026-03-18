---
scope: kernel
name: ADR-026
title: "IPC — Context packet, signal vocabulary, access matrix inter-agents"
status: accepted
date: 2026-03-18
deciders: [<owner>]
---

# ADR-026 — IPC : context packet + signal vocabulary + access matrix

## Insight fondateur

> Le `×` de la formule Cosmos ne définit pas seulement le FORMAT de ce qui voyage —
> il définit **ce que chaque agent a le DROIT de recevoir selon le signal reçu**.

Le G du modèle PCG se précise ici :

```
P = comment l'agent se comporte internally
C = ce qu'il charge au boot (session-*.yml)
G = ce qu'il peut recevoir et émettre via × (access matrix)
```

Le Gate n'est pas seulement "quel tier débloque cet agent" —
c'est **le périmètre exact de sa communication inter-agents**.

---

## Le context packet — format kernel (invariant)

```yaml
packet:
  from:       agent_name              # qui émet
  to:         agent_name | broadcast  # destinataire
  signal:     SPAWN | RETURN | BLOCKED_ON | CHECKPOINT | HANDOFF | ESCALATE | ERROR
  scope:
    files:    []                      # fichiers concernés (chemins exacts)
    zone:     kernel | project | personal  # zone BSI
  payload:
    context:  {}                      # ce que l'émetteur a découvert
    decision: null                    # décision prise (si applicable)
    options:  []                      # options proposées (ESCALATE uniquement)
    result:   null                    # résultat retourné (RETURN uniquement)
  return_to:  agent_name              # où renvoyer
  session_id: string                  # claim BSI actif
```

**Règle d'or** : chaque signal ne remplit qu'un sous-ensemble du payload.
Un agent ne reçoit jamais plus que ce que son signal autorise.

---

## Signal vocabulary — complet et exhaustif

| Signal | Sens | Payload autorisé | Existait |
|--------|------|-----------------|---------|
| `SPAWN` | parent → enfant : démarre une tâche | scope + context initial | implicite ✗ |
| `RETURN` | enfant → parent : tâche terminée | result uniquement | implicite ✗ |
| `CHECKPOINT` | agent → BSI : état sauvegardé | context snapshot | ✓ |
| `HANDOFF` | session N → session N+1 : passage de relai | context + decision | ✓ |
| `BLOCKED_ON` | agent → pilote : bloqué techniquement | description blocage | ✓ |
| `ESCALATE` | agent → pilote : décision humaine requise | options de décision | ✗ nouveau |
| `ERROR` | agent → parent : échec non récupérable | error description | ✗ nouveau |

**Distinction BLOCKED_ON vs ESCALATE :**
- `BLOCKED_ON` = bloqué techniquement (fichier absent, permission manquante) → attente déblocage
- `ESCALATE` = ambiguïté de valeur (choix architectural, décision métier) → humain décide

---

## Access matrix — qui reçoit quoi

| Agent | Reçoit de | Envoie à | Zones autorisées | Signals autorisés |
|-------|-----------|----------|-----------------|-------------------|
| `orchestrator` | human, tout agent | tout agent | toutes | tous |
| `debug` | orchestrator, human | orchestrator | project + scope-only | SPAWN, RETURN, BLOCKED_ON |
| `security` | orchestrator, code-review | orchestrator | project | SPAWN, RETURN, ESCALATE |
| `coach` | human | human | personal + reference | ESCALATE, CHECKPOINT |
| `scribe` | orchestrator, human | orchestrator | selon scope déclaré | SPAWN, RETURN |
| `audit` | human | human | kernel (lecture) | RETURN, ESCALATE |

> Cette matrice est **extensible** — chaque agent déclare son access profile dans son frontmatter.
> Elle est **vérifiable** — l'opérateur × rejette tout packet qui viole la matrice.

---

## Signal → payload autorisé

Le signal contraint ce qui peut être packagé. Aucune exception.

```
SPAWN     →  scope.files + scope.zone + payload.context
RETURN    →  payload.result uniquement  (jamais le contexte source)
BLOCKED_ON → payload.context (description blocage)
ESCALATE  →  payload.options (liste de choix, pas de contexte complet)
ERROR     →  payload.context (erreur uniquement)
CHECKPOINT → payload.context (snapshot complet, vers BSI uniquement)
HANDOFF   →  payload.context + payload.decision (vers session suivante uniquement)
```

**Pourquoi RETURN ne passe pas le contexte source :**
Évite les fuites — un agent enfant ne peut pas "rapporter" ce qu'il a vu
dans une zone hors de son scope de départ.

---

## Frontmatter agent — extension PCG

Chaque agent déclare son Gate IPC dans son frontmatter :

```yaml
brain:
  # ... champs existants ...
  ipc:
    receives_from: [orchestrator, human]   # qui peut lui SPAWN
    sends_to:      [orchestrator]          # à qui il peut RETURN/ESCALATE
    zone_access:   [project]              # zones autorisées en lecture
    signals:       [SPAWN, RETURN, BLOCKED_ON]  # signals qu'il émet
```

---

## Deux faces de ×

```
×  =  context packet + signal vocabulary    ← kernel, invariant (cet ADR)
   +  routing table                         ← instance, configurable Cosmos
```

La routing table (qui parle à qui dans une instance donnée) est éditée via Cosmos UI.
Elle ne peut pas violer la access matrix du kernel — elle l'instancie.

---

## Ce que cet ADR ne définit pas

- Routing table format (`profil/routing.yml`) → à créer par instance
- Cosmos UI agent graph → produit
- Ambient layer signals → ADR-027

---

## Changelog

| Date | Note |
|------|------|
| 2026-03-18 | Création — context packet, signal vocabulary complet (ESCALATE + ERROR nouveaux), access matrix, PCG Gate précisé, frontmatter agent extension |
