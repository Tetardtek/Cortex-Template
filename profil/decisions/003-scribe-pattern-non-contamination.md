# ADR-003 — Scribe Pattern — non-contamination, un scribe = un territoire

> Date : 2026-03-14
> Statut : actif
> Décidé par : session brain

## Contexte

Sans règle d'écriture, chaque agent modifie ce qu'il veut. Résultat : focus.md écrasé par un agent vps, todo/ pollué par un agent debug. Dérive garantie sur 10 sessions.

## Décision

Un agent métier ne commit jamais directement dans le brain. Il signal → le scribe compétent écrit → dans sa zone uniquement. 8 scribes, 8 territoires exclusifs.

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Chaque agent écrit où il veut | Dérive immédiate, historique illisible |
| Un seul scribe global | Goulot d'étranglement, perd la granularité |

## Conséquences

**Positives :** historique git lisible par scribe, responsabilité claire, zero dérive entre zones.

**Négatives :** friction légère — un agent doit "signaler" plutôt qu'écrire directement. Accepté.

## Références

- `profil/scribe-system.md`
- `profil/architecture.md ## Le Scribe Pattern`
- `KERNEL.md ## Commit types`
