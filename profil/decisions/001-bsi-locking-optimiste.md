# ADR-001 — Locking optimiste BSI — claims + TTL vs mutex strict

> Date : 2026-03-14
> Statut : actif
> Décidé par : session brain sess-20260314-1810-brain

## Contexte

Plusieurs sessions Claude en parallèle peuvent modifier les mêmes fichiers brain sans se voir. Un mutex strict (une seule session à la fois) bloque le workflow multi-agent.

## Décision

Locking optimiste via `BRAIN-INDEX.md` — chaque session déclare un claim avec TTL. On ne bloque pas, on déclare. Le watchdog détecte les conflits et alerte. L'humain décide.

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Mutex strict (une session) | Bloque le dual-agent et le pattern supervisor |
| Pas de locking | Collisions silencieuses sur focus.md, projets/ |
| Branches git par session | Overhead de merge, perd le temps réel |

## Conséquences

**Positives :** multi-sessions en parallèle, pattern supervisor possible, brain-watch détecte les stales automatiquement.

**Négatives / trade-offs :** un conflit rare peut passer si les deux sessions commitent avant que le watchdog notifie. Accepté — le brain est un système coopératif, pas adversarial.

## Références

- `profil/bsi-spec.md`
- `BRAIN-INDEX.md`
- `agents/orchestrator-scribe.md`
