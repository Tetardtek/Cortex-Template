# Agents spécialisés — Tetardtek

> Index des agents disponibles.
> Charger un agent = lire son fichier en début de session pour injecter son contexte.
> Stratification Chaud/Froid — voir `brain/profil/memory-architecture.md` Pillier 3.

---

## 🔴 Agents chauds — auto-détectés sur trigger domaine

> Chargés automatiquement quand le domaine est détecté. Jamais au boot.

| Agent | Domaine | Statut |
|-------|---------|--------|
| `coach` | Progression — tutorat, suivi, coaching code + agents | 🔄 permanent |
| `vps` | Infra, Apache, Docker, SSL | 🔄 |
| `mail` | Stalwart, DNS, protocoles | 🔄 |
| `code-review` | Qualité, sécurité, dette technique | ✅ 2026-03-12 |
| `security` | Auth, tokens, OWASP | ✅ 2026-03-12 |
| `testing` | Jest, Vitest, DDD, coverage | ✅ 2026-03-12 |
| `debug` | Débogage local + prod | ✅ 2026-03-12 |
| `refacto` | Refactorisation — architecture + code | ✅ 2026-03-12 |
| `monitoring` | Observabilité — Kuma, logs VPS | ✅ 2026-03-12 |
| `ci-cd` | Pipelines GitHub Actions + Gitea CI | ✅ 2026-03-12 |
| `optimizer-backend` | Perf Node.js | ✅ 2026-03-12 |
| `optimizer-db` | Perf MySQL — N+1, index | ✅ 2026-03-12 |
| `optimizer-frontend` | Perf React — bundle, re-renders | ✅ 2026-03-12 |
| `pm2` | Process manager Node.js prod | 🧪 forgé 2026-03-13 |
| `migration` | TypeORM migrations — schéma, deploy safe | 🧪 forgé 2026-03-13 |
| `frontend-stack` | Architecture frontend — stack, libs UI, patterns pro | 🧪 forgé 2026-03-13 |
| `i18n` | Internationalisation — audit traductions, clés manquantes | 🧪 forgé 2026-03-13 |
| `doc` | Documentation — README, API Swagger, cohérence doc ↔ code | 🧪 forgé 2026-03-13 |

---

## 🔵 Agents stables — invocation manuelle uniquement

> Ne se chargent pas automatiquement. Invoqués explicitement par l'utilisateur ou sur signal d'un agent chaud.

| Agent | Domaine | Statut |
|-------|---------|--------|
| `orchestrator` | Coordination — diagnostic et délégation multi-agents | ✅ 2026-03-12 |
| `scribe` | Maintenance du brain | ✅ 2026-03-12 |
| `mentor` | Pédagogie — explication, garde-fou | ✅ 2026-03-12 |
| `recruiter` | Meta-agent — conception d'agents | 🔄 |
| `agent-review` | Audit du système d'agents — gaps, patches, vue système | ✅ 2026-03-13 |
| `interprete` | Clarification d'intention — demandes ambiguës, scope drift | 🧪 forgé 2026-03-13 |
| `brainstorm` | Exploration et structuration de décisions — avocat du diable | 🧪 forgé 2026-03-13 |
| `aside` | Parenthèse de session — répond au pattern /btw, 2-3 lignes, retourne à session | 🧪 forgé 2026-03-14 |
| `toolkit-scribe` | Persistance patterns — gardien du toolkit/ | 🧪 forgé 2026-03-13 |
| `coach-scribe` | Persistance progression — journal/skills/milestones | 🧪 forgé 2026-03-13 |
| `todo-scribe` | Persistance intentions — gardien de brain/todo/ | 🧪 forgé 2026-03-13 |
| `helloWorld` | Bootstrap intelligent — briefing + chargement sélectif | 🧪 forgé 2026-03-13 |
| `git-analyst` | Historique git sémantique — conventions, synthèse commits | 🧪 forgé 2026-03-13 |
| `capital-scribe` | Capital CV — milestones → formulations recruteur | 🧪 forgé 2026-03-13 |
| `config-scribe` | Configuration brain — wizard first run, hydration Sources | 🧪 forgé 2026-03-13 |
| `brain-compose` | Multi-instances brain — symlinks kernel, registre machine | 🧪 forgé 2026-03-13 |

---

## Template

Créer un nouvel agent : copier `_template.md`, remplir, ajouter dans la bonne section (🔴 ou 🔵).

---

## Workflows multi-agents connus

| Workflow | Agents | Description |
|----------|--------|-------------|
| Nouveau service VPS | `vps` | Deploy Docker + Apache + SSL |
| Audit infra + code | `vps` + `code-review` | Vérification complète avant mise en prod |
| Déploiement mail | `vps` + `mail` | Setup Stalwart depuis zéro |
| Audit perf full-stack | `optimizer-backend` + `optimizer-db` + `optimizer-frontend` | Riri Fifi Loulou |
| Audit perf backend | `optimizer-backend` + `optimizer-db` | API + DB — sans toucher au frontend |
| Validation avant prod | `code-review` + `ci-cd` | Review code + pipeline avant déploiement |
| Nouveau projet complet | `vps` + `ci-cd` | Déploiement serveur + pipeline CI/CD |
| Problème non identifié | `orchestrator` → agents détectés | Diagnostic + délégation automatique |
| Audit système d'agents | `agent-review` → `recruiter` | Review + détection gaps → forge si besoin |
| Exploration / décision archi | `brainstorm` → `recruiter` ou agent métier | Explorer + challenger → construire |
| Question hors-scope en session | `aside` | /btw → 2-3 lignes → retour session |
| Fin de session complète | `scribe` + `toolkit-scribe` + `coach-scribe` + `todo-scribe` | Brain + toolkit + progression + intentions |
| Feature livrée en prod | `git-analyst` + `capital-scribe` | Commits synthétisés + capital CV mis à jour |
| Projet multi-langue | `i18n` + `frontend-stack` | Audit traductions + intégration lib |
| Release / PR importante | `doc` + `code-review` | Doc à jour + code validé |
| Audit complet avant prod | `security` + `code-review` + `testing` | Validation complète feature sensible |
| Bug prod complexe | `debug` + `vps` | Isolation + infra |
| Refacto sécurisée | `refacto` + `testing` + `code-review` | Tests avant, refacto, review après |
| Incident prod | `monitoring` + `vps` + `debug` | Alerte → diagnostic infra → debug applicatif |
| Nouveau déploiement | `ci-cd` + `monitoring` | Pipeline + sondes de surveillance |
| Dream team perf | `orchestrator` → `optimizer-*` | Audit perf full-stack via orchestrateur |
