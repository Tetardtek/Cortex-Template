#!/bin/bash
# feature-gate-check.sh — Vérifie si une feature ou un tier est activé
# Returns 0 (enabled) / 1 (disabled)
#
# Usage :
#   bash scripts/feature-gate-check.sh bact.enrichment
#   bash scripts/feature-gate-check.sh pro              # tier level check
#   if bash scripts/feature-gate-check.sh diagram.actions; then ...

set -uo pipefail

BRAIN_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
COMPOSE_FILE="$BRAIN_ROOT/brain-compose.local.yml"

# --- Lire le tier actif depuis brain-compose.local.yml ---
_get_tier() {
  [ -f "$COMPOSE_FILE" ] || { echo "free"; return; }
  local tier="free"
  if command -v python3 &>/dev/null && python3 -c "import yaml" &>/dev/null 2>&1; then
    tier=$(BRAIN_COMPOSE="$COMPOSE_FILE" python3 - <<'PYEOF' 2>/dev/null
import yaml, os, sys
path = os.environ.get('BRAIN_COMPOSE', '')
try:
    with open(path) as f:
        data = yaml.safe_load(f)
    instances = data.get('instances', {})
    for name, inst in instances.items():
        if inst.get('active'):
            print(inst.get('feature_set', {}).get('tier', 'free'))
            sys.exit(0)
except Exception:
    pass
print('free')
PYEOF
)
  else
    # Fallback grep — fonctionne sur brain-compose.local.yml standard
    tier=$(grep "^\s*tier:" "$COMPOSE_FILE" | head -1 | awk '{print $NF}' | tr -d "'\"")
  fi
  echo "${tier:-free}"
}

# --- Niveau numérique du tier ---
_tier_level() {
  case "$1" in
    free)     echo 0 ;;
    featured) echo 1 ;;
    pro)      echo 2 ;;
    full)     echo 3 ;;
    *)        echo 0 ;;
  esac
}

# --- Tier minimum requis par feature ---
_feature_min_tier() {
  case "$1" in
    # tier: free — toujours enabled
    kernel.boot|kernel.agents|workflow.manual|diagram.readonly)
      echo "free" ;;
    # tier: featured — coaching + distillation RAG
    coach.full|distillation.rag|progression.tracking)
      echo "featured" ;;
    # tier: pro — outils metier
    bact.enrichment|workflow.orchestrated|diagram.interactive|supervisor.project)
      echo "pro" ;;
    # tier: full — kernel + supervision
    bact.rag|diagram.actions|kernel.write)
      echo "full" ;;
    # feature inconnue → false (défaut sécurisé)
    *)
      echo "unknown" ;;
  esac
}

# --- Main ---
FEATURE="${1:-}"
if [ -z "$FEATURE" ]; then
  echo "Usage: feature-gate-check.sh <feature|tier>" >&2
  exit 2
fi

CURRENT_TIER=$(_get_tier)
CURRENT_LEVEL=$(_tier_level "$CURRENT_TIER")

# Cas 1 : argument est un tier name (free/featured/pro/full)
case "$FEATURE" in
  free|featured|pro|full)
    REQUIRED_LEVEL=$(_tier_level "$FEATURE")
    [ "$CURRENT_LEVEL" -ge "$REQUIRED_LEVEL" ] && exit 0 || exit 1
    ;;
esac

# Cas 2 : argument est un feature name
MIN_TIER=$(_feature_min_tier "$FEATURE")
if [ "$MIN_TIER" = "unknown" ]; then
  exit 1
fi
REQUIRED_LEVEL=$(_tier_level "$MIN_TIER")
[ "$CURRENT_LEVEL" -ge "$REQUIRED_LEVEL" ] && exit 0 || exit 1
