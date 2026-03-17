---
name: ADR-019-session-modes-soft-lock
type: decision
context_tier: cold
---

# ADR-019 — Session modes : soft lock comportemental par déclaration au boot

> Date : 2026-03-17
> Statut : actif
> Décidé par : brainstorm session sess-20260317-1329-boot

---

## Contexte

Sans mécanisme de mode, une session Claude dérive naturellement vers l'exécution technique même quand elle devrait rester en navigation/coaching. Le contexte se pollue, la présence coach se dilue, et c'est l'humain qui porte la charge de garder le cap.

Trois alternatives ont été évaluées : mode dans le memory-global (permanent), mode dans les claims BSI (inter-sessions), mode déclaré à la session.

---

## Décision

Les modes sont déclarés au démarrage d'une session Claude via un mot-clé, chargent un fichier `modes/<nom>.md`, et constituent un **soft lock** : Claude refuse d'exécuter ce qui dépasse le périmètre du mode et redirige vers une session dédiée.

**Déclaration :** mot-clé dans le premier message (`brain +navigate`, `brain +kernel`, etc.)
**Fichiers :** `Brain/modes/<nom>.md` — chargés au boot si le mot-clé est détecté par helloWorld
**Enforcement :** soft — Claude dit "ouvre une autre session pour ça", il n'exécute pas
**Périmètre :** intra-session uniquement — pas de visibilité cross-sessions

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Mode dans `memory-global/` | Permanent = toujours actif. Un mode est ponctuel, pas identitaire |
| Mode dans claims BSI | BSI = gouvernance fichiers. Ne gère pas le comportement Claude. Mauvais périmètre |
| Mode dans `~/.claude/session-role/` | Local machine, non tracké, pas distributable avec le brain |

---

## Conséquences

**Positives :**
- Contexte préservé — pas de pollution par des tâches hors périmètre
- Présence coach maintenue sur la durée
- Livrable immédiatement — pas de dépendance BSI
- Distributable avec le brain-template

**Négatives / trade-offs assumés :**
- Soft lock uniquement — repose sur la discipline Claude, pas un mécanisme dur
- Pas de visibilité cross-sessions (hard lock = futur, attend évolution BSI)
- Nécessite que helloWorld détecte le mot-clé et charge le bon fichier mode

---

## À construire

- `Brain/modes/` — répertoire des modes
- `Brain/modes/brain-navigate.md` — premier mode à forger
- Modification de `agents/helloWorld.md` — détection mot-clé + chargement mode
- `brain-template/modes/` — mode example dans le template

---

## Références

- Fichiers concernés : `Brain/modes/` (à créer), `agents/helloWorld.md`, `memory-global/coach_presence.md`
- Sessions : `sess-20260317-1329-boot`
- Lexique : `profil/lexique.md` — distinction type de session / mode
