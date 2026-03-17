---
name: 015-architecture-deux-niveaux-agents-L1-L2
type: decision
context_tier: warm
status: accepted
---

# ADR-015 — Architecture deux niveaux agents : local (L2) vs git-triggered relay (L1)

> Date : 2026-03-17
> Statut : actif
> Décidé par : session brain 2026-03-17

---

## Contexte

Aujourd'hui, tous les agents opèrent en session locale (Level 2) mais le protocole BSI les traite uniformément comme Level 1 : claim créé, commité, pushé avant de travailler. Cette friction est acceptable pour les sessions humaines — elle ancre la session dans le kernel et rend le contexte visible au VPS et aux sessions parallèles. Elle est en revanche un blocage structurel pour les agents automatiques (ambient daemon, agent-review inline, debug ephemere) qui doivent démarrer sans friction.

Deux insights ont émergé lors de la session 2026-03-17 :

1. **Le BSI crée une friction qui bloque l'automatisation locale.** Un agent local qui doit créer un claim, commiter et pusher avant de travailler est un agent qui ne peut pas opérer à la vitesse d'une session.
2. **Git est le bus de coordination naturel.** La transition entre travail local (éphémère) et travail persisté (kernel) passe naturellement par un commit. Git est déjà le mécanisme de versionning, de relay, et de déclencheur.

Note orthogonale validée le même jour : la séparation pay-gate (fonctionnalités monétisées) vs BSI opérationnel (plomberie) est une décision distincte — les endpoints de revenu restent gatés quelle que soit la provenance de la requête.

---

## Décision

Formaliser une architecture à deux niveaux d'exécution agents, avec des protocoles et des infrastructures distincts.

### Level 1 — Git-triggered relay (asynchrone)

- **Trigger :** webhook git (push, PR, commit kernel)
- **Protocole BSI :** complet — claim créé, commité, pushé
- **Artefacts durables :** `decisions/`, `claims/`, `toolkit/`, `audits/`
- **Auth + tier enforcement :** complet, aucune exception
- **Use cases :** agent-review sur PR, deploy agent sur push main, kernel-auditor sur commit kernel
- **Infrastructure requise :** endpoint `POST /webhook` dans brain-engine — **NON CONSTRUIT** (vision future)

### Level 2 — Local fast (synchrone, frictionless)

- **Trigger :** session courante, appel direct `localhost:7700`
- **Protocole BSI :** aucun. Pas de claim. Pas de commit. Pas de push. Log éphémère local optionnel.
- **localhost trust :** endpoints BSI opérationnels (`GET /boot`, `/agents`, `/teams`, `/workflows`, `POST /workflows/create`) — aucune auth requise, aucun tier gate
- **Pay endpoints :** maintenus gatés même en localhost — aucune exception
- **Use cases :** agent-review inline, debug, bact-scribe, workflow-auditor local, ambient daemon notify
- **Infrastructure requise :** helper `_is_localhost()` dans brain-engine — **À CONSTRUIRE**

### Règle de promotion L2 → L1

Un Level 2 qui veut persister son travail dans le kernel fait un commit. Ce commit déclenche le relay Level 1. Git est le seul mécanisme de transition L2 → L1. Il n'y a pas d'autre voie.

### Endpoints jamais bypassed même en Level 2

| Endpoint | Feature | Raison |
|---|---|---|
| `GET /visualize` | pro | génère du revenu |
| `GET /infra` | pro | génère du revenu |
| `PUT /brain/{path}` | pro | génère du revenu |

Ces endpoints sont pay-gated sans exception de provenance.

### Conventions de session

- **Sessions humaines :** Level 1 par convention. Le claim anchor la session dans le kernel, la rend visible aux sessions parallèles et au VPS.
- **Agents locaux automatiques :** Level 2 par défaut. Le boot claim BSI est optionnel — aucune friction imposée.

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| BSI allégé (claim sans push) | Ne résout pas la friction pour les daemons — le commit reste bloquant. |
| Token court-circuit local (token spécial localhost) | Introduit une surface d'auth supplémentaire à maintenir. La confiance localhost sans token est plus simple et plus robuste. |
| Endpoint /local-boot sans auth global | Trop large — expose des endpoints qui devraient rester gatés (pay features). La granularité par endpoint est préférable. |

---

## Vision webhook future (à ne pas perdre)

```
git push
  → Gitea webhook → POST brain-engine/webhook
  → brain-engine parse le payload (branch, files modifiés, author)
  → route vers l'agent relay approprié selon les fichiers touchés :
      agents/*.md modifié    → kernel-auditor
      brain-ui/**            → agent-review frontend
      brain-engine/**        → agent-review backend
      claims/*.yml fermé     → workflow-auditor
  → agent s'exécute avec contexte complet (diff, commit message, author)
  → résultat commité dans audits/ ou decisions/
```

Ne pas construire avant un use case concret. L'infrastructure webhook L1 est une vision, pas un backlog immédiat.

---

## Conséquences

**Positives :**
- Les agents locaux automatiques peuvent démarrer sans friction BSI
- La distinction est claire : local = éphémère, git = durable
- Git reste la source de vérité — aucune donnée persistée hors kernel sans commit
- Les sessions humaines ne changent pas de comportement (Level 1 par convention)
- Le protocole BSI existant reste intact pour les sessions qui en ont besoin

**Négatives / trade-offs assumés :**
- Une session Level 2 est invisible au VPS et aux autres sessions tant qu'elle ne commit pas
- Le helper `_is_localhost()` doit être implémenté dans brain-engine avant de pouvoir bénéficier des endpoints frictionless
- La ligne pay-gate / BSI-opérationnel doit être maintenue explicitement dans le code — risque de dérive si non documentée

---

## Références

- Fichiers concernés :
  - `brain-engine/server.py` — tier enforcement, endpoints à séparer par niveau
  - `CLAUDE.md` — boot claim BSI, à qualifier "optionnel pour les sessions Level 2"
  - `brain-constitution.md` — Layer 0, invariants de session
  - `brain-compose.yml` — modes session, permissions BSI par mode
- Sessions où la décision a émergé :
  - Session 2026-03-17 — friction BSI agents locaux + git comme bus de coordination
  - ADR-014 — zone-aware BSI, kerneluser (contexte parent)
