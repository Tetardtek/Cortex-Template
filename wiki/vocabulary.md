# Brain — Vocabulaire

> Source unique de vérité pour les termes du brain.
> Mis à jour par `wiki-scribe` en close de session quand un terme est forgé.
> `git log wiki/vocabulary.md` = timeline de croissance du vocabulaire.

---

## circuit breaker
> Forgé : 2026-03-17 | Domaine : orchestration kernel
Mécanisme de protection dans `kernel-orchestrator` : 3 échecs consécutifs sur le même scope → arrêt automatique de la séquence, signal `CIRCUIT_BREAK` vers `brain-hypervisor`, gate:human obligatoire avant reprise. Règle : jamais relancer automatiquement après 3 fails — l'humain inspecte. Script : `scripts/preflight-check.sh reset <scope>`.

## context-broker
> Forgé : 2026-03-15 | Domaine : brain système
Agent qui gère le cycle respiratoire du contexte d'un sprint. Deux temps : **inhale** (source_map en début de sprint — quels agents lisent quels fichiers) et **expire** (release_map en fin de sprint — ce qui a été touché, todos ouvertes, métriques breath). Rend le contexte traçable et libère proprement la mémoire inter-sprints.

## contention map
> Forgé : 2026-03-14 | Domaine : orchestration multi-agents
Carte produite par `tech-lead` en gate d'entrée de sprint : pour chaque fichier touché, quel agent en est l'owner et quels autres agents le touchent aussi. Permet de planifier l'ordre de commit pour éviter les conflits de merge. Input clé pour `orchestrator` et `integrator`.

## cosign
> Forgé : 2026-03-14 | Domaine : orchestration / zones
Convention de validation d'un overflow de zone par le `tech-lead`. Format obligatoire dans le message de commit de l'agent qui écrit : `tech-lead: overflow granted — <raison courte>`. Trace l'autorisation dans le git log. Sans cosign → overflow non autorisé.

## brain run
> Forgé : 2026-03-15 | Domaine : onboarding
Commande d'installation du brain sur une nouvelle machine. Une seule ligne suffit pour avoir un cerveau opérationnel. Voir `wiki/brain-setup.md` et la page [Cold Start](cold-start).

## brain_name
> Forgé : 2026-03-14 | Domaine : brain système
Identifiant de l'instance brain sur une machine (`prod`, `prod-laptop`). Défini dans `~/.claude/CLAUDE.md`. Détermine le write_mode et les permissions push.

## ASF-Brain
> Forgé : 2026-03-15 | Domaine : vision
Autonomous Software Factory — état cible où le brain peut builder un tier logiciel complet depuis un brief humain, sans intervention sur le code.

## BaaS (Brain as a Service)
> Forgé : 2026-03-15 | Domaine : vision
Modèle où le brain devient un service multi-tenant : `brain new` clone un brain pour un client, `brain sync` partage un workspace sprint. Prérequis : cockpit solo + SuperOAuth multi-tenant + OpenClaw.

## coach gate
> Forgé : 2026-03-20 | Domaine : session / coaching
Matrice de comportement du coach indexée par session type. 5 modes : **silencieux** (navigate, deploy, infra, urgence, audit — observation seule, pas de rapport), **standard** (work, debug — actif sur patterns), **engagé** (brain, brainstorm — challenger les décisions), **complet** (coach, capital — mentorat structuré), **copilote** (pilote — proactif). Spec : `agents/coach.md ## Gate par session type`.

## close decision tree
> Forgé : 2026-03-20 | Domaine : session / orchestration
Pseudo-code dans session-orchestrator qui détermine quels scribes fire et dans quel ordre pour chaque session type. Rend la close sequence auditable et déterministe — pas de logique implicite. Spec : `agents/session-orchestrator.md ## boot-summary`.

