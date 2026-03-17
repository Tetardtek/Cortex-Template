---
name: ADR-020-presence-layer-live-states
type: decision
context_tier: cold
---

# ADR-020 — Presence layer : live-states.md comme registre inter-sessions

> Date : 2026-03-17
> Statut : actif
> Décidé par : brainstorm session sess-20260317-1329-boot

---

## Contexte

Sans visibilité inter-sessions, l'humain porte manuellement l'état de toutes les sessions parallèles. Il sait qui travaille sur quoi, qui est bloqué, qui attend une décision. C'est épuisant et ça force la sérialisation de ce qui pourrait être parallèle.

BSI existe mais gouverne les fichiers, pas l'état des sessions Claude. Les signaux BSI sont lents (file-based, asynchrones). Il manque un layer de présence temps-réel queryable depuis n'importe quelle session.

---

## Décision

Un fichier unique `workspace/live-states.md` sert de registre de présence inter-sessions. Chaque session écrit son état à l'open et le met à jour au close. La session navigate le lit pour avoir une vue d'ensemble sans lire les contextes individuels.

**Clé unique :** `sess_id` (BSI claim ID) — jamais le nom du projet.
**8 champs :** `sess_id`, `project`, `doing`, `status`, `needs`, `priority`, `team`, `blocking`, `context`, `updated`
**Remplissage :** session-orchestrator steps 6.5 (open) + 7 (close)
**Lecture :** session navigate, session-orchestrator, brain-state-bot (futur)

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Signaux BSI pour la présence | BSI = gouvernance fichiers. Présence = état sessions. Périmètres distincts |
| Entrée par `project` comme clé | Collision si plusieurs sessions sur le même projet |
| Intégré dans BRAIN-INDEX.md | BRAIN-INDEX = claims BSI. Mélanger présence et gouvernance = drift |

---

## Tiers d'automatisation (brain-state-bot)

| Tier | Remplissage | Champs auto-dérivés |
|------|-------------|-------------------|
| `free` | Manuel (session ou humain) | `sess_id`, `project`, `updated` depuis claims BSI |
| `pro` | Bot bash (cron 10min) | + `blocking[]`, `team[]`, `priority:critical` |
| `owner` | phi-3-mini enrichi | + `context` synthétisé, détection blockers implicites, alertes navigate |

---

## Conséquences

**Positives :**
- L'humain ne porte plus l'état dans sa tête
- Navigate lit 20 lignes au lieu de 5 contextes — ~90% de réduction token
- Workflow sans humain possible : session-orchestrator lit `needs`, route vers navigate ou agent
- Distributable dans le brain-template (fichier vide + spec)

**Négatives / trade-offs assumés :**
- `needs` ne peut pas être dérivé automatiquement — toujours écrit par la session
- En tier free, le bot n'existe pas — remplissage manuel ou par session-orchestrator uniquement
- Stale si session-orchestrator ne tourne pas correctement au close

---

## À construire

- `brain-state-bot` — spec dédiée (étape 5)
- Stale detection : `updated` > 2h + `status: progressing` → bot passe à `idle`
- Archive : `status: closed` + 24h → `workspace/live-states-archive/`

---

## Références

- Fichiers : `workspace/live-states.md`, `wiki/live-states.md`, `agents/session-orchestrator.md`
- Sessions : `sess-20260317-1329-boot`
- ADR lié : ADR-019 (session modes — orthogonal, même session)
