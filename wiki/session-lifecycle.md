# Brain — Cycle de vie d'une session

> Ce qui se passe du premier message au dernier commit.

---

## Boot (automatique)

```
Message utilisateur
    ↓
CLAUDE.md charge :
  0. PATHS.md              — chemins machine
  1. collaboration.md      — règles de travail
  2. coach.md              — présence permanente
  3. secrets-guardian.md   — écoute passive MYSECRETS
  4. helloWorld.md         — briefing + CHECKPOINT + détection session

helloWorld → ouvre claim BSI + push immédiat
    ↓
session-orchestrator reçoit le handoff :
  → détecte session_type + scope
  → détermine handoff_level (NO / SEMI / SEMI+ / FULL)
  → charge les couches correspondantes
  → active la position (rôle contextuel)
```

**Handoff levels :**

| Level | Contexte chargé |
|-------|----------------|
| `NO` | Layer 0 seulement (kernel + constitution + paths + collaboration) |
| `SEMI` | Layer 0 + position |
| `SEMI+` | SEMI + focus.md + projets/<scope> + todo/<scope> |
| `FULL` | SEMI+ + Layer 2 : workspace actif + handoffs |

---

## Work

- Agents invoqués sur domaine détecté (auto) ou sur demande explicite
- `/btw` disponible à tout moment pour aparté sans casser le fil
- `/checkpoint` recommandé avant compactage ou si sprint > 2h

---

## Close — séquence obligatoire

> Déclenchée par : `fin` | `on wrappe` | `je ferme` | `c'est bon`
> Source de vérité close sequences par type : `wiki/session-matrix.md`
> Decision tree runtime : `agents/session-orchestrator.md ## boot-summary`

```
Étape 0 — Checkpoint (si sprint actif)
  → Écrire workspace/<sprint>/checkpoint.md
  → Permet warm restart à la prochaine session

Étape 1 — metabolism-scribe  ← TOUJOURS (15 types)
  → tokens_used, context_peak, duration, agents_loaded
  → commits, todos_closed, health_score (formule par profil), handoff_level
  → type : use-brain | build-brain | explore-brain | auto

Étape 2 — todo-scribe  ← RÈGLE INVIOLABLE
  → Tout item complété pendant la session → [x] dans backlog.md
  → Mettre à jour la table métriques (✅ Done +N, ⬜ Open -N)
  → Si aucun item fermé → écrire pourquoi dans changelog backlog
  → Commit : "backlog: close <item-id> — <titre court>"

Étape 3 — todo-scribe  [si work | sprint | debug | brainstorm]
  → ✅ todos fermés
  → ⬜ todos émergés capturés

Étape 4 — wiki-scribe  [si nouveau pattern/commande/agent forgé]
  → Ajouter terme dans vocabulary.md
  → Créer/mettre à jour la page wiki concernée
  → Commit : "wiki: vocabulary +N terms — <domaine>"

Étape 5 — scribe  [si session significative]
  → brain/ : focus, projets/, AGENTS si nouvel agent

Étape 6 — coach  [rapport de session — si coach actif]
  ⚡ Rapport de session — <sess-id>
     Ce qui a été produit : <liste concrète>
     Pattern observé      : <observation — 1 ligne>
     Point à ancrer       : <concept ou réflexe>
     Objectif suivant     : <1 action concrète mesurable>
  → BLOCKING — attend réponse ou /exit

Étape 7 — BSI close claim  ← NON NÉGOCIABLE
  → status: open → closed dans claims/<sess-id>.yml
  → git commit + push brain/
  → rm session-role + pid
```

### Close sequences par type de session

| Type | Sequence (etapes actives) |
|------|--------------------------|
| `audit` | 1 (metabolism) → rapport audit → 7 (BSI close) |
| `brain` | 1 → 5 (scribe) → 6 (coach) → 7 |
| `brainstorm` | 1 → 3 (todo si todos emerges) → 7 |
| `capital` | 1 → capital-scribe → 6 (coach) → 7 |
| `coach` | 1 → coach-scribe → 7 |
| `debug` | 1 → 2 + 3 (todo) → 6 (coach) → 7 |
| `deploy` | 1 → 5 (scribe infra) → 7 |
| `edit-brain` | 1 → 5 (scribe) → 6 (coach) → 7 |
| `handoff` | 1 → 7 |
| `infra` | 1 → 5 (scribe si changement config) → 7 |
| `kernel` | 1 → 7 |
| `navigate` | 1 → 7 |
| `pilote` | 1 → 4 (wiki) → 5 (scribe) → 6 (coach) → 7 |
| `urgence` | 1 → post-mortem scribe → 7 |
| `work` | 1 → 2 + 3 (todo) → 5 (scribe si commit) → 6 (coach) → 7 |

---

## Règle inviolable backlog (étape 2)

> Sans cette règle, le backlog devient un cimetière de todos. La métrique de vélocité reste à zéro.

**Ce qui est obligatoire :**
- Chaque item touché pendant la session → [x] si terminé, note si partiel
- Table métriques recalculée avant le commit
- Un commit `backlog: close ...` par item fermé (ou un commit groupé si plusieurs)

**Ce qui est interdit :**
- Fermer la session sans avoir vérifié le backlog
- Marquer [x] un item non terminé (intégrité des métriques)

---

## Warm restart (Pattern 8)

Si la session se poursuit après compactage ou reprise :
```
Lis brain/workspace/<sprint>/checkpoint.md et reprends — pas de bootstrap complet.
```

Cold bootstrap : 2-3 min — Warm restart : < 30 sec.
