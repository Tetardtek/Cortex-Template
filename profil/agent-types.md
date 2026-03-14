# agent-types.md — Typage des agents brain

> **Type :** Référence — Invariant structurel
> Rédigé : 2026-03-14
> Résout : "toggle intelligent, grille agent-review par type, règles de chargement cohérentes, _template.md typé"

---

## Problème résolu

Sans typage formalisé, chaque agent est traité de manière identique. Résultat :
- helloWorld charge des agents sans savoir s'ils peuvent être togglés (certains ne se togglent pas)
- agent-review audite un scribe avec les critères d'un agent métier
- le feature-flag filtering ne sait pas quel type d'agent exclure en mode léger
- les règles de Sources au démarrage varient sans pattern documenté

Le typage donne une grammaire partagée — un agent qui se déclare `scribe` hérite de règles connues sans les réécrire.

---

## Types

### `system`

Agents d'infrastructure du brain lui-même. Toujours chargés, non togglables.

**Règle :** sources au démarrage minimales. Ne produisent rien — ils orchestrent ou gardent.

| Agent | Rôle |
|-------|------|
| `helloWorld` | Bootstrap — briefing, chargement sélectif, claims BSI |
| `session-orchestrator` | Lifecycle boot+close — reçoit handoff de helloWorld |
| `secrets-guardian` | Gardien permanent — 4 surfaces, passive listener |
| `brain-compose` | Multi-instances — kernel/instance split, registre machine |

---

### `scribe`

Agents d'écriture — persistance d'un repo ou d'une couche. Invocation unique par session.

**Règle :** zéro source au démarrage. Tout reçu par rapport entrant. Un seul scribe propriétaire par repo/couche.

| Agent | Repo / Couche propriétaire |
|-------|---------------------------|
| `scribe` | `brain/` — focus, projets/, agents/ |
| `metabolism-scribe` | `progression/metabolism/` — métriques session |
| `toolkit-scribe` | `toolkit/` — patterns validés |
| `coach-scribe` | `progression/` — journal, skills, milestones |
| `todo-scribe` | `todo/` — intentions, todos ⬜/✅ |
| `content-scribe` | `content/` — drafts, captures, content-logs |
| `orchestrator-scribe` | `BRAIN-INDEX.md` — Signals, HANDOFF, CHECKPOINT |
| `config-scribe` | `profil/` couche config — wizard first run |
| `capital-scribe` | `profil/capital.md` — milestones → formulations CV |

---

### `meta`

Agents de conception et d'amélioration du brain. Produisent des agents, des specs, des audits.

**Règle :** invocation manuelle uniquement. Peuvent charger n'importe quelle source — c'est leur métier.

| Agent | Rôle |
|-------|------|
| `recruiter` | Forge de nouveaux agents — template selection, grille qualité |
| `agent-review` | Audit du système — gaps, cohérence, preAlpha checklist |
| `brainstorm` | Exploration, avocat du diable, décisions architecturales |
| `interprete` | Clarification intention — demandes ambiguës, scope drift |
| `aside` | Parenthèse /btw — 2-3 lignes, retour session |

---

### `coach`

Agents de guidance humaine. Observent sans intervenir pendant le travail — parlent aux moments clés.

**Règle :** passive listener permanent. Parlent au boot (si demandé), pendant (sur signal), et au close (rapport).

| Agent | Rôle |
|-------|------|
| `coach` | Présence permanente — rapport close, pattern observé, point à ancrer |
| `mentor` | Pédagogie — explication, garde-fou, +coach flag étendu |

---

### `orchestrator`

Agents de coordination — routent, délèguent, synchronisent. Ne produisent pas de contenu eux-mêmes.

**Règle :** décision + délégation. Jamais d'exécution directe.

| Agent | Rôle |
|-------|------|
| `orchestrator` | Diagnostic + délégation multi-agents |
| `supervisor` | Multi-sessions — dual-agent, CHECKPOINT, escalade humain |
| `content-orchestrator` | Signal content-worthy → draft pipeline |

---

### `metier`

Agents de domaine technique. Chargés sur trigger domaine (CLAUDE.md auto-detect) ou invocation explicite.

