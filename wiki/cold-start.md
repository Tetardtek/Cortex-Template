# Cold Start — Brain Run

> Nouveau cerveau. Nouvelle machine. Prêt en 5 minutes.

---

## TL;DR

```bash
git clone git@git.tetardtek.com:Tetardtek/brain.git ~/Dev/Brain
bash ~/Dev/Brain/scripts/brain-setup.sh prod ~/Dev/Brain
```

C'est tout. Le script fait le reste.

---

## Ce que fait `brain run`

```
brain-setup.sh <brain_name> <brain_root>
       │
       ├── ✅ Vérifie la clé SSH Gitea
       ├── ✅ Clone les 6 satellites
       │     profil/ · todo/ · toolkit/ · progression/ · reviews/ · wiki/
       ├── ✅ Configure ~/.claude/CLAUDE.md
       ├── ✅ Crée brain-compose.local.yml
       ├── ✅ Vérifie MYSECRETS (warning si absent)
       └── ✅ Locke le kernel en readonly (si machine laptop)
```

Après le script, une seule chose à faire manuellement : créer `MYSECRETS`.

---

## MYSECRETS — le seul fichier manuel

```bash
# ~/Dev/BrainSecrets/MYSECRETS — jamais commité, jamais affiché
BRAIN_TELEGRAM_TOKEN=...
BRAIN_TELEGRAM_CHAT_ID=...
SUPER_OAUTH_DISCORD_CLIENT_SECRET=...
SUPER_OAUTH_GITHUB_CLIENT_SECRET=...
SUPER_OAUTH_GOOGLE_CLIENT_SECRET=...
SUPER_OAUTH_TWITCH_CLIENT_SECRET=...
```

Structure complète : voir `MYSECRETS.example` dans le repo.

---

## Machines reconnues

| Machine | brain_name | Peut pusher |
|---------|------------|-------------|
| Desktop (principal) | `prod` | kernel + satellites |
| Laptop | `prod-laptop` | satellites seulement |
| VPS | — | brain-bot seulement |

> Le kernel brain ne se push **que** depuis le desktop principal.
> Le laptop peut pull, lire, et pusher ses propres satellites (todo, progression...).

---

## Première session après install

```
Bon jour !
```

helloWorld démarre, lit le contexte, ouvre le claim BSI, et présente l'état des projets.
Si c'est vraiment la première fois : ratio = 0, backlog = vide → le coach le détectera.

---

## Rotation secrets OAuth (si nécessaire)

```bash
# Après avoir rempli MYSECRETS avec les nouveaux secrets :
bash ~/Dev/Brain/scripts/archive/rotate-oauth-secrets.sh
```

Injecte les 4 secrets sur le VPS et redémarre SuperOAuth.
> Script archivé — vérifier s'il est toujours applicable avant de l'utiliser.

---

## Warm restart vs cold start

| | Cold start | Warm restart |
|---|---|---|
| Contexte | Bootstrap complet 5 fichiers | 1 fichier checkpoint.md |
| Durée | 2-3 min | < 30 sec |
| Quand | Nouvelle machine, ou pas de checkpoint | `/checkpoint` fait avant |
| Commande | Boot normal | `Lis brain/workspace/<sprint>/checkpoint.md et reprends` |

---

## Troubleshooting

**SSH refused** → clé SSH pas ajoutée dans Gitea (Settings → SSH Keys → Add Key)

**MYSECRETS manquant** → secrets-guardian avertit au boot, pas bloquant pour le dev local

**Satellites pas clonés** → relancer `brain-setup.sh` (idempotent)

**Laptop veut pusher le kernel** → normal, le remote est locké en `no_push` — pusher depuis le desktop
