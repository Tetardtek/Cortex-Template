# Guide des sessions — Brain

> Ce guide explique comment fonctionnent les sessions du brain.
> Pour la reference technique complete : `wiki/session-matrix.md`

---

## C'est quoi une session ?

Une session est une conversation avec le brain, du premier message au dernier commit. Chaque session a un **type** qui determine quels agents sont charges, quels fichiers sont accessibles, et ce que le brain peut ecrire.

Le cycle de vie est simple : **boot → work → close**.

- **Boot** : le brain detecte le type de session, charge le contexte minimum necessaire
- **Work** : tu travailles, les agents pertinents sont disponibles
- **Close** : les scribes capturent les metriques, mettent a jour les todos, et ferment le claim BSI

**Le brain demarre toujours en session.** Si tu ne declares pas de type, tu es automatiquement en session `navigate` — la plus legere. C'est le lobby : tu peux regarder autour, poser des questions, et quand tu veux travailler, tu escalades vers le bon type.

---

## Isolation et escalade

Chaque type de session a un perimetre strict. Le brain ne deborde jamais :

- En **navigate** : lecture seule, orientation — pas de code, pas de modification brain
- En **work** : code projet — pas de modification du brain (kernel, agents)
- En **brain** : modification du brain — pas de code projet
- En **edit-brain** : modification kernel — gate humain obligatoire

Si tu demandes quelque chose qui depasse le scope de ta session, le brain te propose d'escalader :

```
"Cette action depasse le scope navigate — brain boot mode work/superoauth pour continuer."
```

Tu confirmes, le brain ferme la session legere et ouvre la bonne. Deux claims dans l'historique, tout est trace.

---

## Les types de sessions

**Coder & produire**

- `work` — Developpement projet → `brain boot mode work/<projet>`
- `debug` — Investigation bug → `brain boot mode debug/<projet>`
- `deploy` — Ship en prod, config VPS → `brain boot mode deploy/<projet>`
- `infra` — Maintenance VPS, monitoring → `brain boot mode infra`
- `urgence` — Production down, hotfix → `brain boot mode urgence`

**Construire le brain**

- `brain` — Travailler sur les agents, todos, focus → `brain boot mode brain`
- `edit-brain` — Modifier le kernel (gate humain) → `brain boot sudo`
- `kernel` — Lire le kernel sans le modifier → `brain boot mode kernel`
- `pilote` — Session longue, copilotage actif → `brain boot mode pilote`

**Explorer & reflechir**

- `brainstorm` — Explorer, challenger, structurer → `brain boot mode brainstorm/<sujet>`
- `navigate` — Vue d'ensemble legere → `brain boot navigate`
- `coach` — Progression, reflexion strategique → `brain boot mode coach`
- `capital` — Bilan, objectifs, CV → `brain boot mode capital`
- `audit` — Analyse lecture seule, rapport → `brain boot mode audit/<projet>`
- `handoff` — Reprendre une session precedente → `brain boot mode handoff/<id>`

---

## Comment ca se lance — les 4 couches

Le brain ne charge pas tout d'un coup. Il utilise 4 couches, comme des pelures d'oignon :

```
L0 — Toujours charge (~5%)
     KERNEL.md, PATHS.md, brain-compose.local.yml
     → L'identite du brain. Non negociable.

L1 — Selon le type de session (~10-18%)
     Les agents et fichiers specifiques a CE type de session.
     → work charge debug + coach, deploy charge vps + ci-cd, etc.

L2 — Selon le projet (~5-15%)
     Si tu declares un projet dans ta commande, ses fichiers sont charges.
     → projets/<nom>.md + todo/<nom>.md

L3 — Sur demande (0% au boot)
     Tout le reste. Charge en cours de session si tu en as besoin.
     → "Charge l'agent testing" → L3 → disponible
```

**Resultat** : ~20-30% du contexte utilise au boot, au lieu de 80%. La session demarre vite.

---

## Ce que chaque session peut / ne peut pas faire

**Sessions projet** — ecrivent dans le code, pas dans le brain :
- `work` · `debug` · `deploy` · `infra` · `urgence` — ecriture projet uniquement

**Sessions brain** — ecrivent dans le brain, pas dans le code :
- `brain` — agents, profil (gate humain sur le kernel)
- `edit-brain` — **ecriture kernel autorisee** (gate humain obligatoire)
- `kernel` — lecture seule, aucune ecriture

**Sessions mixtes** :
- `pilote` — ecriture projet + brain (gates architecturaux sur les forks irreversibles)

**Sessions legeres** — ecriture limitee ou aucune :
- `brainstorm` — todo seulement
- `navigate` — aucune ecriture
- `coach` — progression seulement
- `capital` — profil seulement
- `audit` — rapport seul
- `handoff` — herite du handoff

---

## Ce qui se passe quand tu fermes une session

