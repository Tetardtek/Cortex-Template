# Les satellites — tes repos dans le brain

> Pourquoi le brain a des sous-dossiers qui sont des repos Git separés.

---

## C'est quoi un satellite ?

Le brain a un **kernel** (le repo principal) et des **satellites** (des repos Git independants qui vivent dans des sous-dossiers).

```
~/Dev/Brain/              ← kernel (repo principal)
  agents/                 ← dans le kernel
  profil/                 ← dans le kernel
  todo/                   ← SATELLITE (son propre repo Git)
  toolkit/                ← SATELLITE (son propre repo Git)
  progression/            ← SATELLITE (son propre repo Git)
  reviews/                ← SATELLITE (son propre repo Git)
```

Chaque satellite a sa propre histoire Git, ses propres commits, ses propres branches. Le kernel les ignore (`.gitignore`).

---

## Pourquoi ne pas tout mettre dans un seul repo ?

**Isolation.** Tes todos n'ont pas besoin d'etre dans le meme historique que tes agents. Ta progression est privee — elle ne doit pas etre dans le template distribue. Ton toolkit peut etre partage independamment.

**Permissions.** Le kernel est protege (confirmation humaine). Les satellites sont libres — les scribes ecrivent dedans sans gate.

**Distribution.** Quand tu forkes le brain-template, tu recois le kernel propre. Tes satellites sont a toi — tu les crées.

---

## Les 4 satellites

### todo/ — tes intentions

Ce que tu veux faire, ce qui reste a faire, ce qui est planifie.

```
todo/
  README.md       ← index des fichiers actifs
  brain.md        ← todos du brain lui-meme
  <projet>.md     ← todos par projet
```

Ecrit par : `todo-scribe` en fin de session.

### toolkit/ — tes patterns valides

Les patterns, templates, et snippets que tu as valides en prod. Reutilisables d'une session a l'autre.

```
toolkit/
  _template.md    ← template de pattern
  docker/         ← patterns Docker
  apache/         ← templates vhost
  github-actions/ ← pipelines CI/CD
```

Ecrit par : `toolkit-scribe` quand un pattern est valide.

### progression/ — ton parcours

Ta progression, tes skills, ton metabolisme de sessions. Le coach ecrit ici.

```
progression/
  README.md           ← niveau actuel + objectifs
  metabolism/         ← metriques de chaque session
  skills/             ← competences par domaine
  journal/            ← observations de session
```

Ecrit par : `metabolism-scribe`, `coach-scribe`.

### reviews/ — tes audits d'agents

Les audits faits par `agent-review` — comment chaque agent performe en conditions reelles.

```
reviews/
  _template.md    ← template de review
  <Projet>/       ← reviews par projet
```

Ecrit par : `agent-review`.

---

## Comment les creer

### Option 1 — Dossiers locaux (le plus simple)

Le `setup.sh` cree les dossiers automatiquement au premier lancement. Ils fonctionnent comme des dossiers normaux. Pas de repo Git separe.

C'est suffisant pour commencer. Tu peux les versionner plus tard.

### Option 2 — Repos Git separes (recommande a terme)

Si tu veux versionner chaque satellite independamment :

```bash
# Creer un repo pour todo/
cd ~/Dev/Brain/todo
git init
git add .
git commit -m "init: todo satellite"
# Optionnel : push vers ton Gitea/GitHub
git remote add origin <URL_DU_REPO>
git push -u origin main
```

Repete pour chaque satellite (toolkit/, progression/, reviews/).

> Le `.gitignore` du kernel ignore deja ces dossiers — pas de conflit.

### Option 3 — Cloner des satellites existants

Si tu reprends un brain existant ou tu veux partir d'un satellite pre-rempli :

```bash
git clone <URL> ~/Dev/Brain/todo
git clone <URL> ~/Dev/Brain/toolkit
git clone <URL> ~/Dev/Brain/progression
git clone <URL> ~/Dev/Brain/reviews
```

---

## Ce qui se passe si un satellite est absent

**Rien ne casse.** Le brain fonctionne sans satellites. Le briefing signale ce qui manque :

```
⚠️ Alertes
  - progression/ satellite non clone
  - todo/ satellite non clone
```

C'est informatif, pas bloquant. Les scribes ne peuvent juste pas ecrire dans des dossiers qui n'existent pas.

---

## Regle d'or

> Le kernel ne depend jamais des satellites. Les satellites dependent du kernel.
> Un satellite peut etre supprime et recree sans impact sur le brain.
> Le kernel, lui, est sacre.
