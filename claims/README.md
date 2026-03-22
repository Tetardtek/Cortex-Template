# claims/

> Sessions BSI actives — un fichier par session ouverte.

Chaque `brain boot` ouvre un claim ici via `scripts/bsi-claim.sh`.
Le claim trace : qui travaille sur quoi, depuis quand, et expire apres 4h.

```
claims/
  sess-20260322-1200-navigate.yml   <- session active
  sess-20260322-1400-work.yml       <- autre session
```

Ce dossier est **local** — apres la declaration d'ownership, il sera gitignore.
Les claims vivent dans `brain.db` (source de verite) et ici en fichiers (fallback).
