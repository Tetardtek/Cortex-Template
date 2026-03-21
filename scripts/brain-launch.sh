#!/bin/bash
# brain-launch.sh — Affiche le prompt exact à coller dans une nouvelle fenêtre Claude Code
# Usage : bash scripts/brain-launch.sh <phase>
# Phases : 1 | 2a | 2b | 3 | 4 | 5
#          so3-1 | so3-2 | so3-3 | so3-4   (SuperOAuth Tier 3 — terrain test brain-hypervisor)

PHASE="${1:-}"

bar() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

header() {
  bar
  echo "  PROMPT — copier/coller dans la nouvelle fenêtre Claude Code"
  bar
  echo ""
}

footer() {
  echo ""
  bar
  echo ""
}

case "$PHASE" in

  1)
    header
    cat << 'EOF'
brain boot mode brain

Tâche : Brain API Key — Phase 1 (Schema & fondations)
Plan complet : todo/brain.md ## Brain API Key

À implémenter dans l'ordre :
1. brain-compose.yml : ajouter champ brain_api_key (optionnel) + feature_set schema
   feature_set : { tier: free|pro|full, agents: [], contexts: [], distillation: bool,
                   last_validated_at, expires_at, grace_until }
2. brain-compose.local.yml : documenter le cache feature_set (commentaires + exemple)
3. Créer wiki/brain-api-key.md : architecture complète, format clé, tiers

Format clé : bk_live_<32chars> (prod) / bk_test_<32chars> (dev, toujours tier free)
Tiers : free (sans clé) / pro (clé valide) / full (clé valide + distillation locale)

Checker todo/brain.md ## Brain API Key Phase 1 et cocher les items au fur et à mesure.
EOF
    footer
    ;;

  2a)
    header
    cat << 'EOF'
brain boot mode work/brain-api-key

Tâche : Brain API Key — Phase 2a (Serveur VPS — code)
Plan complet : todo/brain.md ## Brain API Key

À implémenter :
1. scripts/brain-key-server.py
   - POST /validate { key: "bk_live_xxx" } → { valid: bool, tier, features: [], expires_at }
   - GET  /health → 200 OK
   - Lit keys.yml (chemin via env BRAIN_KEYS_FILE)
   - Auth serveur : header X-Server-Secret (valeur dans env BRAIN_SERVER_SECRET)
   - ~50 lignes max — stdlib Python ou Flask minimal

2. scripts/brain-key-admin.sh
   - generate <owner> <tier: free|pro|full> [expires: YYYY-MM-DD]
   - revoke   <key_id>
   - list
   - check    <key>

Format keys.yml :
  keys:
    - key_id: bk_live_xxxx
      owner: alice
      tier: pro
      valid: true
      created_at: 2026-03-17
      expires_at: 2026-04-17

Checker todo/brain.md ## Phase 2 items 1+2 au fur et à mesure.
EOF
    footer
    ;;

  2b)
    header
    cat << 'EOF'
brain boot mode work/brain-api-key

Tâche : Brain API Key — Phase 2b (Deploy VPS)
Plan complet : todo/brain.md ## Brain API Key

VÉRIFICATION PRÉREQUIS — à faire EN PREMIER, avant toute autre action :
  1. [ -f scripts/brain-key-server.py ] → si absent : STOP IMMÉDIAT.
     Message : "brain-key-server.py manquant — phase 2a doit être terminée d'abord."
     Ne pas continuer, ne pas créer le fichier, ne pas déployer.
  2. [ -f scripts/brain-key-admin.sh ] → même règle.
  Si les deux existent → continuer.

À déployer sur le VPS :
1. Copier brain-key-server.py sur VPS (hors brain/ — ne jamais commiter keys.yml)
2. Service systemd brain-key-server
   - écoute 127.0.0.1:5099
   - env : BRAIN_KEYS_FILE=/home/<user>/brain-keys/keys.yml
            BRAIN_SERVER_SECRET=<depuis MYSECRETS>
3. nginx vhost : keys.brain.<domain> → proxy 127.0.0.1:5099 + SSL certbot
4. Monitor Uptime Kuma : GET keys.brain.<domain>/health
5. Test end-to-end : brain-key-admin.sh generate test@local free → check → validate

Checker todo/brain.md ## Phase 2 item Deploy VPS.
EOF
    footer
    ;;

  3)
    header
    cat << 'EOF'
brain boot mode brain

Tâche : Brain API Key — Phase 3 (Agent key-guardian)
Plan complet : todo/brain.md ## Brain API Key

Prérequis : curl https://keys.brain.<domain>/health répond 200 avant de commencer.

À créer : agents/key-guardian.md
  Rôle : valide Brain API Key au boot, écrit feature_set dans brain-compose.local.yml
  Activation : permanent, avant helloWorld si brain_api_key présent

  Flow :
    1. Lire brain_api_key dans brain-compose.local.yml
    2. Si absent → feature_set: { tier: free } silencieux, stop
    3. Si last_validated_at < 24h → utiliser cache, stop
    4. POST /validate → écrire feature_set complet
    5. Si VPS unreachable → grace period last_validated_at + 72h
       Si grace_until dépassé → downgrade tier: free + warning unique

  Règles absolues :
    - Jamais bloquer le boot (toujours fallback tier: free)
    - Jamais afficher la clé dans les logs ou le briefing

Checker todo/brain.md ## Phase 3 items au fur et à mesure.
EOF
    footer
    ;;

  4)
    header
    cat << 'EOF'
brain boot mode brain