## cold start
> Forgé : 2026-03-15 | Domaine : session / onboarding
Deux sens : (1) Première session sur une nouvelle machine — `brain run` + MYSECRETS + CLAUDE.md → voir [Cold Start](cold-start). (2) Session sans checkpoint disponible → bootstrap complet ~2-3 min. Opposé : warm restart.

## BHP (Brain Hydration Protocol)
> Forgé : 2026-03-15 | Mis à jour : 2026-03-20 | Domaine : brain système
Protocole d'optimisation du contexte always-tier. Objectif : < 2 000 lignes au boot. Phase 1 = frontmatter propagé. Phase 2 = context-tier-split sur agents lourds (**terminé** — 16 agents splittés en boot-summary/detail). Spec : `wiki/context-loading.md`.

## boot-summary
> Forgé : 2026-03-20 | Domaine : BHP Phase 2
Section d'un agent contenant le minimum nécessaire pour COMMENCER à travailler : rôle (1 ligne), méthode/curseur, règles d'engagement, composition. ~20-30 lignes. Chargé en L1 par session-orchestrator quand l'agent est dans le manifest de la session. Opposé : `detail`.

## detail (agent)
> Forgé : 2026-03-20 | Domaine : BHP Phase 2
Section d'un agent contenant tout ce qu'il faut pour ALLER EN PROFONDEUR : activation, sources, périmètre complet, patterns/réflexes, anti-hallucination, ton, déclencheur, cycle de vie, changelog. Chargé en L3 sur invocation explicite ou quand l'agent est actif en session. Opposé : `boot-summary`.

## Brain Session Index (BSI)
> Forgé : 2026-03-14 | Domaine : session
Système de locking optimiste inter-sessions. Un claim par session (`claims/sess-YYYYMMDD-HHMM-slug.yml`). Les signaux dans `BRAIN-INDEX.md` permettent la communication inter-instances. Spec : `profil/bsi-spec.md`.

## Claim BSI
> Forgé : 2026-03-14 | Domaine : session
Fichier `claims/sess-YYYYMMDD-HHMM-<slug>.yml` — décrit une session ouverte (scope, instance, handoff_level, expires). Ouvert au boot par helloWorld, fermé au close par session-orchestrator.

## Checkpoint (Pattern 8)
> Forgé : 2026-03-15 | Domaine : session
Fichier `workspace/<sprint>/checkpoint.md` — capture l'état de travail en < 50 lignes pour permettre un warm restart sans bootstrap complet. Commande : `/checkpoint`. Spec : `toolkit/brain/checkpoint-pattern.md`.

## Cockpit
> Forgé : 2026-03-15 | Mis à jour : 2026-03-15 | Domaine : vision + mode
Deux sens liés : (1) Workspace v2 — couche humaine (`brief.md` + `kanban.md`) sur le workspace agent. (2) **Mode cockpit** (`brain-compose.yml`) — coach proactif qui route avant qu'on cherche + `kanban-scribe` actif automatiquement au wrap + `interprete` en écoute continue. Déclaré avec `mode: cockpit` ou `brain boot mode cockpit`.

## kanban-scribe
> Forgé : 2026-03-15 | Domaine : pipeline kanban
Agent déclenché au wrap. Lit le scope du claim BSI actif → met à jour `todo/<scope>.md` → détecte si la complétion était autonome (`🤖`) ou humaine (`✅`) → commite. Source de vérité pour la viabilité des agents : un item `🤖` = agent viable sur ce scope, candidat toolkit.

## context-tier
> Forgé : 2026-03-14 | Domaine : brain système
Niveau de chargement d'un fichier brain : `always` (chargé au boot), `warm` (chargé sur scope), `cold` (chargé sur invocation explicite), `hot` (chargé si domaine détecté).

## gate:human
> Forgé : 2026-03-14 | Domaine : orchestration / protocol
Point d'arrêt explicite dans un workflow ou un protocole agent — le brain suspend toute action et attend une réponse humaine avant de continuer. Format : `gate:human → "<message>"`. Non bypassable par l'agent lui-même. Script : `scripts/human-gate-ack.sh`. Opposé du nœud automatique.

