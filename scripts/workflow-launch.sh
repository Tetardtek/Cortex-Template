#!/bin/bash
# workflow-launch.sh — Lance le prochain step d'un workflow thématique
# Lit le workflow YAML, trouve le step à lancer, génère le claim BSI correspondant.
#
# Usage :
#   bash scripts/workflow-launch.sh <workflow.yml>              # step 1 (ou prochain)
#   bash scripts/workflow-launch.sh <workflow.yml> --step N     # step spécifique
#   bash scripts/workflow-launch.sh <workflow.yml> --status     # état de la chaîne
#
# Le claim généré est affiché + écrit dans claims/ — l'humain lance le satellite.
# (Futur : kernel-orchestrator lancera automatiquement — BSI-v3-9)

set -euo pipefail

BRAIN_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"

WORKFLOW_FILE="${1:-}"
MODE="launch"
TARGET_STEP=""

# --- Parse args ---
shift || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --step)   TARGET_STEP="$2"; shift 2 ;;
    --status) MODE="status"; shift ;;
    *)        shift ;;
  esac
done

if [ -z "$WORKFLOW_FILE" ]; then
  echo "Usage : bash scripts/workflow-launch.sh <workflow.yml> [--step N] [--status]"
  echo "Workflows disponibles :"
  ls "$BRAIN_ROOT/workflows/"*.yml 2>/dev/null | grep -v "_template" \
    | sed "s|$BRAIN_ROOT/workflows/||" | sed 's/^/  /'
  exit 1
fi

# Résolution chemin workflow
if [ ! -f "$WORKFLOW_FILE" ]; then
  WORKFLOW_FILE="$BRAIN_ROOT/workflows/$WORKFLOW_FILE"
fi
if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "🚨 Workflow introuvable : $WORKFLOW_FILE"
  exit 1
fi

# --- Lecture du workflow (parser YAML minimal) ---
THEME_NAME=$(grep '^name:' "$WORKFLOW_FILE" | sed 's/name: *//' | tr -d '"')
THEME_BRANCH=$(grep '^branch:' "$WORKFLOW_FILE" | sed 's/branch: *//' | tr -d '"')

echo "📋 Workflow : $THEME_NAME"
echo "   Branche  : $THEME_BRANCH"
echo ""

# --- Mode status : afficher l'état de la chaîne ---
if [ "$MODE" = "status" ]; then
  echo "État des claims pour ce thème :"
  echo ""
  # Trouver les claims qui référencent ce theme_branch
  for claim in "$BRAIN_ROOT/claims/"sess-*.yml; do
    if grep -q "theme_branch: $THEME_BRANCH" "$claim" 2>/dev/null; then
      sess_id=$(grep '^sess_id:' "$claim" | sed 's/sess_id: *//')
      status=$(grep '^status:' "$claim" | sed 's/status: *//')
      step=$(grep '^workflow_step:' "$claim" 2>/dev/null | sed 's/workflow_step: *//' || echo "?")
      result_status=$(grep 'status:' "$claim" | grep -v '^status:' | head -1 | sed 's/.*status: *//' || echo "-")
      echo "  Step $step — $sess_id [$status] result:$result_status"
    fi
  done
  exit 0
fi

# --- Trouver le prochain step à lancer ---
# Lire les steps depuis le workflow
STEPS=()
STEP_TYPES=()
STEP_SCOPES=()
STEP_ANGLES=()
STEP_GATES=()

current_step=""
current_type=""
current_scope=""
current_angle=""
current_gate=""

while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*-[[:space:]]step:[[:space:]]*([0-9]+) ]]; then
    # Sauvegarder le step précédent
    if [ -n "$current_step" ]; then
      STEPS+=("$current_step")
      STEP_TYPES+=("$current_type")
      STEP_SCOPES+=("$current_scope")
      STEP_ANGLES+=("$current_angle")
      STEP_GATES+=("$current_gate")
    fi
    current_step="${BASH_REMATCH[1]}"
    current_type=""
    current_scope=""
    current_angle=""
    current_gate=""
  elif [[ "$line" =~ ^[[:space:]]+type:[[:space:]]*(.+) ]]; then
    current_type="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]+scope:[[:space:]]*(.+) ]]; then
    current_scope="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]+story_angle:[[:space:]]*\"(.+)\" ]]; then
    current_angle="${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^[[:space:]]+gate:[[:space:]]*(.+) ]]; then
    current_gate="${BASH_REMATCH[1]}"
  fi
done < "$WORKFLOW_FILE"

# Sauvegarder le dernier step
if [ -n "$current_step" ]; then
  STEPS+=("$current_step")
  STEP_TYPES+=("$current_type")
  STEP_SCOPES+=("$current_scope")
  STEP_ANGLES+=("$current_angle")
  STEP_GATES+=("$current_gate")