Tâche : Brain API Key — Phase 4 (Intégration kernel)
Plan complet : todo/brain.md ## Brain API Key

Prérequis : key-guardian.md fonctionnel, feature_set écrit correctement au boot.

À modifier :
1. agents/helloWorld.md — fast boot path BHP :
   Après L0 : lire feature_set.tier depuis brain-compose.local.yml
   Si tier: free → skip agents/manifests avec tier_required: pro ou full
   Briefing ligne Instance : afficher "Tier: <tier>"

2. contexts/session-*.yml — ajouter champ tier_required :
   tier_required: free   → toujours chargé
   tier_required: pro    → skippé silencieusement si tier: free
   Passer en revue chaque manifest et classifier chaque agent L1

3. scripts/brain-setup.sh — étape 3.5 :
   "Brain API Key ? (Entrée = tier free)"
   Si clé → POST /validate immédiatement
   Si valide → écrire brain_api_key + feature_set dans brain-compose.local.yml
   Si invalide → warning + continuer en free

Checker todo/brain.md ## Phase 4 items au fur et à mesure.
EOF
    footer
    ;;

  5)
    header
    cat << 'EOF'
brain boot mode brain

Tâche : Brain API Key — Phase 5 (Sync & template)
Plan complet : todo/brain.md ## Brain API Key

Prérequis : Phases 1-4 complètes et testées end-to-end.

À faire :
1. scripts/sync-template.sh :
   - Vérifier que agents/key-guardian.md EST synced (pas exclu)
   - Ajouter dans SCRIPTS_EXCLUDE : brain-key-server.py brain-key-admin.sh
     (scripts privés owner — jamais dans le template public)

2. brain-template/README.md — section "Brain API Key" :
   - Comment obtenir une clé
   - Tiers et ce qu'ils débloquent
   - Renseigner dans brain-compose.local.yml

3. wiki/brain-api-key.md (si pas créé Phase 1) :
   Architecture complète, flow validation, grace period, révocation, tiers

4. bash scripts/sync-template.sh --dry → vérifier inclusions/exclusions
5. bash scripts/sync-template.sh      → sync effectif

Checker todo/brain.md ## Phase 5 — cocher tous les items.
EOF
    footer
    ;;

  shadow-audit)
    header
    cat << 'EOF'
brain boot mode brain

Tu es kernel-auditor en mode shadow — audit silencieux, pas de refactoring.
Tu observes, tu listes, tu notes. Tu ne modifies rien.

Scope : agents/ (63 fichiers .md)
Sources de référence à charger EN PREMIER :
  - brain/KERNEL.md         → zones, protection graduée, ownership
  - agents/AGENTS.md        → index de référence
  - brain/brain-constitution.md (si existe) → philosophie

━━ PASSES D'AUDIT (dans l'ordre) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PASSE 1 — Convention frontmatter (convention-guard)
  Pour chaque agent : vérifier que le frontmatter contient :
    name, type, context_tier, status, brain.scope, brain.export
  → Lister les agents avec frontmatter incomplet ou absent

PASSE 2 — Zone ownership (kernel-auditor)
  Vérifier que les agents kernel (scope:kernel) sont bien des agents
  de protocole — pas des specs métier ou des helpers projet
  → Lister les agents mal zonés

