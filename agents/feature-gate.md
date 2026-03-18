---
name: feature-gate
type: protocol
context_tier: always
status: draft
brain:
  version:   1
  type:      protocol
  scope:     kernel
  owner:     human
  writer:    human
  lifecycle: permanent
  read:      full
  triggers:  [boot, tier-change, feature-check]
  export:    true
  ipc:
    receives_from: [human, helloWorld]
    sends_to:      [human]
    zone_access:   [kernel]
    signals:       [RETURN, ESCALATE]
---

# Agent : feature-gate

> Dernière validation : 2026-03-17
> Domaine : Coupure de features au boot — PayByFeature runtime

---

## boot-summary

Lit `feature_set` depuis `brain-compose.local.yml` après key-guardian.
Initialise l'état runtime : chaque feature est `enabled` ou `disabled` selon le tier.
Expose `isEnabled(feature)` — tous les agents l'interrogent avant d'activer une capacité.
Sans feature-gate, le tier est déclaratif mais jamais enforced.

```
Règles non-négociables :
Jamais bloquer  : si feature_set absent → tier: free silencieux (jamais throw)
Toujours après  : key-guardian doit avoir tourné avant feature-gate
Interface simple : isEnabled(feature) → true/false — rien d'autre
Pas de logique  : feature-gate lit et expose — jamais de décision métier
```

---

## Position dans le boot

```
boot
  1. secrets-guardian  → MYSECRETS disponible + unlocked
  2. key-guardian      → valide clé → écrit feature_set dans brain-compose.local.yml
  3. feature-gate      → lit feature_set → initialise état runtime ← ICI
  4. helloWorld        → charge SEULEMENT les agents/manifests enabled
  5. bact-scribe       → reçoit tier → enrichit en conséquence (pro/full)
  6. draw-gateway      → vérifie tier:full avant d'activer les actions (futur)
```

---

## Mapping tier → features

```yaml
tier: free
  enabled:
    - kernel.boot          # helloWorld, secrets-guardian, key-guardian
    - kernel.agents        # tous les agents métier de base
    - workflow.manual      # brain-launch.sh + supervision assistée
    - diagram.readonly     # draw satellite read-only
  disabled:
    - bact.enrichment      # pas d'enrichissement contextuel
    - workflow.orchestrated # kernel-orchestrator autonome
    - diagram.interactive  # annotations Excalidraw
    - diagram.actions      # gate:human cliquable
    - distillation         # distillation locale

tier: pro
  enabled:
    - tout ce que free active
    - bact.enrichment      # L0 + toolkit/<domain>/ + manifests L1
    - workflow.orchestrated # kernel-orchestrator semi-auto
    - diagram.interactive  # annotations capturées par diagram-scribe
    - supervisor.project   # Brain Supervisor N + BACT
  disabled:
    - bact.rag             # RAG local (full seulement)
    - diagram.actions      # gate:human cliquable (full seulement)
    - distillation         # distillation locale (full seulement)

tier: full
  enabled:
    - tout ce que pro active
    - bact.rag             # L0 + L1 + L2 + RAG local
    - diagram.actions      # gate:human cliquable → signal BSI direct
    - distillation         # distillation locale
```

---

## Interface

```
isEnabled("bact.enrichment")    → true si tier: pro ou full
isEnabled("diagram.actions")    → true si tier: full uniquement
isEnabled("workflow.manual")    → true toujours (free minimum)
isEnabled("distillation")       → true si tier: full
```

---

## Initialisation

```
INIT :
  1. Lire brain-compose.local.yml → feature_set.tier
     Si absent ou illisible → tier: free (jamais bloquer)
  2. Construire la map enabled/disabled depuis le mapping tier ci-dessus
  3. Logger silencieusement : "feature-gate: tier=<X>, N features enabled"
     (pas de liste — juste le tier et le count)
  4. Exposer isEnabled() pour le reste du boot

CHECK (à la demande) :
  isEnabled(feature) → lire la map → retourner true/false
  Si feature inconnue → false (défaut sécurisé)
```

---

## Intégration helloWorld

```
helloWorld boot L1 — chargement manifests :
  Pour chaque agent dans le manifest :
    Si agent.tier_required défini :
      → feature-gate.isEnabled("tier_required") avant de charger
      → false → skip silencieux (pas d'erreur, pas de message)
    Sinon → charger (tier: free par défaut)
```

---

## Sources à charger

| Fichier | Pourquoi |
|---------|----------|
| `brain-compose.local.yml` | Tier actif → feature_set |
| `agents/helloWorld.md` | Boot path à modifier pour interroger feature-gate |

---

## Scripts

```bash
# Vérifier l'état feature-gate (debug)
bash scripts/feature-gate-status.sh
# → affiche : tier + features enabled/disabled

# À forger (post-validation)
```

---

## Liens

- S'active après  : `key-guardian` (écrit feature_set)
- Utilisé par     : `helloWorld` (boot manifests) + `bact-scribe` (tier enrichment) + `draw-gateway` (tier:full check)
- → voir aussi    : `key-guardian` + `Brain API Key` + `brain-compose.local.yml`

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-17 | Création — mapping tiers, interface isEnabled(), position boot, intégration helloWorld |
