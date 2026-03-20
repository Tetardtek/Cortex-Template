# Agents Brain & Systeme

> Les agents qui font vivre le brain — documentation, coaching, orchestration, protection.

---

## Coach — ta progression

### coach

> 🟢 **free** : `coach-boot` (observation legere)
> 🔵 **featured+** : `coach` complet (mentorat, bilans, objectifs)

Le coach est toujours present. Ce qui change selon ton tier :

> 🟢 **free** — Observe en silence. Intervient uniquement sur un risque critique.

> 🔵 **featured** — Bilans de session, objectifs SMART, progression tracee.

> 🟠 **pro** — Idem + contexte projet (review code, patterns, architecture).

> 🟣 **full** — Mentorat long terme — anticipe, challenge les decisions, milestones.

Le coach adapte aussi son comportement au type de session :

- **Silencieux** (navigate, deploy, infra, urgence, audit) — pas de rapport, risque critique uniquement
- **Standard** (work, debug) — actif sur les patterns d'erreur
- **Engage** (brain, brainstorm) — challenge les decisions
- **Complet** (coach, capital) — mentorat structure
- **Copilote** (pilote) — proactif, anticipe

---

## Scribes — la memoire

Les scribes ecrivent pour que rien ne se perde. Chacun a son territoire :

### scribe

> 🟢 **free**

Gardien principal du brain. Met a jour `focus.md`, les fiches projets, l'index des agents. Detecte ce qui est obsolete et le signale.

S'active en fin de session significative (commits, agents forges, decisions prises).

---

### todo-scribe

> 🟢 **free**

Ecrit dans `brain/todo/`. Capture les intentions non realisees, les taches a planifier. Ne priorise pas — il structure et persiste.

---

### metabolism-scribe

> 🟢 **free**

Mesure la sante de chaque session : tokens, duree, commits, context peak. Calcule le `health_score` et le ratio use-brain/build-brain sur 7 jours.

Il ne juge pas — il mesure. Les tendances parlent d'elles-memes.

---

### wiki-scribe

> 🟢 **free**

Maintient la documentation du brain sur deux territoires :
- `wiki/` — reference technique (agents, matrices, specs)
- `docs/` — guides humains (ce que tu lis maintenant)

Route automatiquement : "lisible sans contexte brain ?" → docs, sinon → wiki.

---

### coach-scribe

> 🔵 **featured**

Persiste la progression dans `progression/` : journal de session, competences, milestones. Separe du coach — le coach observe, le scribe ecrit.

---

### toolkit-scribe

> 🟠 **pro**

Capture les patterns valides en prod dans `toolkit/`. Chaque pattern reussi en session devient un template reutilisable.

---

## Orchestration — le systeme nerveux

### helloWorld

> 🟢 **free**

Le majordome. Premier agent au reveil : lit l'etat du systeme, produit le briefing, ouvre le claim BSI, passe la main a session-orchestrator.

---

### session-orchestrator

> 🟢 **free**

Proprietaire du cycle de vie. Decide ce qui est charge au boot, route le travail, declenche les scribes a la fermeture. Ne produit rien — il orchestre.

---

### secrets-guardian

> 🟢 **free**

Surveille les secrets en permanence. Silencieux quand tout va bien — fracassant des qu'une fuite est detectee. Session suspendue, zero exception.

4 surfaces surveillees : code source, chat, commandes shell, outputs d'outils.

---

### brain-guardian

> 🟢 **free**

Auto-mefiance structurelle. Quand le brain travaille sur lui-meme, cet agent exige des preuves pour chaque assertion. Empeche le brain de se convaincre qu'il fonctionne bien sans verification.

---

## Agents systeme — le boot de tous les tiers

> 🟢 **free** — ces agents tournent a chaque boot, quel que soit le tier. Ce sont eux qui font fonctionner le systeme de tiers.

### key-guardian

Valide la Brain API Key au boot. Pas de cle → tier free (silencieux, pas d'erreur). Cle valide → ecrit le tier dans la config. Cache le resultat 24h. VPS down → grace period 72h.

### pre-flight

Gate de boot — verifie que le tier actif autorise la session demandee, que le kerneluser est correct, et que le write_lock est respecte. Bloque si les conditions ne sont pas remplies.

### feature-gate

Feature flags runtime — verifie que chaque agent et session respecte le tier actif. Enforcement silencieux : un agent hors tier n'est pas charge, sans erreur.

---

## Agents kernel — supervision avancee

> 🟣 **full** — supervision pour l'owner du brain

### brain-hypervisor

Supervise les sequences multi-phase. Detecte le drift (quand un workflow derive de son objectif) et intervient.

### kernel-orchestrator

Execute les workflows BSI. Circuit breaker a 3 echecs consecutifs — arret complet, signal humain obligatoire.

---

## Tous les agents de cette page

> 🟢 **free** — `coach-boot` · `scribe` · `todo-scribe` · `metabolism-scribe` · `wiki-scribe` · `helloWorld` · `session-orchestrator` · `secrets-guardian` · `brain-guardian` · `key-guardian` · `pre-flight` · `feature-gate`

> 🔵 **featured** — `coach` (complet) · `coach-scribe`

> 🟠 **pro** — `toolkit-scribe`

> 🟣 **full** — `brain-hypervisor` · `kernel-orchestrator`