**Règle :** sources au démarrage = minimum domaine. Couche projet en Source conditionnelle seulement.

| Agent | Domaine |
|-------|---------|
| `vps` | VPS, Apache, Docker, SSL, deploy |
| `debug` | Bug, crash, comportement inattendu |
| `security` | Faille, JWT, OAuth, OWASP |
| `code-review` | Review, qualité, PR, validation |
| `testing` | Jest, Vitest, coverage, TDD |
| `refacto` | Dette technique, DDD |
| `ci-cd` | Pipeline, GitHub Actions, Gitea CI |
| `monitoring` | Kuma, alertes, logs |
| `optimizer-backend` | Node.js perf, mémoire |
| `optimizer-db` | MySQL, N+1, index, TypeORM |
| `optimizer-frontend` | Bundle, re-renders, React |
| `pm2` | Process manager |
| `migration` | TypeORM schema, migrations |
| `frontend-stack` | shadcn, Tailwind, UI libs |
| `i18n` | Traductions, clés manquantes |
| `doc` | README, API, Swagger |
| `mail` | SMTP, IMAP, Stalwart, DNS ← **metier/protocol** |

---

### `metier/protocol` (sous-type)

Agents métier dont le domaine est régi par des **RFC ou spécifications formelles**. Pas de marge d'erreur — une erreur de protocole = prod cassé ou faille exploitable.

**Règles supplémentaires par rapport à `metier` :**
- Vérification obligatoire avant toute affirmation (citer RFC ou spec)
- Anti-hallucination renforcé — préférer "je ne sais pas" à une approximation
- Toute déviation du standard documentée explicitement avec justification
- Niveau de confiance affiché sur chaque décision technique

| Agent | Protocole(s) | RFC de référence |
|-------|-------------|-----------------|
| `mail` | SMTP, IMAP, DKIM, DMARC, SPF | RFC 5321, 5322, 6376, 7489 |
| `security` | OAuth 2.0, JWT, TLS | RFC 6749, 7519 |

---

## Impact sur les outils

### `_template.md`

Ajouter en en-tête :
```
> **Type :** <system | scribe | meta | coach | orchestrator | metier | metier/protocol>
```

### Toggle intelligent (helloWorld / brain-compose)

| Type | Toggleable ? | Règle |
|------|-------------|-------|
| `system` | Non | Toujours chargé |
| `scribe` | Non | Invoqué sur signal, jamais en fond |
| `meta` | Oui | Exclu en mode léger |
| `coach` | Oui | Flag +coach pour activer en cours de session |
| `orchestrator` | Oui | Exclu en mode solo/léger |
| `metier` | Oui | Auto-detect CLAUDE.md ou invocation |
| `metier/protocol` | Non | Jamais bypasser le gardien protocolaire |

### Grille agent-review par type

- `system` → critères : passivité boot, zéro surcharge contexte, ownership clair
- `scribe` → critères : zéro source démarrage, un seul repo propriétaire, format log standardisé
- `meta` → critères : capacité à lire n'importe quelle source, output actionnable
- `coach` → critères : rapport non-bloquant sauf close, passive listener permanent
- `orchestrator` → critères : délègue tout, ne produit pas de contenu
- `metier` → critères : sources min, couche projet conditionnelle, toolkit-scribe en écoute
- `metier/protocol` → critères : citation RFC, niveau de confiance explicite, anti-hallucination renforcé

---

## Trigger de chargement

```
Propriétaire : agent-review, recruiter, session-orchestrator, helloWorld
Trigger      : forgeage d'un nouvel agent (recruiter), audit (agent-review), toggle décision (helloWorld)
Section      : Sources au démarrage (agent-review, recruiter) — Sources conditionnelles (helloWorld)
```

---

## Maintenance

```
Propriétaire : agent-review (audits) + recruiter (forgeage)
Mise à jour  : quand un nouveau type émerge, ou qu'un sous-type est formalisé
Jamais modifié par : agents métier, scribes
```

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-14 | Création — 6 types + sous-type metier/protocol, toggle rules, grille agent-review |
