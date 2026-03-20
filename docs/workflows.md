# Workflows — les recettes d'agents

> Quels agents combiner, pour quel resultat. Les combinaisons testees et validees.

---

## Quotidien

### Coder sur un projet

```
brain boot mode work/mon-projet
```

> 🟢 **free**

Agents actifs : `debug`, `scribe`, `todo-scribe`. Le brain detecte ce que tu fais et charge les agents supplementaires si besoin.

---

### Debugger un bug

```
brain boot mode debug/mon-projet
```

> 🟢 **free**

Agent principal : `debug` — methode en 5 etapes (reproduire → isoler → hypotheses → verifier → corriger). Si le bug touche l'infra → delegue a `vps`.

---

### Explorer une idee

```
brain boot mode brainstorm/sujet
```

> 🟢 **free**

Agent principal : `brainstorm` — avocat du diable, challenge tes decisions. Pas de livrable attendu — les insights sont captures en todo si actionnable.

---

## Avant de shipper

### Review code + securite

```
Charge les agents code-review et security
```

> 🟠 **pro**

`code-review` analyse selon 7 priorites. Si un finding critique est detecte → `security` prend le relais pour l'audit OWASP. Apres → `testing` pour couvrir les corrections.

**Recette complete avant prod :**

```
Charge les agents security, code-review et testing
```

Les 3 travaillent en sequence : securite → qualite → tests.

---

### Audit perf full-stack — le trio

```
Charge les agents optimizer-backend, optimizer-db et optimizer-frontend
```

> 🟠 **pro**

Le trio Riri Fifi Loulou :
- `optimizer-backend` — async, memoire, event loop Node.js
- `optimizer-db` — N+1, index manquants, EXPLAIN
- `optimizer-frontend` — re-renders, bundle, lazy loading

Chacun sait ce qu'il ne couvre pas et delegue aux deux autres.

---

## Deploy

### Deployer un nouveau service

```
brain boot mode deploy/mon-projet
```

> 🟠 **pro**

Agents actifs : `vps` + `ci-cd`. Le workflow :
1. `vps` deploie le service (Docker + Apache + SSL)
2. `ci-cd` cree le pipeline (GitHub Actions ou Gitea CI)
3. `monitoring` suggere une sonde post-deploy

---

### Deployer un service mail

```
brain boot mode deploy
Charge les agents vps et mail
```

> 🟠 **pro**

`vps` gere le serveur (container Stalwart, vhost Apache), `mail` gere le protocole (SMTP, IMAP, DNS, SPF, DKIM).

---

## Refacto

### Refacto securisee

```
Charge les agents refacto et testing
```

> 🟠 **pro**

1. `testing` ecrit les tests avant la refacto (filet de securite)
2. `refacto` restructure par etapes (tests verts a chaque etape)
3. `code-review` valide le resultat

**Regle :** pas de tests → pas de refacto niveau 2/3.

---

## Incidents

### Bug en prod

```
brain boot mode urgence
```

> 🟠 **pro**

Agents actifs : `debug` + `vps`. Mode conserve automatique (economie de contexte). `debug` isole le probleme, `vps` intervient si c'est infra.

---

### Incident complexe

```
brain boot mode urgence
Charge les agents monitoring, vps et debug
```

> 🟠 **pro**

`monitoring` lit les alertes et logs → `vps` diagnostique l'infra → `debug` isole le bug applicatif. Sequence : alertes → infra → code.

---

## Brain

### Forger un nouvel agent

```
brain boot mode brain
Charge l'agent recruiter
```

> 🟢 **free**

`recruiter` concoit l'agent : domaine, perimetre, composition, anti-hallucination. Il produit le fichier `.md` complet. `agent-review` peut ensuite l'auditer.

---

### Auditer le systeme d'agents

```
brain boot mode brain
Charge l'agent agent-review
```

> 🟢 **free**

`agent-review` detecte les gaps, les overlaps, et les agents qui ne font pas ce qu'ils promettent. Si un gap est trouve → `recruiter` forge l'agent manquant.

---

### Session pilote (copilotage long)

```
brain boot mode pilote
```

> 🟣 **full**

Le coach est proactif — il anticipe les bifurcations et challenge les decisions. Tous les scribes sont actifs. Contexte max (~35%).

---

## Les combos par tier

> 🟢 **free** — debug seul, brainstorm seul, forger des agents, auditer le systeme

> 🔵 **featured** — tout ce qui est free + sessions coach avec bilans et objectifs

> 🟠 **pro** — review + securite + tests, trio perf, deploy complet, incidents, refacto securisee

> 🟣 **full** — pilotage long, supervision multi-phase, contenu YouTube, modification kernel