PASSE 3 — Cohérence index (dead-ref-scanner)
  Comparer agents/AGENTS.md avec ls agents/*.md
  → Agents présents dans AGENTS.md mais fichier absent
  → Agents présents en fichier mais absents de AGENTS.md

PASSE 4 — Agents forgés cette session (nouveaux — priorité)
  brain-hypervisor, kernel-orchestrator, bact-scribe,
  diagram-scribe, workflow-auditor
  → Frontmatter complet ? Zone correcte ? Liens cohérents ?

━━ FORMAT DE SORTIE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Rapport structuré :

  PASSE 1 — Frontmatter
    ✅ N agents conformes
    ⚠️  [agent] : champs manquants [liste]

  PASSE 2 — Zones
    ✅ N agents bien zonés
    ⚠️  [agent] : scope déclaré X, devrait être Y — raison

  PASSE 3 — Index
    ✅ Index cohérent / ⚠️  N écarts
    → [agent] manquant dans AGENTS.md
    → [agent] dans AGENTS.md sans fichier

  PASSE 4 — Nouveaux agents session
    [agent] : ✅ / ⚠️  [problème]

  SCORE GLOBAL : N/63 agents conformes (X%)
  ACTIONS RECOMMANDÉES (par priorité) :
    1. [action courte + fichier cible]
    2. ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Mode shadow : rapporter uniquement — aucune modification sans gate:human.
EOF
    footer
    ;;

  so3)
    header
    cat << 'EOF'
brain boot mode brain

Charge l'agent brain-hypervisor.
Plan : workflows/superoauth-tier3.yml

Tu es brain-hypervisor en mode supervision assistée.
Supervise la séquence SuperOAuth Tier 3 de bout en bout.

Sources à charger :
  - workflows/superoauth-tier3.yml       → plan de la séquence (4 steps)
  - brain/KERNEL.md                      → zones BSI (drift detection)
  - todo/super-oauth.md                  → contexte projet
  - todo/superoauth-tier3-sprint.md      → détail step 3

Contexte de départ :
  SuperOAuth Tier 2 livré ✅ 2026-03-16.
  16 vulnérabilités npm (11 high) bloquent le sprint Tier 3.
  CI/CD SSH i/o timeout — pipeline non-opérationnel.
  Objectif : livrer Tier 3 (per-tenant providers + client auth + audit log) en prod.

À faire en INIT :
  1. Lire le workflow, analyser les 4 steps
  2. Construire la carte zones : step N → zone BSI + type + risques
  3. Identifier les drifts de zone (code→deploy, deploy→code, code→deploy prod)
  4. Lister les gates humains obligatoires
  5. Annoncer : "Plan chargé — 4 steps, zones : [...], gates humains : [...]"

IMPORTANT — rôle de l'humain :
  Tu es le gate:human. À chaque gate, le superviseur s'arrête et attend ta décision.
  Pas de "continuer ?" implicite — le superviseur pose la question, tu réponds, il avance.
  Sans ta réponse explicite → le superviseur ne lance pas le step suivant.

Ensuite attendre instruction pour lancer step 1.
Pour chaque step : bash scripts/brain-launch.sh so3-N → brief à déléguer.
EOF
    footer
    ;;

  so3-1)
    header
    cat << 'EOF'
brain boot mode work/super-oauth

⚡ Terrain test brain-hypervisor — SuperOAuth Tier 3 / Step 1
Workflow : workflows/superoauth-tier3.yml ## step 1
Todo ref : todo/super-oauth.md ## vulnérabilités npm

Contexte :
  SuperOAuth Tier 2 livré ✅ 2026-03-16.
  npm audit détecte 16 vulnérabilités (11 high) — bloquantes avant Tier 3.
  Ce step doit être 0-vuln (high) avant de passer au step suivant.

Agents actifs : security · code-review · testing
Scope : github/Super-OAuth/ (package.json, package-lock.json, dépendances)

À faire :
1. cd github/Super-OAuth && npm audit — lister les 16 vulnérabilités par severity
2. npm audit fix — appliquer les fixes automatiques
3. npm audit fix --force — si des vulnérabilités high restent après step 2
   ⚠️  --force peut introduire des breaking changes → lancer la suite de tests après
4. npm test (ou npm run test) — vérifier 0 régression
5. Si breaking changes → fixer le code impacté avant de clore

Résultat attendu :
  ✅ ok      → 0 vulnérabilités high, tests verts → trigger:next (step so3-2)
  ⚠️  partial → vulnérabilités résiduelles (low/medium) → gate:human requis
  ❌ fail    → tests cassés après --force → signal BLOCKED_ON

Rapporter à brain-hypervisor (fenêtre superviseur) :
  "so3-1 ok / partial / fail — [résumé vulns résiduelles + état tests]"
  ⚠️  Ne pas lancer so3-2 directement — brain-hypervisor gère le gate code→deploy.
EOF
    footer
    ;;

  so3-2)
    header
    cat << 'EOF'
brain boot mode work/super-oauth

⚡ Terrain test brain-hypervisor — SuperOAuth Tier 3 / Step 2
Workflow : workflows/superoauth-tier3.yml ## step 2
Todo ref : projets/super-oauth.md ## GitHub Actions SSH i/o timeout

⚡ Gate drift détecté par brain-hypervisor : step 1 (code) → step 2 (deploy/CI-CD)
   Zone change : project → CI/CD infra — tu travailles sur les pipelines GitHub Actions.
   Confirmer avant de continuer (gate:human déjà validé si tu reçois ce brief).

Contexte :
  Les GitHub Actions plantent en SSH i/o timeout sur le VPS.
  CI/CD non-opérationnel = impossible de merger Tier 3 en prod de façon automatisée.
  Fix requis avant le sprint Tier 3 (step so3-3).

Agents actifs : ci-cd · vps
Scope : github/Super-OAuth/.github/workflows/

À diagnostiquer et corriger :
1. Lire les logs GitHub Actions — identifier où le timeout SSH se produit
2. Vérifier la config SSH dans les workflows (host, port, timeout settings)
3. Options courantes :
   - Augmenter ServerAliveInterval / ConnectTimeout dans ssh config
   - Utiliser appleboy/ssh-action avec timeout configuré
   - Vérifier que le VPS accepte les connexions SSH depuis GitHub runners (IP ranges)
   - KeepAlive côté serveur (/etc/ssh/sshd_config : ClientAliveInterval)
4. Tester le fix : push un commit test → vérifier que le pipeline passe

Résultat attendu :
  ✅ ok      → pipeline GitHub Actions vert → trigger:next (step so3-3)
  ⚠️  partial → CI/CD partiellement fixé (certains jobs) → gate:human requis
  ❌ fail    → fix non trouvé → gate:human → "skip ou bloquer le sprint ?"

Rapporter à brain-hypervisor (fenêtre superviseur) :
  "so3-2 ok / partial / fail — [résumé du fix appliqué ou raison du blocage]"
  ⚠️  Ne pas lancer so3-3 directement — brain-hypervisor gère le gate deploy→code.
EOF
    footer
    ;;

  so3-3)
    header
    cat << 'EOF'
brain boot mode work/super-oauth

⚡ Terrain test brain-hypervisor — SuperOAuth Tier 3 / Step 3
Workflow : workflows/superoauth-tier3.yml ## step 3
Todo ref : todo/superoauth-tier3-sprint.md

⚡ Gate drift détecté par brain-hypervisor : step 2 (deploy) → step 3 (code)
   Retour sur le code après infra — repositionner contexte développement.

Contexte :
  npm propre ✅ (step 1), CI/CD opérationnel ✅ (step 2).
  Sprint Tier 3 : per-tenant providers + client auth + audit log.
  Gate : 0-failures requis avant deploy (tous les tests doivent être verts).

Agents actifs : tech-lead · security · optimizer-db · build · testing
Scope : github/Super-OAuth/

À implémenter (ref : todo/superoauth-tier3-sprint.md) :
1. Per-tenant OAuth providers
   - Chaque tenant peut avoir ses propres providers configurés
   - Isolation stricte : un tenant ne peut pas accéder aux providers d'un autre
2. Client authentication
   - Auth client-to-client via SuperOAuth
   - Scopes et permissions par client
3. Audit log
   - Tracer tous les événements OAuth critiques (login, token issue, revoke, error)
   - Stockage structuré, queryable par tenant

Pour chaque feature :
  - Design DDD → implémentation → tests unitaires + intégration
  - Security review : injection, privilege escalation, token leakage
  - DB : vérifier indexes, éviter N+1 (optimizer-db)

Gate 0-failures : npm test → 0 failing tests requis avant de rapporter "ok".
  Si tests partiels → rapporter "partial" → gate:human.

Résultat attendu :
  ✅ ok      → 3 features livrées, 0 failing tests → trigger:next (step so3-4)
  ⚠️  partial → features partielles ou tests non-verts → gate:human requis
  ❌ fail    → blocage technique → signal BLOCKED_ON

Rapporter à brain-hypervisor (fenêtre superviseur) :
  "so3-3 ok / partial / fail — [features livrées, état tests, dette résiduelle]"
  ⚠️  Ne pas lancer so3-4 directement — gate:human prod obligatoire via brain-hypervisor.
EOF
    footer
    ;;

  so3-4)
    header
    cat << 'EOF'
brain boot mode work/super-oauth

⚡ Terrain test brain-hypervisor — SuperOAuth Tier 3 / Step 4
Workflow : workflows/superoauth-tier3.yml ## step 4

⚡ Gate humain obligatoire — deploy en production.
   brain-hypervisor a détecté : step 3 (code) → step 4 (deploy prod)
   Ce gate ne peut pas être automatisé — confirmation explicite requise avant ce brief.

Contexte :
  Tier 3 implémenté ✅ (step 3), tests verts ✅.
  Deploy : migration DB + build + pm2 reload sur VPS.

Agents actifs : vps · integrator
Scope : vps/github/Super-OAuth/

À faire dans l'ordre :
1. Vérifier l'état du VPS avant deploy :
   pm2 status, df -h, free -m → s'assurer que le VPS est sain
2. Pull les changements :
   cd github/Super-OAuth && git pull origin <branch>
3. Install deps :
   npm ci --production
4. Migration DB :
   npm run migration:run   (ou équivalent TypeORM)
   ⚠️  Vérifier que la migration est réversible (rollback plan)
5. Build :
   npm run build
6. Reload PM2 :
   pm2 reload super-oauth --update-env
7. Smoke tests :
   - GET /health → 200
   - Tester un flow OAuth end-to-end minimal
   - Vérifier les logs pm2 : pm2 logs super-oauth --lines 50

En cas d'erreur :
  - Migration fail → rollback migration → gate:human
  - App crash après reload → pm2 restart + git revert → gate:human
  - Logs d'erreur → analyser avant de continuer

Résultat attendu :
  ✅ ok      → SuperOAuth Tier 3 live ✅ → notify:"SuperOAuth Tier 3 live ✅"
  ⚠️  partial → deploy partiel → gate:human → "vérifier logs pm2"
  ❌ fail    → deploy échoué → gate:human → "rollback ?"

Rapporter à brain-hypervisor (fenêtre superviseur) :
  "so3-4 ok / partial / fail — [état deploy, smoke tests, logs pm2 summary]"
EOF
    footer
    ;;

  # ─── Clickerz Sprint 1 ────────────────────────────────────────────

  clk)
    header
    cat << 'EOF'
brain boot mode brain

Charge l'agent brain-hypervisor.
Plan : workflows/clickerz-sprint1.yml

Tu es brain-hypervisor en mode supervision assistée.
Supervise la séquence Clickerz Sprint 1 de bout en bout.

Sources à charger :
  - workflows/clickerz-sprint1.yml   → plan de la séquence (4 steps)
  - brain/KERNEL.md                  → zones BSI (drift detection)
  - todo/clickerz.md                 → contexte projet + Sprint 1 backlog

Contexte de départ :
  Nouveau projet Clickerz — Sprint 1.
  GDD minimal à définir avant toute ligne de code (game-designer en tête).
  Stack à choisir (Phaser / PixiJS / HTML5 vanilla ?).
  Objectif sprint : GDD + fondations + boucle progression + démo jouable.

À faire en INIT :
  1. Lire le workflow, analyser les 4 steps
  2. Construire la carte zones : step N → zone BSI + type + risques
  3. Identifier les drifts de zone et gates humains
  4. Annoncer : "Plan chargé — 4 steps, zones : [...], gates humains : [...]"

IMPORTANT :
  Tu es le gate:human. Chaque gate = arrêt physique — tu réponds, l'hyperviseur avance.
  Pour chaque step : bash scripts/brain-launch.sh clk-N → brief à déléguer.
EOF
    footer
    ;;

  clk-1)
    header
    cat << 'EOF'
brain boot mode work/clickerz

⚡ brain-hypervisor — Clickerz Sprint 1 / Step 1
Workflow : workflows/clickerz-sprint1.yml ## step 1
Todo ref : todo/clickerz.md ## Sprint 1

Agents : game-designer, product-strategist
Gate : bact (enrichissement contextuel avant délégation)

Objectif :
  Produire le GDD minimal de Clickerz :
  - Mécaniques core : ressource principale, source de production, upgrades
  - Boucle de progression : prestige / reset, courbe d'équilibrage indicative
  - Stack technique recommandée (Phaser 3 / PixiJS / vanilla TS — justifier)
  - Monétisation : cosmétiques only ? Battle pass ? Premium one-time ?
  - Intégrations optionnelles : Twitch, leaderboard, sauvegarde cloud

BACT à injecter :
  - toolkit/bact/patterns/game.yml ## gdd-first
  - toolkit/bact/patterns/game.yml ## economy-invariants
  - toolkit/bact/patterns/game.yml ## clicker-core-loop

Livrables attendus :
  - docs/GDD.md (ou wiki entry) avec les 5 sections ci-dessus
  - Recommandation stack argumentée (1 paragraphe)

Rapport de retour :
  "clk-1 ok / partial / fail — [résumé GDD produit ou raison du blocage]"
  ⚠️  Ne pas lancer clk-2 directement — brain-hypervisor gère le gate bact→code.
EOF
    footer
    ;;

  clk-2)
    header
    cat << 'EOF'
brain boot mode work/clickerz

⚡ brain-hypervisor — Clickerz Sprint 1 / Step 2
Workflow : workflows/clickerz-sprint1.yml ## step 2
Todo ref : todo/clickerz.md ## Sprint 1

Agents : tech-lead, build, testing
Gate : bact (stack + GDD injectés avant délégation)

Prérequis : GDD validé (clk-1 ok)

Objectif : Fondations techniques
  - Init projet avec la stack choisie (selon GDD)
  - Boucle core clicker : clic → +ressource, idle → +ressource/s
  - Premier upgrade : coût, multiplicateur, UI minimal
  - Tests unitaires sur la logique économique

BACT à injecter :
  - toolkit/bact/patterns/game.yml ## clicker-core-loop
  - toolkit/bact/patterns/backend.yml ## migration-first (si backend)
  - GDD.md ## mécaniques core

Rapport de retour :
  "clk-2 ok / partial / fail — [état fondations, tests, dette résiduelle]"
  ⚠️  Ne pas lancer clk-3 directement — gate bact via brain-hypervisor.
EOF
    footer
    ;;

  clk-3)
    header
    cat << 'EOF'
brain boot mode work/clickerz

⚡ brain-hypervisor — Clickerz Sprint 1 / Step 3
Workflow : workflows/clickerz-sprint1.yml ## step 3
Todo ref : todo/clickerz.md ## Sprint 1

Agents : game-designer, build, testing
Gate : bact

Prérequis : Fondations opérationnelles (clk-2 ok)

Objectif : Boucle de progression
  - Prestige : reset ressources + bonus permanent
  - Sauvegarde locale (localStorage ou IndexedDB)
  - Équilibrage initial : courbe ressources sur 10/30/60 min de jeu
  - UI de progression visible (milestone, indicateurs)

BACT à injecter :
  - toolkit/bact/patterns/game.yml ## progression-loops
  - toolkit/bact/patterns/game.yml ## economy-invariants
  - GDD.md ## boucle progression

Rapport de retour :
  "clk-3 ok / partial / fail — [prestige ok, save ok, équilibrage, dette]"
  ⚠️  Ne pas lancer clk-4 directement — gate:human prod obligatoire via brain-hypervisor.
EOF
    footer
    ;;

  clk-4)
    header
    cat << 'EOF'
brain boot mode work/clickerz

⚡ brain-hypervisor — Clickerz Sprint 1 / Step 4  [gate:human — deploy]
Workflow : workflows/clickerz-sprint1.yml ## step 4
Gate : human — CONFIRMATION EXPLICITE REQUISE avant tout deploy

Agents : vps, integrator
Prérequis : clk-3 ok + validation humaine explicite

Objectif : Deploy Sprint 1
  - Build prod (minification, assets)
  - Deploy VPS ou hébergement statique
  - Smoke test : chargement, clic de base, save/restore fonctionnel
  - PM2 ou serve statique selon stack

Rapport de retour :
  "clk-4 ok / partial / fail — [URL live, smoke tests, logs]"
EOF
    footer
    ;;

  # ─── OriginsDigital Sprint 3 ──────────────────────────────────────

  od)
    header
    cat << 'EOF'
brain boot mode brain

Charge l'agent brain-hypervisor.
Plan : workflows/origins-digital-sprint3.yml

Tu es brain-hypervisor en mode supervision assistée.
Supervise la séquence OriginsDigital Sprint 3 de bout en bout.

Sources à charger :
  - workflows/origins-digital-sprint3.yml  → plan de la séquence (4 steps)
  - brain/KERNEL.md                        → zones BSI (drift detection)
  - todo/origins-digital.md               → contexte projet + backlog Sprint 3

Contexte de départ :
  OriginsDigital v2 — Sprint 3.
  Pivot vision B2B : white-label + identité premium.
  Dépendance : SuperOAuth Tier 3 ✅ déjà livré (step 3 peut utiliser le SDK).
  Objectif sprint : Vision B2B documentée + refonte visuelle + SuperOAuth SDK frontend.

À faire en INIT :
  1. Lire le workflow, analyser les 4 steps
  2. Construire la carte zones + drifts
  3. Lister les gates humains
  4. Annoncer : "Plan chargé — 4 steps, zones : [...], gates humains : [...]"

IMPORTANT :
  Tu es le gate:human. Chaque gate = arrêt physique.
  Pour chaque step : bash scripts/brain-launch.sh od-N → brief à déléguer.
EOF
    footer
    ;;

  od-1)
    header
    cat << 'EOF'
brain boot mode work/originsdigital

⚡ brain-hypervisor — OriginsDigital Sprint 3 / Step 1
Workflow : workflows/origins-digital-sprint3.yml ## step 1
Todo ref : todo/origins-digital.md ## Vision B2B

Agents : coach, product-strategist, tech-lead
Gate : bact

Objectif : Brainstorm Vision B2B
  - Définir la cible B2B : studios indé, marques, agences ?
  - White-label : qu'est-ce qui est personnalisable (couleurs, logo, domaine) ?
  - Identité visuelle cible : premium, minimaliste, craft ?
  - Pricing model B2B : abonnement, per-seat, commission ?
  - Différenciateur vs concurrents (GameAnalytics, etc.)

BACT à injecter :
  - toolkit/bact/patterns/brain.yml ## hypervisor-init
  - SuperOAuth Tier 3 ✅ comme asset disponible (auth multi-tenant déjà livré)

Livrables attendus :
  - docs/vision-b2b.md : positionnement, cible, pricing, différenciateur
  - Brief refonte visuelle (→ input step 2)

Rapport de retour :
  "od-1 ok / partial / fail — [vision B2B documentée ou blocage]"
  ⚠️  Ne pas lancer od-2 directement — brain-hypervisor gère le gate.
EOF
    footer
    ;;

  od-2)
    header
    cat << 'EOF'
brain boot mode work/originsdigital

⚡ brain-hypervisor — OriginsDigital Sprint 3 / Step 2
Workflow : workflows/origins-digital-sprint3.yml ## step 2
Todo ref : todo/origins-digital.md ## Refonte visuelle

Agents : frontend-stack, code-review
Gate : bact

Prérequis : Vision B2B validée (od-1 ok)

Objectif : Refonte visuelle — identité premium
  - Appliquer le design brief issu de od-1
  - Tailwind config : palette, typographie, spacing premium
  - Composants clés : hero, pricing card, CTA, navbar
  - Dark mode natif si dans le brief
  - Mobile-first responsive

BACT à injecter :
  - toolkit/bact/patterns/brain.yml ## bact-tier-model
  - docs/vision-b2b.md ## identité visuelle cible

Rapport de retour :
  "od-2 ok / partial / fail — [composants livrés, Storybook/screenshot, dette]"
  ⚠️  Ne pas lancer od-3 directement — gate bact via brain-hypervisor.
EOF
    footer
    ;;

  od-3)
    header
    cat << 'EOF'
brain boot mode work/originsdigital

⚡ brain-hypervisor — OriginsDigital Sprint 3 / Step 3
Workflow : workflows/origins-digital-sprint3.yml ## step 3
Todo ref : todo/origins-digital.md ## SuperOAuth frontend

Agents : tech-lead, security, build, testing
Gate : bact

Prérequis : Refonte visuelle ok (od-2 ok) + SuperOAuth Tier 3 ✅ en prod

Objectif : Intégration SuperOAuth SDK frontend
  - Bouton "Se connecter avec SuperOAuth" (OAuth flow PKCE)
  - Redirect vers SuperOAuth, callback, gestion token
  - UI état connecté : avatar, menu user, logout
  - Gestion erreurs OAuth (token expiré, scope refusé)
  - Tests : flow login complet (mock ou test tenant)

BACT à injecter :
  - toolkit/bact/patterns/security.yml ## validate-then-verify
  - toolkit/bact/patterns/security.yml ## tenant-isolation-strict
  - SuperOAuth Tier 3 API : endpoint auth, scopes disponibles

Rapport de retour :
  "od-3 ok / partial / fail — [OAuth flow ok, tests, dette sécurité]"
  ⚠️  Ne pas lancer od-4 — gate:human prod obligatoire via brain-hypervisor.
EOF
    footer
    ;;

  od-4)
    header
    cat << 'EOF'
brain boot mode work/originsdigital

⚡ brain-hypervisor — OriginsDigital Sprint 3 / Step 4  [gate:human — deploy]
Workflow : workflows/origins-digital-sprint3.yml ## step 4
Gate : human — CONFIRMATION EXPLICITE REQUISE

Agents : vps, integrator
Prérequis : od-3 ok + validation humaine explicite

Objectif : Deploy Sprint 3
  - Build prod (Next.js build ou Vite build)
  - PM2 reload ou redeploy VPS
  - Smoke test : homepage, login OAuth, pages principales
  - Vérifier SSL + headers sécurité

Rapport de retour :
  "od-4 ok / partial / fail — [URL live, smoke tests, logs pm2]"
EOF
    footer
    ;;

  # ─── TetaRdPG Sprint 3 ────────────────────────────────────────────

  tpg)
    header
    cat << 'EOF'
brain boot mode brain

Charge l'agent brain-hypervisor.
Plan : workflows/tetardpg-sprint3.yml

Tu es brain-hypervisor en mode supervision assistée.
Supervise la séquence TetaRdPG Sprint 3 de bout en bout.

Sources à charger :
  - workflows/tetardpg-sprint3.yml   → plan de la séquence (4 steps)
  - brain/KERNEL.md                  → zones BSI (drift detection)
  - todo/tetardpg.md                 → contexte projet + backlog Sprint 3

Contexte de départ :
  TetaRdPG Sprint 3 — économie TetardCoin + Twitch integration.
  Brainstorm monétisation d'abord : valeurs Bits→TetardCoin à définir.
  Objectif sprint : économie implémentée + rewards Twitch temps réel.

À faire en INIT :
  1. Lire le workflow, analyser les 4 steps
  2. Construire la carte zones + drifts
  3. Lister les gates humains
  4. Annoncer : "Plan chargé — 4 steps, zones : [...], gates humains : [...]"

IMPORTANT :
  Tu es le gate:human. Chaque gate = arrêt physique.
  Pour chaque step : bash scripts/brain-launch.sh tpg-N → brief à déléguer.
EOF
    footer
    ;;

  tpg-1)
    header
    cat << 'EOF'
brain boot mode work/tetardpg

⚡ brain-hypervisor — TetaRdPG Sprint 3 / Step 1
Workflow : workflows/tetardpg-sprint3.yml ## step 1
Todo ref : todo/tetardpg.md ## Brainstorm Monétisation

Agents : game-designer, product-strategist
Gate : bact

Objectif : Brainstorm économie TetardCoin
  - Taux de conversion : combien de Bits = 1 TetardCoin ? (ex: 1 Bit = 1 TC, ou 100 Bits = 10 TC)
  - Rewards abonnés : bonus TC/mois selon tier (T1/T2/T3 Twitch)
  - Rewards bits : seuils de cheers (100 / 500 / 1000 / 5000 bits)
  - Utilisation TC : cosmétiques, pouvoirs temporaires, votes, etc.
  - Économie saine : pas d'inflation, plafond ou sink ?
  - Comparatif concurrents (StreamElements, Streamlabs points)

BACT à injecter :
  - toolkit/bact/patterns/game.yml ## economy-invariants
  - toolkit/bact/patterns/game.yml ## twitch-integration-pattern

Livrables attendus :
  - docs/economy-design.md : taux, seuils, tableau récap
  - Décision : sink économique (oui/non, quel mécanisme)

Rapport de retour :
  "tpg-1 ok / partial / fail — [valeurs définies ou blocage décisionnel]"
  ⚠️  Ne pas lancer tpg-2 directement — brain-hypervisor gère le gate.
EOF
    footer
    ;;

  tpg-2)
    header
    cat << 'EOF'
brain boot mode work/tetardpg

⚡ brain-hypervisor — TetaRdPG Sprint 3 / Step 2
Workflow : workflows/tetardpg-sprint3.yml ## step 2
Todo ref : todo/tetardpg.md ## Sprint 3

Agents : tech-lead, game-designer, build, testing
Gate : bact

Prérequis : Économie design validé (tpg-1 ok)

Objectif : Implémentation économie TetardCoin
  - Entité TetardCoin : balance par user, historique transactions
  - Service de conversion Bits → TC (selon taux défini en tpg-1)
  - Migration DB si nécessaire
  - API endpoints : balance, earn, spend, history
  - Tests unitaires sur la logique économique (invariants)

BACT à injecter :
  - toolkit/bact/patterns/game.yml ## economy-invariants
  - toolkit/bact/patterns/backend.yml ## migration-first
  - toolkit/bact/patterns/backend.yml ## typeorm-n-plus-one
  - docs/economy-design.md ## taux + seuils

Rapport de retour :
  "tpg-2 ok / partial / fail — [entités, migrations, API, tests]"
  ⚠️  Ne pas lancer tpg-3 directement — gate bact via brain-hypervisor.
EOF
    footer
    ;;

  tpg-3)
    header
    cat << 'EOF'
brain boot mode work/tetardpg

⚡ brain-hypervisor — TetaRdPG Sprint 3 / Step 3
Workflow : workflows/tetardpg-sprint3.yml ## step 3
Todo ref : todo/tetardpg.md ## Twitch

Agents : tech-lead, build, testing, integrator
Gate : bact

Prérequis : Économie TetardCoin ok (tpg-2 ok)

Objectif : Intégration Twitch — Bits events + chat rewards
  - Webhook Twitch ou EventSub : bits cheers en temps réel
  - Handler : cheer event → crédit TC selon taux
  - Chat rewards : channel points redemption → TC ou action jeu
  - Authentification Twitch OAuth (app token)
  - Gestion retry/idempotence (event reçu 2x → 1 seul crédit)
  - Tests : mock EventSub payload → vérifier crédit TC

BACT à injecter :
  - toolkit/bact/patterns/game.yml ## twitch-integration-pattern
  - toolkit/bact/patterns/security.yml ## validate-then-verify (webhook signature)
  - toolkit/bact/patterns/backend.yml ## production-ready-defaults

Rapport de retour :
  "tpg-3 ok / partial / fail — [EventSub ok, idempotence ok, tests, dette]"
  ⚠️  Ne pas lancer tpg-4 — gate:human prod obligatoire via brain-hypervisor.
EOF
    footer
    ;;

  tpg-4)
    header
    cat << 'EOF'
brain boot mode work/tetardpg

⚡ brain-hypervisor — TetaRdPG Sprint 3 / Step 4  [gate:human — deploy]
Workflow : workflows/tetardpg-sprint3.yml ## step 4
Gate : human — CONFIRMATION EXPLICITE REQUISE

Agents : vps, integrator
Prérequis : tpg-3 ok + validation humaine explicite

Objectif : Deploy Sprint 3
  - Migration DB (TetardCoin balance + transactions)
  - PM2 reload
  - Smoke test : bits cheer test → TC crédit visible
  - Vérifier webhook Twitch actif en prod (EventSub subscription)

Rapport de retour :
  "tpg-4 ok / partial / fail — [deploy ok, webhook actif, smoke tests, logs pm2]"
EOF
    footer
    ;;

  hypervisor)
    header
    cat << 'EOF'
brain boot mode coach-as-hypervisor

Tu es le coach en mode hyperviseur. Tu exécutes le protocole brain-hypervisor directement
dans cette fenêtre — pas de fenêtre séparée. Tu spawnes les agents delegates via l'Agent tool
en background. L'humain ne voit que les gates:human.

Charge : agents/helloWorld.md + agents/coach.md + brain-hypervisor.md

━━━ STACK PROBE — avant toute délégation ━━━
Lire decisions/infra-registry.yml et vérifier pour CHAQUE projet du sprint :
  □ DB type dans app.module.ts === infra-registry.db.prod.engine ?
  □ Driver installé (mysql2 / pg selon engine) ?
  □ tsconfig.build.json exclut frontend/ et archive/ ?
  □ .env existe sur le VPS ? (sinon : créer avant build)
  □ pm2 app existe ? (sinon : pm2 start, pas reload)

━━━ CROSS-DEPS SCAN — avant toute délégation ━━━
Pour chaque projet du sprint, vérifier :
  □ Dépendance vers un autre projet du stack ? (auth partagée, API commune)
  □ Séquençage nécessaire ? (A doit être live avant B)
  □ Si dépendance → gate:human.REVIEW avant de déléguer

━━━ SECRETS INJECTION — avant spawn subagent ━━━
  □ Charger secrets-injector pour chaque projet qui touche VPS/DB/API
  □ Injecter credentials minimaux dans le prompt — jamais "lis MYSECRETS"

━━━ FORMAT GATE:HUMAN ━━━
  🔴 gate:human.DECISION   — choix archi, go/no-go prod
  🟡 gate:human.REVIEW     — valider output agent avant suite
  🔵 gate:human.DEFINE     — connaissance structurelle (auto-résout si dans infra-registry)
  ⚫ gate:human.CREDENTIALS — secrets manquants (bloqueant)

━━━ FORMAT RAPPORT AGENT ━━━
  "<projet>-<step> ok / partial / fail — [résumé 1 ligne]"
  partial → détailler ce qui manque
  fail → cause + action corrective proposée

━━━ APRÈS CHAQUE STEP ━━━
  Synthèse : N ok / M partial / P fail
  Si tout ok → déclencher step suivant automatiquement
  Si partial/fail → gate:human.REVIEW

Projets actifs ce sprint : [À COMPLÉTER avant de coller ce prompt]
EOF
    footer
    ;;

  *)
    echo ""
    echo "Usage : bash scripts/brain-launch.sh <phase>"
    echo ""
    echo "Phases disponibles :"
    echo "  Brain API Key :"
    echo "  1     — Schema & fondations (brain-compose + wiki)"
    echo "  2a    — Serveur VPS code (brain-key-server.py + brain-key-admin.sh)"
    echo "  2b    — Deploy VPS (systemd + nginx + SSL + Kuma)"
    echo "  3     — Agent key-guardian"
    echo "  4     — Intégration kernel (helloWorld + manifests + brain-setup)"
    echo "  5     — Sync & template"
    echo ""
    echo "  SuperOAuth Tier 3 (terrain test brain-hypervisor) :"
    echo "  shadow-audit — Audit silencieux agents/ (kernel-auditor mode shadow)"
    echo "  hypervisor — Coach-as-hypervisor mode (multi-workflow parallèle)"
  echo ""
  echo "  SuperOAuth Tier 3 (terrain test brain-hypervisor) :"
  echo "  so3   — INIT brain-hypervisor (charger le workflow complet)"
    echo "  so3-1 — npm audit fix (16 vulns, 11 high)"
    echo "  so3-2 — Fix CI/CD SSH i/o timeout [gate:human — drift code→deploy]"
    echo "  so3-3 — Tier 3 sprint (per-tenant providers + client auth + audit log)"
    echo "  so3-4 — Deploy prod (migration + pm2 reload) [gate:human — prod]"
    echo ""
    echo "  Clickerz Sprint 1 :"
    echo "  clk   — INIT brain-hypervisor (charger le workflow)"
    echo "  clk-1 — GDD minimal (game-designer)"
    echo "  clk-2 — Fondations techniques (stack + core clicker)"
    echo "  clk-3 — Boucle progression (prestige + sauvegarde)"
    echo "  clk-4 — Deploy Sprint 1 [gate:human — prod]"
    echo ""
    echo "  OriginsDigital Sprint 3 :"
    echo "  od    — INIT brain-hypervisor (charger le workflow)"
    echo "  od-1  — Brainstorm Vision B2B"
    echo "  od-2  — Refonte visuelle (Tailwind + design brief)"
    echo "  od-3  — SuperOAuth SDK frontend (OAuth PKCE)"
    echo "  od-4  — Deploy Sprint 3 [gate:human — prod]"
    echo ""
    echo "  TetaRdPG Sprint 3 :"
    echo "  tpg   — INIT brain-hypervisor (charger le workflow)"
    echo "  tpg-1 — Brainstorm économie TetardCoin (Bits→TC)"
    echo "  tpg-2 — Implémentation économie (entités + API)"
    echo "  tpg-3 — Intégration Twitch (EventSub + rewards)"
    echo "  tpg-4 — Deploy Sprint 3 [gate:human — prod]"
    echo ""
    ;;
esac