Quand tu dis `fin`, `on wrappe` ou `c'est bon`, le brain lance une sequence de fermeture automatique :

```
1. Metriques       → metabolism-scribe capture tokens, duree, commits, health_score
2. Todos           → todo-scribe ferme les ✅ et capture les nouveaux ⬜
3. Wiki            → wiki-scribe ajoute les nouveaux termes si besoin
4. Brain update    → scribe met a jour focus, projets, agents si changement
5. Coach           → rapport de session (sauf en navigate, deploy, infra, urgence, audit)
6. BSI close       → le claim est ferme, la session est tracee
```

**Pas toutes les etapes a chaque fois.** Le brain adapte selon le type de session :
- **navigate** : juste metriques + BSI close (session legere)
- **work** : metriques + todos + scribe + coach + BSI close (session complete)
- **brainstorm** : metriques + todos emerges + BSI close (pas de commit attendu)
- **pilote** : tout — metriques + todos + wiki + scribe + coach + BSI close

Le coach ne fait pas de rapport en session silencieuse (navigate, deploy, infra, urgence, audit) — il n'intervient que si risque critique.

---

## Le metabolisme — ce qu'on mesure

A la fin de chaque session, le `metabolism-scribe` capture des metriques :

- **tokens_used** : combien de tokens consommes
- **context_peak** : pic d'utilisation du contexte (%)
- **duration_min** : duree de la session
- **commits** : nombre de commits produits
- **todos_closed** : todos coches pendant la session
- **health_score** : score calcule — se lit en tendance sur 7 jours

Le score n'est pas un jugement. Il detecte les patterns :
- Score bas + context haut = session qui consomme sans produire
- Score bas sur un brainstorm = normal (pas de livrable attendu)
- Ratio use-brain/build-brain < 0.5 sur 7j = trop de travail sur le brain, pas assez de production

### Les 3 profils de scoring

Toutes les sessions ne se mesurent pas pareil :

| Profil | Sessions | Ce qui compte |
|--------|----------|--------------|
| **Productif** | work, deploy, debug, infra, urgence | Todos fermes, commits |
| **Constructif** | brain, edit-brain, kernel, pilote | Fichiers kernel touches, ADRs |
| **Exploratoire** | brainstorm, navigate, coach, capital, handoff, audit | Insights captures, duree |

---

## Les tiers

Le brain a un systeme de tiers qui controle l'acces aux agents et aux sessions :

> 🟢 **free** — 6 sessions (work, debug, brainstorm, brain, navigate, handoff). Pas de cle API. Le brain fonctionne quand meme.

> 🔵 **featured** — +2 sessions (coach, capital). Progression personnelle, RAG, coaching complet.

> 🟠 **pro** — +4 sessions (audit, deploy, infra, urgence). Tous les agents metier : code-review, security, vps, ci-cd, monitoring.

> 🟣 **full** — +3 sessions (kernel, edit-brain, pilote). Tous les agents, acces kernel complet, owner du brain.

→ Detail complet : voir **Agents & Tiers** dans la sidebar.

---

## FAQ

### Comment creer un nouveau type de session ?

1. Creer `contexts/session-<type>.yml` avec le format L0/L1/L2/L3
2. Declarer le tier_required et le context_target
3. Ajouter le type dans `brain-compose.yml` > `feature_sets` > le bon tier
4. Ajouter le handoff_default dans `manifest.yml`
5. Ajouter la zone access dans `KERNEL.md`
6. Mettre a jour `wiki/session-matrix.md`

### Comment escalader depuis navigate ?

Dis simplement `brain boot mode <type>` (ex: `brain boot mode work/superoauth`). Le brain ferme navigate et ouvre la session demandee. Tu peux aussi decrire ce que tu veux faire — le brain detectera le debordement et proposera le bon type.

### Pourquoi ma session est en mode conserve ?

Le mode conserve se declenche quand :
- Le contexte depasse 70% ET le health_score est < 1.0
- Le contexte a la fermeture depasse 60%
- C'est une session urgence (conserve automatique)

En mode conserve, le brain cible < 40% de contexte et ne charge que l'essentiel.

### C'est quoi un handoff ?

Un handoff est un fichier qui capture l'etat d'une session pour qu'une autre puisse reprendre. Niveaux :
- **NO** : pas de handoff — la prochaine session repart de zero (cold start)
- **SEMI** : Layer 0 + position
- **SEMI+** : SEMI + focus + projet
- **FULL** : tout le contexte de reprise

---

## Liens

- **Reference technique** : `wiki/session-matrix.md` — matrice complete avec tous les champs
- **Cycle de vie** : `wiki/session-lifecycle.md` — boot → work → close en detail
- **Context loading** : `wiki/context-loading.md` — architecture BHP L0-L3
- **Metabolisme** : `profil/metabolism-spec.md` — formules et seuils
