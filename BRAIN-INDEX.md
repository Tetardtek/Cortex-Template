# BRAIN-INDEX.md — Registre de claims

> Système de locking optimiste — Brain Session Index (BSI).
> **Claims** : scribe uniquement. **Signals** : orchestrator-scribe uniquement.
> Ne jamais éditer manuellement.
> Spec complète : `brain/profil/bsi-spec.md`

---

## Claims actifs

| Session | Instance | Portée | Niveau | Ouvert le | Expire le | État |
|---------|----------|--------|--------|-----------|-----------|------|
| — | — | — | — | — | — | — |

*Aucun claim actif.*

---

## Claims stale — contrôle humain requis

| Session | Instance | Portée | Expiré le | Action requise |
|---------|----------|--------|-----------|----------------|

*Aucun claim stale.*

---

## Signals — Bus inter-sessions

> Écrit par `orchestrator-scribe`. Lu par toutes les instances au démarrage.
> Un signal livré reste 24h pour audit, puis archivé.

| ID | De | Pour | Type | Concerné | Payload | État |
|----|----|------|------|----------|---------|------|
| — | — | — | — | — | — | — |

*Aucun signal en attente.*

**Types de signaux :**
- `READY_FOR_REVIEW` — instance A termine, demande review à instance B
- `REVIEWED` — review terminée, résultats dans `reviews/`
- `BLOCKED_ON` — instance A attend que instance B libère un scope
- `HANDOFF` — passage de main, instance B reprend depuis un point précis
- `CHECKPOINT` — snapshot mid-session (A→A), reprise après compactage ou coupure
- `INFO` — message sans action requise

---

## Historique — 30 derniers jours

| Session | Instance | Portée | Commits | Ouvert | Fermé | Statut |
|---------|----------|--------|---------|--------|-------|--------|

*Aucun historique.*

---

> **Règle watchdog :** au démarrage, le scribe scanne Claims + Signals.
> Claims TTL expiré → stale. Signals pending adressés à cette instance → alerter.
>
> **Format session ID :** `sess-YYYYMMDD-HHMM-<slug>`
> **Format signal ID :** `sig-YYYYMMDD-<seq>` (ex: `sig-20260314-001`)
> **Format instance :** `brain_name@machine` — ex: `prod@desktop`, `template-test@laptop`
