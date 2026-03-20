# Demarrer avec le brain

> Tu viens de forker. Voici tes 5 premieres minutes.

---

## Etape 1 — Installer

```bash
git clone <ton-fork> ~/Dev/Brain
cd ~/Dev/Brain
```

Si c'est une nouvelle machine, lance le setup complet :

```bash
bash scripts/brain-setup.sh prod ~/Dev/Brain
```

Ca clone les satellites (toolkit, progression, todo, reviews, profil), installe les hooks, et prepare CLAUDE.md.

---

## Etape 2 — Premier boot

Ouvre Claude Code dans le dossier du brain et tape :

```
brain boot
```

C'est tout. Le brain :
1. Lit ta config machine
2. Charge le minimum necessaire (~20% du contexte)
3. Te presente un briefing : etat du systeme, projets actifs, todos
4. Ouvre un claim BSI (trace de session)
5. Te demande ce que tu veux faire

---

## Etape 3 — Travailler

**Tu veux coder sur un projet :**

```
brain boot mode work/mon-projet
```

Le brain charge les agents pertinents (debug, scribe, todo-scribe) et le fichier projet si il existe.

**Tu veux explorer ou reflechir :**

```
brain boot mode brainstorm/sujet
```

Mode libre, pas de livrable attendu. L'agent `brainstorm` challenge tes idees.

**Tu ne sais pas quoi faire :**

```
brain boot
```

Le briefing te montre tes todos, tes projets actifs, et te pose la question. Reponds naturellement — le brain detecte le type de session.

---

## Etape 4 — Fermer proprement

Quand tu as fini :

```
on wrappe
```

Le brain lance la sequence de fermeture :
- Capture les metriques de ta session
- Met a jour tes todos
- Ferme le claim BSI

Ne ferme pas le terminal avant que le claim soit ferme.

---

## Les commandes essentielles

**Boot**
- `brain boot` — demarrage standard
- `brain boot mode <type>` — choisir son mode (work, debug, brainstorm, brain...)
- `brain boot navigate` — mode lecture seule, le plus leger

**En session**
- `Charge l'agent <nom>` — invoquer un agent specifique
- `/btw <question>` — parenthese rapide sans casser le fil
- `checkpoint` — sauvegarder l'etat avant une pause

**Fermeture**
- `on wrappe` ou `fin` — fermeture propre avec metriques

---

## Les 3 choses a savoir

**1. Le brain charge le minimum.** Il ne lit pas tout au demarrage. Il charge ~20-30% du contexte selon ta session et ajoute le reste a la demande. C'est pour ca qu'il demarre vite.

**2. Les agents se chargent tout seuls.** Tu parles de "bug" → l'agent `debug` arrive. Tu dis "deploy" → `vps` + `ci-cd` se chargent. Tu n'as pas besoin de tout connaitre — le brain route.

**3. Les secrets ne passent jamais dans le chat.** Le `secrets-guardian` surveille en permanence. Si un secret apparait accidentellement, la session se suspend. C'est normal — c'est une protection.

---

## Bonus — le dashboard

Le brain a un dashboard web avec tes docs, tes workflows, et une visualisation 3D de ton corpus.

```bash
# Build le dashboard (une seule fois)
bash brain-ui/build.sh

# Lance brain-engine (sert aussi le dashboard)
bash brain-engine/start.sh

# Ouvre dans ton navigateur
# http://localhost:7700/ui/
```

---

## Et apres ?

- **Voir ce que tu as** → Vue d'ensemble (Agents & Tiers) dans la sidebar
- **Comprendre les sessions** → Sessions dans la sidebar
- **Voir les recettes d'agents** → Workflows dans la sidebar
- **Comprendre l'architecture** → Architecture dans la sidebar
