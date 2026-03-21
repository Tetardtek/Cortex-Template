#!/bin/bash
# feature-gate-status.sh — État du feature-gate (tier actif + features enabled/disabled)
# Lecture seule. Aucune écriture.
#
# Usage :
#   bash scripts/feature-gate-status.sh

set -uo pipefail

BRAIN_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
COMPOSE_FILE="$BRAIN_ROOT/brain-compose.local.yml"

# --- Lire le tier actif ---
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
    tier=$(grep "^\s*tier:" "$COMPOSE_FILE" | head -1 | awk '{print $NF}' | tr -d "'\"")
  fi
  echo "${tier:-free}"
}

_tier_level() {
  case "$1" in
    free) echo 0 ;;
    pro)  echo 1 ;;
    full) echo 2 ;;
    *)    echo 0 ;;
  esac
}

# --- Mapping complet feature → tier minimum ---
declare -A FEATURE_MIN=(
  [kernel.boot]="free"
  [kernel.agents]="free"
  [workflow.manual]="free"
  [diagram.readonly]="free"
  [bact.enrichment]="pro"
  [workflow.orchestrated]="pro"
  [diagram.interactive]="pro"
  [supervisor.project]="pro"
  [bact.rag]="full"
  [diagram.actions]="full"
  [distillation]="full"
)

# Ordre d'affichage
FEATURE_ORDER=(
  kernel.boot kernel.agents workflow.manual diagram.readonly
  bact.enrichment workflow.orchestrated diagram.interactive supervisor.project
  bact.rag diagram.actions distillation
)

# --- Main ---
TIER=$(_get_tier)
LEVEL=$(_tier_level "$TIER")

echo "feature-gate — tier: $TIER"
echo "──────────────────────────────────────────────"

ENABLED_LIST=()
DISABLED_LIST=()

for feature in "${FEATURE_ORDER[@]}"; do
  min_tier="${FEATURE_MIN[$feature]}"
  required=$(_tier_level "$min_tier")
  if [ "$LEVEL" -ge "$required" ]; then
    ENABLED_LIST+=("$feature")
  else
    DISABLED_LIST+=("$feature  (requires: $min_tier)")
  fi
done

if [ "${#ENABLED_LIST[@]}" -gt 0 ]; then
  echo "  ✅ Enabled"
  for f in "${ENABLED_LIST[@]}"; do
    echo "    + $f"
  done
fi

if [ "${#DISABLED_LIST[@]}" -gt 0 ]; then
  echo "  ❌ Disabled"
  for f in "${DISABLED_LIST[@]}"; do
    echo "    - $f"
  done
fi

echo "──────────────────────────────────────────────"
echo "  ${#ENABLED_LIST[@]} enabled  /  ${#DISABLED_LIST[@]} disabled"