fi

TOTAL_STEPS=${#STEPS[@]}

if [ "$TOTAL_STEPS" -eq 0 ]; then
  echo "🚨 Aucun step trouvé dans le workflow."
  exit 1
fi

# Déterminer le step cible
if [ -n "$TARGET_STEP" ]; then
  STEP_IDX=$((TARGET_STEP - 1))
else
  # Trouver le dernier step complété via les claims
  LAST_DONE=0
  for claim in "$BRAIN_ROOT/claims/"sess-*.yml; do
    if grep -q "theme_branch: $THEME_BRANCH" "$claim" 2>/dev/null; then
      if grep -q "status: closed" "$claim" 2>/dev/null; then
        claim_step=$(grep '^workflow_step:' "$claim" 2>/dev/null \
          | sed 's/workflow_step: *//' || echo "0")
        if [ "$claim_step" -gt "$LAST_DONE" ] 2>/dev/null; then
          LAST_DONE="$claim_step"
        fi
      fi
    fi
  done
  STEP_IDX=$LAST_DONE
fi

if [ "$STEP_IDX" -ge "$TOTAL_STEPS" ]; then
  echo "✅ Workflow terminé — tous les steps complétés ($TOTAL_STEPS/$TOTAL_STEPS)"
  exit 0
fi

# --- Construire le claim pour ce step ---
STEP_NUM="${STEPS[$STEP_IDX]}"
STEP_TYPE="${STEP_TYPES[$STEP_IDX]}"
STEP_SCOPE="${STEP_SCOPES[$STEP_IDX]}"
STEP_ANGLE="${STEP_ANGLES[$STEP_IDX]}"
STEP_GATE="${STEP_GATES[$STEP_IDX]}"

# Déterminer le next step pour on_done
NEXT_IDX=$((STEP_IDX + 1))
ON_DONE=""
ON_FAIL="signal  → BLOCKED_ON pilote"

if [ "$NEXT_IDX" -lt "$TOTAL_STEPS" ]; then
  NEXT_TYPE="${STEP_TYPES[$NEXT_IDX]}"
  NEXT_SCOPE="${STEP_SCOPES[$NEXT_IDX]}"
  NEXT_GATE="${STEP_GATES[$NEXT_IDX]}"

  if [ "$NEXT_GATE" = "human" ]; then
    ON_DONE="gate:human → \"Step $((NEXT_IDX+1)) prêt ($NEXT_TYPE:$NEXT_SCOPE) — lancer ?\""
  else
    ON_DONE="trigger → type:$NEXT_TYPE scope:$NEXT_SCOPE"
  fi
else
  ON_DONE="notify  → pilote  # dernier step — chaîne terminée"
fi

# Gestion gate sur le step courant
if [ "$STEP_GATE" = "human" ]; then
  echo "⏸ GATE HUMAN requis avant ce step."
  echo "   Confirmer avant de lancer le satellite."
  echo ""
fi

# Générer le sess_id
DATETIME=$(date +%Y%m%d-%H%M)
SCOPE_SLUG=$(echo "$STEP_SCOPE" | tr '/' '-' | sed 's/-$//' | tr '[:upper:]' '[:lower:]')
SESS_ID="sess-${DATETIME}-${THEME_NAME}-step${STEP_NUM}"
CLAIM_FILE="$BRAIN_ROOT/claims/${SESS_ID}.yml"

# Écrire le claim
cat > "$CLAIM_FILE" << EOF
sess_id:          $SESS_ID
type:             satellite
scope:            $STEP_SCOPE
agent:            satellite-boot
status:           open
opened_at:        "$(date +%Y-%m-%dT%H:%M)"
handoff_level:    0
story_angle:      "$STEP_ANGLE"
satellite_type:   $STEP_TYPE
satellite_level:  leaf
parent_satellite: ~
theme_branch:     $THEME_BRANCH
workflow:         $THEME_NAME
workflow_step:    $STEP_NUM
on_done:          $ON_DONE
on_fail:          $ON_FAIL
EOF

echo "✅ Claim généré : claims/${SESS_ID}.yml"
echo ""
echo "  Step        : $STEP_NUM / $TOTAL_STEPS"
echo "  Type        : $STEP_TYPE"
echo "  Scope       : $STEP_SCOPE"
echo "  Tâche       : $STEP_ANGLE"
if [ -n "$STEP_GATE" ]; then
echo "  Gate        : $STEP_GATE"
fi
echo "  On done     : $ON_DONE"
echo "  On fail     : $ON_FAIL"
echo ""
echo "→ Commiter le claim :"
echo "  git add claims/${SESS_ID}.yml && git commit -m \"bsi: open satellite ${SESS_ID}\""