## git-analyst
> Forgé : 2026-03-15 | Domaine : documentation / conception
Agent qui lit `git log` et produit une narration sémantique. Utilisé dans les sessions "docs par storytelling" : git-analyst → storyteller → doc agent. Transforme l'historique de commits en documentation vivante.

## Handoff Level
> Forgé : 2026-03-14 | Domaine : session
Profondeur de contexte chargé au boot : `NO` (Layer 0 seulement), `SEMI` (+ position), `SEMI+` (+ projets/todo scope), `FULL` (+ Layer 2 workspace). Déterminé par session_type × scope via `handoff-matrix.md`.

## health_score
> Forgé : 2026-03-14 | Domaine : métabolisme
Score 0-1 calculé par metabolism-scribe. Proxy de la "santé" d'une session : commits, todos fermés, agents chargés, context_peak. Seuil critique : < 0.80.

## KANBAN (Pattern 7 + pipeline)
> Forgé : 2026-03-15 | Mis à jour : 2026-03-15 | Domaine : orchestration + pipeline
Deux usages : (1) **Sprint setup** — fichier `workspace/<sprint>/kanban.md` généré depuis un todo structuré. Chaque carte = un agent + prompt autonome prêt à coller (Pattern 7). (2) **Pipeline de session** — les états `todo/<scope>.md` (`⬜→🔄→✅→🤖`) sont la source de vérité du workflow. `kanban-scribe` fait avancer les états au wrap. Un item `🤖` (validé-autonome) = signal de viabilité agent.

## Nœud humain / nœud automatique
> Forgé : 2026-03-15 | Domaine : pipeline kanban
Deux types de points de décision dans le workflow. **Nœud humain** : décision de valeur — "est-ce que ce scope mérite prod ?" — jamais de mécanique. **Nœud automatique** : `kanban-scribe` avance l'état sans intervention. Si une mécanique demande une décision humaine → agent mal conçu.

## validé-autonome (🤖) / validé-humain (✅)
> Forgé : 2026-03-15 | Domaine : pipeline kanban
États terminaux d'un item kanban. `✅` = complété avec intervention humaine au wrap. `🤖` = complété sans aucune intervention — l'agent a tourné seul du début à la fin. `🤖` = signal de viabilité : cet agent + scope peut entrer dans le toolkit.

