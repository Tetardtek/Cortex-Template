# ADR-002 — Session-as-identity — slug IS le rôle

> Date : 2026-03-14
> Statut : actif
> Décidé par : session brain

## Contexte

Pour faire travailler plusieurs rôles en parallèle (build, review, test), l'option naïve est de forker un brain par rôle. Explosion de configurations, de syncs, de dérive.

## Décision

Le slug de session IS l'identité de routage. Un seul brain par machine. N sessions nommées. `sess-20260314-0900-build@desktop` = rôle build. `orchestrator-scribe` route les signaux par `sess-id@machine`.

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Un brain par rôle | Explosion configs, sync impossible |
| Tags git par rôle | Pas de communication inter-session |

## Conséquences

**Positives :** un seul brain à maintenir, N rôles simultanés, signaux inter-sessions via BSI.

**Négatives :** le slug doit être discipliné — un slug générique (`-brain`) perd le contexte du rôle.

## Références

- `profil/bsi-spec.md ## session-as-identity`
- `BRAIN-INDEX.md ## Claims`
