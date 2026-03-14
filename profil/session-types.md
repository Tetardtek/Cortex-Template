# session-types.md — Types de sessions et comportements au boot

> Dernière mise à jour : 2026-03-14
> Type : Référence
> Géré par : `session-orchestrator`
> Utilisé par : `helloWorld`, `session-orchestrator`, `metabolism-scribe`

---

## Tableau complet — boot possibilities

| Intent déclaré | Mode activé | Contexte chargé | Scribes close | MYSECRETS |
|----------------|-------------|-----------------|---------------|-----------|
| `brain` | `prod` | BRAIN-INDEX, focus, todo/brain, AGENTS | metabolism + scribe + coach | ❌ non |
| `work <projet>` | `prod` | projets/X, todo/X, agent métier détecté | metabolism + todo-scribe + coach | ⚡ si .env/db |
| `sprint <projet>` | `prod` | projets/X, todo/X, BSI scope déclaré | metabolism + todo-scribe + coach | ⚡ si .env/db |
| `deploy <projet>` | `deploy` | projets/X, infrastructure/vps, agent vps/ci-cd | metabolism | ✅ oui |
| `debug <projet>` | `debug` | projets/X, agent debug | metabolism + todo-scribe | ⚡ si .env/db |
| `review <projet>` | `review-back` ou `review-front` | projets/X, agent code-review | metabolism | ❌ non |
| `coach` | `coach` | profil/objectifs, progression/README, skills/ | metabolism + coach-scribe | ❌ non |
| `brainstorm <sujet>` | `brainstorm` | BRAIN-INDEX si brain, projets/X si work | metabolism | ❌ non |
| `agents` | `prod` | AGENTS.md, _template, profil/context-hygiene | metabolism + scribe | ❌ non |
| (rien / ambigu) | → 1 question | `brain ou work ?` → résout vers l'un des cas ci-dessus | — | — |

> **HANDOFF** : détecté automatiquement si claim HANDOFF dans BRAIN-INDEX → mode HANDOFF, charge handoffs/<fichier>.md

---

## Règle MYSECRETS — passive listening

```
Au boot        → secrets-guardian confirme que MYSECRETS existe (présence only)
                 Ne charge PAS les valeurs
                 Écoute passive sur 4 surfaces (code / chat / shell / output)

Sur trigger    → charge MYSECRETS et active le cycle de vie secrets
Triggers :       .env | mysql | VPS | deploy | JWT | token | API key | credentials | MYSECRETS mentionné
```

---

## Contexte chargé par type — détail

### `brain`
```
Couche 0 — invariant   : PATHS + collaboration
Couche 1 — intent      : brain
Couche 2 — domaine     : BRAIN-INDEX + focus + todo/brain
Couche 3 — projet      : (aucun)
```

### `work <projet>`
```
Couche 0 — invariant   : PATHS + collaboration
Couche 1 — intent      : work
Couche 2 — domaine     : agent métier détecté (frontend / backend / infra / agents)
Couche 3 — projet      : projets/<projet> + todo/<projet>
```

### `deploy <projet>`
```
Couche 0 — invariant   : PATHS + collaboration
Couche 1 — intent      : deploy
Couche 2 — domaine     : infrastructure/vps + agents vps/ci-cd/pm2
Couche 3 — projet      : projets/<projet> — section deploy uniquement
MYSECRETS : chargé — secrets requis pour VPS/docker
```

### `coach`
```
Couche 0 — invariant   : PATHS + collaboration
Couche 1 — intent      : coach
Couche 2 — domaine     : progression/README + skills/<domaine si précisé>
Couche 3 — projet      : (aucun — focus progression uniquement)
```

### `brainstorm <sujet>`
```
Couche 0 — invariant   : PATHS + collaboration
Couche 1 — intent      : brainstorm
Couche 2 — domaine     : selon sujet (brain → BRAIN-INDEX / work → projets/X)
Couche 3 — projet      : (aucun — pas d'écriture)
```

---

## Séquence close — par type

| Type session | Ordre scribes |
|-------------|---------------|
| `brain` | metabolism-scribe → scribe → **coach rapport** → user décide |
| `work` | metabolism-scribe → todo-scribe → scribe (si commit) → **coach rapport** → user décide |
| `sprint` | metabolism-scribe → todo-scribe → **coach rapport** → user décide |
| `deploy` | metabolism-scribe → scribe (infra) → user décide |
| `debug` | metabolism-scribe → todo-scribe → **coach rapport** → user décide |
| `coach` | metabolism-scribe → coach-scribe → user décide |
| `brainstorm` | metabolism-scribe → todo-scribe (si todos émergés) → user décide |

> `coach rapport` = coach produit le bilan de session **avant** la fermeture BSI.
> L'utilisateur lit, puis choisit : `/exit` ou discussion avec le coach.
> BSI close est toujours le dernier geste — même si l'utilisateur part sans lire.

---

## Signal au boot — format

```
"brain"                        → type: brain
"work originsdigital"          → type: work, projet: originsdigital
"deploy originsdigital"        → type: deploy, projet: originsdigital
"debug originsdigital"         → type: debug, projet: originsdigital
"review backend originsdigital" → type: review-back, projet: originsdigital
"coach"                        → type: coach
"brainstorm agents"            → type: brainstorm, sujet: agents
(premier message ambigu)       → session-orchestrator pose 1 question
```

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-14 | Création — tableau complet boot possibilities, règle MYSECRETS passive, séquence close par type, architecture 4 couches |
