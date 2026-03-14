# BRAIN-INDEX.md — Registre de claims

> Système de locking optimiste — Brain Session Index (BSI).
> Mis à jour par le **scribe uniquement**. Ne jamais éditer manuellement.
> Spec complète : `brain/profil/bsi-spec.md`

---

## Claims actifs

| Session | Portée | Niveau | Ouvert le | Expire le | État |
|---------|--------|--------|-----------|-----------|------|
| — | — | — | — | — | — |

*Aucun claim actif.*

---

## Claims stale — contrôle humain requis

| Session | Portée | Expiré le | Action requise |
|---------|--------|-----------|----------------|

*Aucun claim stale.*

---

## Historique — 30 derniers jours

| Session | Portée | Ouvert | Fermé | Statut |
|---------|--------|--------|-------|--------|

*Aucun historique.*

---

> **Règle watchdog :** au démarrage de chaque session brain, le scribe scanne ce fichier.
> TTL expiré → déplacer vers "Claims stale". Jamais auto-release — contrôle humain toujours.
