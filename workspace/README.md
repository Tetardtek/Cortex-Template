# workspace/

> Espace de travail temporaire — brouillons, logs de session, feedback.

Utilise par les agents pendant une session pour poser du contenu intermediaire :

```
workspace/
  ram.md        <- memoire volatile de session (efface au close)
  log.md        <- journal de session
  feedback.md   <- notes pour le coach
```

Ce dossier est **local** — apres la declaration d'ownership, il sera gitignore.
Rien ici n'est versionne — c'est du scratch pad.
