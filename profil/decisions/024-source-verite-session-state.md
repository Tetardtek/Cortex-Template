---
name: 024-source-verite-session-state
type: decision
context_tier: warm
status: actif
---

# ADR-024 — Source de vérité session state

> Date : 2026-03-17
> Statut : actif
> Décidé par : brainstorm navigate + coach (session 2026-03-17 ~23h)

---

## Décision

Trois systèmes coexistent — scopes distincts, aucun doublon.

| Système | Scope | Analogie | Source de vérité pour |
|---------|-------|----------|-----------------------|
| `claims/*.yml` | Historique | git log | "Quelles sessions ont existé ?" — audit trail, gouvernance |
| `workspace/now.md` | Contexte bridge | Sticky note | "Qu'est-ce que la prochaine session doit savoir ?" |
| `workspace/live-states.md` | Présence live | Tableau blanc | "Qu'est-ce qui tourne EN CE MOMENT ?" |

---

## Priorité de lecture au boot

```
1. now.md          → toujours présent, toujours frais — prioritaire
2. live-states.md  → si brain-state-bot actif (tier pro+)
3. BSI claims      → gouvernance uniquement, jamais contexte boot
```

---

## Règle d'écriture

- `now.md` : écrit par Claude à chaque fermeture de session — écrase le précédent
- `live-states.md` : écrit par session-orchestrator (open/close) + brain-state-bot
- `claims/*.yml` : écrit une fois à l'open, fermé au close — jamais modifié après

---

## Conséquence

BSI claims n'est plus la source de vérité contextuelle au boot.
`now.md` prend ce rôle. Claims = audit, pas contexte.

---

## Références

- ADR-016 (now.md push garanti)
- ADR-020 (live-states présence layer)
- ADR-001 (BSI locking optimiste — gouvernance)
