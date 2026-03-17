---
name: 021-scope-drift-guardrails-session-permissions
type: decision
context_tier: warm
status: actif
---

# ADR-021 — Guardrails de scope : permissions implicites par type de session

> Date : 2026-03-17
> Statut : actif
> Décidé par : brainstorm navigate + coach (session 2026-03-17 ~22h)

---

## Contexte

### Le diagnostic

Le brain est une solution à un problème d'interface fondamental :
**Claude n'a pas de mémoire persistante native, et aucun mécanisme natif n'empêche le scope drift.**

Sans guardrails, chaque session fait ce qu'elle veut :
- `brain.md` grossit à chaque session (83k chars atteints) parce que rien ne discipline les writes
- Une session-work charge du contexte navigate par accident
- Un agent répond sur un domaine hors de son scope parce que rien ne le bloque
- L'humain porte seul la discipline de scope — et c'est insoutenable

### Le pattern identifié

Toute l'architecture brain (L0/L1/L2, session-*.yml, modes/, BSI) est une tentative de **compenser l'absence de guardrails natifs** entre l'humain, Claude, et le contexte chargé.

Les fichiers allègent la charge contextuelle. Mais ils ne font pas respecter le scope.

### La friction comme signal

Quand une solution augmente la friction humaine (ex : "pense à lancer le script après la session"), c'est un signal que le guardrail est au mauvais endroit. Un guardrail qui demande à l'humain de se souvenir — c'est une convention fragile, pas un guardrail.

### Les deux niveaux manquants

| Niveau | Ce qu'on a | Ce qui manque |
|---|---|---|
| **Contextuel** | session-*.yml, L0/L1/L2, audits | header auto-dérivé (brain-todo-header) |
| **Comportemental** | modes/brain-navigate.md (soft lock) | permissions implicites par type → settings.json |

---

## Décision

**Les permissions d'une session Claude sont déterminées par son type déclaré au boot — pas par la bonne volonté de l'humain ou de Claude.**

Deux nouvelles sessions en priorité absolue :

### `session-edit-brain` — sudo brain
- Accès complet en écriture sur tout le brain
- Chargée explicitement quand l'humain veut modifier la structure du brain lui-même
- Toutes les actions brain autorisées sans confirmation supplémentaire
- Scope : brain meta-work (agents, ADRs, sessions, kernel)
- Permissions settings.json : writes brain/* autorisés

### `session-kernel` — lecture seule kernel
- Interdit toute modification des fichiers identifiés comme kernel
- Kernel = PATHS.md, KERNEL.md, CLAUDE.md, brain-compose*.yml, agents/coach*.md
- Toute tentative de write kernel → refus explicite + redirection vers session-edit-brain
- Protège l'identité cognitive du brain contre la dérive accidentelle

---

## Principe directeur

> **Le type de session = contrat de permissions, pas une déclaration d'intention.**

Ce n'est pas "dans cette session on essaie de ne pas modifier le kernel". C'est "dans cette session, modifier le kernel est techniquement impossible sans escalade explicite".

La discipline ne doit pas reposer sur la mémoire de l'humain ou la bonne volonté de Claude — elle doit être dans la configuration.

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Soft lock comportemental seul (ADR-019) | Insuffisant — Claude peut "oublier" en session longue ou post-compaction |
| Convention documentée | Fragile — repose sur la discipline humaine |
| Confirmation à chaque action sensible | Trop de friction — inverse du problème |

---

## Conséquences

**Positives :**
- Scope drift impossible par construction pour les sessions typées
- L'humain n'a plus à porter la discipline de scope dans sa tête
- Les sessions deviennent des contrats exécutables, pas des intentions
- brain.md et le kernel ne peuvent pas grossir accidentellement hors session-edit-brain

**Négatives / trade-offs assumés :**
- Requiert un audit granulaire L0/L1 pour que chaque session-*.yml soit précis (déjà PRIORITÉ 1)
- La configuration settings.json devient un artefact critique à maintenir
- session-edit-brain = session à ouvrir explicitement → légère friction intentionnelle (c'est le point)

---

## Livrable immédiat

1. `profil/contexts/session-edit-brain.yml` — L0/L1 write-all brain
2. `profil/contexts/session-kernel.yml` — L0/L1 read-only kernel + soft lock write
3. Audit kernel : identifier les fichiers protégés (liste dans KERNEL.md)
4. Lier audit granulaire L0/L1 (PRIORITÉ 1) à la définition des permissions par session

---

## Références

- Sessions où la décision a émergé : navigate 2026-03-17 ~22h
- ADR-019 — session modes soft lock (précurseur comportemental)
- ADR-020 — presence layer live-states
- `todo/brain.md` — PRIORITÉ 1 audit granulaire
- `profil/contexts/session-navigate.yml` — premier exemple de session avec soft lock
- `modes/brain-navigate.md` — soft lock comportemental existant