## mode d'exécution (ADR-032)
> Forgé : 2026-03-18 | Domaine : orchestration
Propriété de la **session**, pas du workflow. Trois niveaux : **Mode 1 — manuel** (l'humain valide chaque step, gates systématiques), **Mode 2 — assisté** (l'humain valide les gates:human, steps techniques en automatique), **Mode 3 — swarm** (brain autonome, l'humain ne voit que les blocages critiques). Voir ADR-032 et **swarm-ready gate**.

## metabolism / metabolism-scribe
> Forgé : 2026-03-14 | Domaine : métabolisme
Agent de mesure de session. Calcule health_score, ratio use-brain/build-brain, context_peak, agents_loaded, durée, commits. Déclenché en step 1 du close protocol.

## overflow (de zone)
> Forgé : 2026-03-14 | Domaine : zones / orchestration
Demande d'un agent d'écrire hors de sa zone normale. Doit être soumis au `tech-lead` avec un format précis (agent demandeur, zone cible, fichier exact, raison métier, cas d'usage concret). Validé uniquement si la raison est métier — jamais pour convenance. Tracé par **cosign** dans le message de commit. Zone ABSOLU (KERNEL.md, CLAUDE.md) → humain requis, toujours.

## Pattern N
> Forgé : 2026-03-14+ | Domaine : orchestration
Convention récurrente validée en prod, capturée dans `profil/orchestration-patterns.md`. Patterns 1-8 actifs. Spec complète : `profil/orchestration-patterns.md`.

## Plateforme 2026
> Forgé : 2026-03-15 | Domaine : projet
Vision mini-game platform — SuperOAuth comme auth centrale, 4 tuiles (OriginsDigital, HP Quest, ClickerZ, TetaRdPG). Spec : `projets/plateforme-2026.md`.

## Position (brain)
> Forgé : 2026-03-14 | Domaine : session
Rôle contextuel chargé par session-orchestrator selon le session_type. Applique promote/suppress sur le contexte Layer 1. Ignoré si handoff_level = NO.

## ratio use-brain / build-brain
> Forgé : 2026-03-14 | Domaine : métabolisme
Métrique d'équilibre : sessions qui utilisent le brain (use-brain) vs sessions qui l'améliorent (build-brain). Cible : ≥ 0.60. Actuel : 0.33 🔴.

## Scribe Pattern
> Forgé : 2026-03-13 | Domaine : brain système (ADR-003)
Règle structurelle : un agent observateur ne documente jamais lui-même — il délègue toujours l'écriture à un scribe dédié. Sépare la capacité d'observation de la capacité d'écriture. Un agent peut être remplacé sans perdre la trace de sa production. Paires établies : coach → coach-scribe, session-orchestrator → metabolism-scribe, git-analyst → capital-scribe, content-orchestrator → content-scribe.

## swarm-ready gate
> Forgé : 2026-03-18 | Domaine : orchestration (ADR-032)
Quatre critères à satisfaire avant de passer un workflow en **Mode 3 — swarm** : (1) au moins un run en Mode 1 ✅, (2) au moins un run en Mode 2 ✅, (3) agents du workflow validés par `agent-review` ✅, (4) outputs structurés (rapports format strict) ✅. Sans ce gate, le mode swarm n'est pas autorisé.

## satellite
> Forgé : 2026-03-14 | Domaine : brain système
Repo Git indépendant versionné séparément du kernel brain. Liste : brain-profil, brain-todo, brain-toolkit, brain-agent-review, brain-progression. Ignoré dans le `.gitignore` du kernel.

## session-orchestrator
> Forgé : 2026-03-14 | Domaine : session
Agent propriétaire du cycle de vie de session (boot → work → close). Ne produit rien lui-même — orchestre les scribes et la séquence de fermeture. Spec : `agents/session-orchestrator.md`.

## Signal BSI
> Forgé : 2026-03-14 | Domaine : session
Message inter-sessions dans `BRAIN-INDEX.md ## Signals`. Types : READY_FOR_REVIEW, REVIEWED, BLOCKED_ON, HANDOFF, CHECKPOINT, INFO.

## SuperOAuth
> Forgé : 2026-03-13 | Domaine : projet
Auth centrale de la plateforme 2026. Express + JWT + Redis + MySQL. Provider OAuth universel multi-tenant. Tier 3 ✅ (2026-03-17). Repo : `~/Dev/Github/Super-OAuth/`.

## Toolkit-first
> Forgé : 2026-03-15 | Domaine : orchestration
Règle : avant chaque carte KANBAN, vérifier si un pattern toolkit/ existe. Si oui → utiliser. Si non → exécuter → toolkit-scribe capture en fin de carte. Accélérateur sprint-over-sprint.

## wrap
> Forgé : 2026-03-15 | Domaine : session
Fermeture propre d'une session. Déclenche la séquence close complète (checkpoint → metabolism → backlog → todo → wiki → scribe → coach → BSI). Alias : `fin`, `on wrappe`, `je ferme`. Sans wrap, le backlog n'est pas mis à jour et le VPS reste aveugle.

## warm restart
> Forgé : 2026-03-15 | Domaine : session
Reprise de session depuis un `checkpoint.md` sans bootstrap complet. < 30 sec vs 2-3 min cold bootstrap. Voir Pattern 8.
