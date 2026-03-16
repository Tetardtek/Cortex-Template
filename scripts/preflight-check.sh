#!/bin/bash
# preflight-check.sh — BSI-v3-8 Pre-flight check
# Valide les 6 conditions avant qu'un satellite commence à écrire.
# Soft-lock kernel : tout satellite hors scope kernel est bloqué sur zone:kernel.
#
# Usage :
#   preflight-check.sh check  <sess_id> <filepath>  → 6 checks, exit 0 = go
#   preflight-check.sh fail   <sess_id>             → enregistre un échec (circuit breaker)
#   preflight-check.sh reset  <sess_id>             → reset fail counter après succès
#   preflight-check.sh status <sess_id>             → état circuit breaker
#
# Exit codes (check) :
#   0 = go — toutes les vérifications passent
#   1 = scope violation   — filepath hors scope déclaré
#   2 = fichier locké     — attendre ou signal BLOCKED_ON
#   3 = circuit breaker   — arrêt + signal BLOCKED_ON pilote
#   4 = claim invalide    — claim non-open ou introuvable
#   5 = zone violation    — filepath zone:kernel, claim hors scope kernel (soft lock)
#   6 = mauvaise branche  — theme_branch mismatch

set -euo pipefail

BRAIN_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
CLAIMS_DIR="$BRAIN_ROOT/claims"
LOCKS_DIR="$BRAIN_ROOT/locks"
FAILS_DIR="$BRAIN_ROOT/locks/fails"

# Chemins zone:kernel — synchronisés avec KERNEL.md + brain-index-regen.sh
KERNEL_SCOPES="agents/ profil/ scripts/ KERNEL.md CLAUDE.md PATHS.md brain-compose.yml brain-constitution.md BRAIN-INDEX.md"

mkdir -p "$FAILS_DIR"

# Détermine si un filepath est zone:kernel
is_kernel_path() {
  local filepath="$1"
  for kscope in $KERNEL_SCOPES; do
    if [[ "$filepath" == ${kscope}* ]] || [[ "$filepath" == "$kscope" ]]; then
      return 0
    fi
  done
  return 1
}

# Détermine si un scope déclaré couvre la zone kernel
scope_is_kernel() {
  local scope="$1"
  for kscope in $KERNEL_SCOPES; do
    for scope_entry in $scope; do
      if [[ "$kscope" == ${scope_entry}* ]] || [[ "$scope_entry" == ${kscope}* ]]; then
        return 0
      fi
    done
  done
  return 1
}

# --- CHECK ---
cmd_check() {
  local sess_id="$1"
  local filepath="$2"

  local claim_file="$CLAIMS_DIR/${sess_id}.yml"
  local fail_count=0
  local all_ok=true

  echo "🛫 PRE-FLIGHT — $sess_id → $filepath"
  echo ""

  # CHECK 1 — Claim status
  if [ ! -f "$claim_file" ]; then
    echo "❌ CHECK 1 — Claim introuvable : $sess_id"
    exit 4
  fi
  local claim_status
  claim_status=$(grep '^status:' "$claim_file" | sed 's/^[^:]*: *//' | tr -d '"' | head -1)
  if [ "$claim_status" = "paused" ]; then
    echo "❌ CHECK 1 — Claim en pause : $sess_id"
    echo "   → human-gate-ack.sh resume $sess_id"
    exit 4
  fi
  if [ "$claim_status" = "waiting_human" ]; then
    echo "❌ CHECK 1 — Gate:human actif : $sess_id"
    echo "   → human-gate-ack.sh approve|reject $sess_id"
    exit 4
  fi
  if [ "$claim_status" != "open" ]; then
    echo "❌ CHECK 1 — Claim non-open : $claim_status"
    exit 4
  fi
  echo "✅ CHECK 1 — Claim open"

  # CHECK 1b — Cascade pause (parent paused = enfant bloqué)
  local parent_id
  parent_id=$(grep '^parent_satellite:' "$claim_file" | sed 's/^[^:]*: *//' | tr -d '"' 2>/dev/null || echo "")
  if [ -n "$parent_id" ]; then
    local parent_file="$CLAIMS_DIR/${parent_id}.yml"
    if [ -f "$parent_file" ]; then
      local parent_status
      parent_status=$(grep '^status:' "$parent_file" | sed 's/^[^:]*: *//' | tr -d '"' | head -1)
      if [ "$parent_status" = "paused" ]; then
        echo "❌ CHECK 1b — Parent en pause : $parent_id"
        echo "   → human-gate-ack.sh resume $parent_id"
        exit 4
      fi
      if [ "$parent_status" = "failed" ]; then
        echo "❌ CHECK 1b — Parent failed : $parent_id — satellite orphelin"
        exit 4
      fi
    fi
  fi
  [ -n "$parent_id" ] && echo "✅ CHECK 1b — Parent ok" || true

  # CHECK 2 — Scope check
  local claim_scope
  claim_scope=$(grep '^scope:' "$claim_file" | sed 's/^[^:]*: *//' | tr -d '"')
  local scope_ok=false
  for scope_entry in $claim_scope; do
    if [[ "$filepath" == ${scope_entry}* ]] || [[ "$filepath" == "$scope_entry" ]]; then
      scope_ok=true
      break
    fi
  done
  if [ "$scope_ok" = false ]; then
    echo "❌ CHECK 2 — Scope violation : $filepath ∉ [$claim_scope]"
    exit 1
  fi
  echo "✅ CHECK 2 — Scope ok"

  # CHECK 3 — Zone check (soft lock kernel)
  # Un satellite dont le scope n'est pas kernel ne peut pas écrire en zone:kernel.
  # Exception : kerneluser:true → WARNING (pas de blocage) — owner confirme lui-même.
  if is_kernel_path "$filepath"; then
    if ! scope_is_kernel "$claim_scope"; then
      local kerneluser
      kerneluser=$(grep '^kerneluser:' "$BRAIN_ROOT/brain-compose.yml" | sed 's/^[^:]*: *//' | tr -d '"' | head -1)
      if [ "$kerneluser" = "true" ]; then
        echo "⚠️  CHECK 3 — Zone:kernel (kerneluser bypass) : $filepath"
        echo "   Scope [$claim_scope] hors kernel — modification kernel sur confirmation humaine"
      else
        echo "❌ CHECK 3 — Zone violation : $filepath est zone:kernel"
        echo "   Scope déclaré [$claim_scope] n'inclut pas de zone:kernel"
        echo "   → Modification kernel = décision humaine (KERNEL.md règle délégation)"
        exit 5
      fi
    fi
  fi
  if ! is_kernel_path "$filepath" || scope_is_kernel "$claim_scope"; then
    echo "✅ CHECK 3 — Zone ok"
  fi

  # CHECK 4 — Lock check
  local lockname
  lockname=$(echo "$filepath" | sed 's|/|-|g' | sed 's|\.|-|g' | sed 's|^-||')
  local lockfile="$LOCKS_DIR/${lockname}.lock"
  if [ -f "$lockfile" ]; then
    local now existing_holder existing_expires existing_epoch
    now=$(date +%s)
    existing_holder=$(grep '^holder:' "$lockfile" | sed 's/^[^:]*: *//')
    existing_expires=$(grep '^expires_at:' "$lockfile" | sed 's/^[^:]*: *//')
    existing_epoch=$(date -d "$existing_expires" +%s 2>/dev/null \
      || date -j -f "%Y-%m-%dT%H:%M" "$existing_expires" +%s 2>/dev/null || echo 0)
    if [ "$now" -lt "$existing_epoch" ] && [ "$existing_holder" != "$sess_id" ]; then
      echo "❌ CHECK 4 — Fichier locké par : $existing_holder (expire : $existing_expires)"
      exit 2
    fi
  fi
  echo "✅ CHECK 4 — Lock ok"

  # CHECK 5 — Circuit breaker
  local fail_count_file="$FAILS_DIR/${sess_id}.count"
  if [ -f "$fail_count_file" ]; then
    fail_count=$(cat "$fail_count_file")
  fi
  local max_fails
  max_fails=$(grep -A5 'circuit_breaker:' "$BRAIN_ROOT/brain-compose.yml" \
    | grep 'max_consecutive_fails:' | sed 's/^[^:]*: *//' | awk '{print $1}' | head -1 2>/dev/null || echo 3)
  if [ "${fail_count}" -ge "${max_fails}" ] 2>/dev/null; then
    echo "❌ CHECK 5 — Circuit breaker : $fail_count/$max_fails fails consécutifs"
    echo "   → Signal BLOCKED_ON pilote requis — reset manuel après résolution"
    exit 3
  fi
  echo "✅ CHECK 5 — Circuit breaker ok ($fail_count/$max_fails)"

  # CHECK 6 — Theme branch
  local theme_branch
  theme_branch=$(grep '^theme_branch:' "$claim_file" | sed 's/^[^:]*: *//' | tr -d '"' 2>/dev/null || echo "")
  if [ -n "$theme_branch" ]; then
    local current_branch
    current_branch=$(git -C "$BRAIN_ROOT" branch --show-current 2>/dev/null || echo "")
    if [ "$current_branch" != "$theme_branch" ]; then
      echo "❌ CHECK 6 — Mauvaise branche : sur '$current_branch', attendu '$theme_branch'"
      echo "   git checkout $theme_branch"
      exit 6
    fi
  fi
  echo "✅ CHECK 6 — Branch ok (${theme_branch:-main})"

  echo ""
  echo "🟢 PRE-FLIGHT PASS — go"
}

# --- FAIL (circuit breaker increment) ---
cmd_fail() {
  local sess_id="$1"
  local fail_count_file="$FAILS_DIR/${sess_id}.count"
  local count=0
  [ -f "$fail_count_file" ] && count=$(cat "$fail_count_file")
  count=$((count + 1))
  echo "$count" > "$fail_count_file"

  local max_fails
  max_fails=$(grep -A5 'circuit_breaker:' "$BRAIN_ROOT/brain-compose.yml" \
    | grep 'max_consecutive_fails:' | sed 's/^[^:]*: *//' | awk '{print $1}' | head -1 2>/dev/null || echo 3)
  echo "⚠️  Fail enregistré : $count/$max_fails ($sess_id)"
  if [ "$count" -ge "$max_fails" ] 2>/dev/null; then
    echo "🔴 Circuit breaker déclenché — signal BLOCKED_ON pilote"
  fi
}

# --- RESET (après succès) ---
cmd_reset() {
  local sess_id="$1"
  local fail_count_file="$FAILS_DIR/${sess_id}.count"
  rm -f "$fail_count_file"
  echo "✅ Circuit breaker reset : $sess_id"
}

# --- STATUS ---
cmd_status() {
  local sess_id="$1"
  local fail_count_file="$FAILS_DIR/${sess_id}.count"
  local count=0
  [ -f "$fail_count_file" ] && count=$(cat "$fail_count_file")
  local max_fails
  max_fails=$(grep -A5 'circuit_breaker:' "$BRAIN_ROOT/brain-compose.yml" \
    | grep 'max_consecutive_fails:' | sed 's/^[^:]*: *//' | awk '{print $1}' | head -1 2>/dev/null || echo 3)
  if [ "$count" -ge "$max_fails" ] 2>/dev/null; then
    echo "🔴 Circuit breaker déclenché : $count/$max_fails ($sess_id)"
  else
    echo "✅ Circuit breaker ok : $count/$max_fails ($sess_id)"
  fi
}

# --- Router ---
CMD="${1:-}"
case "$CMD" in
  check)  cmd_check  "${2:-}" "${3:-}" ;;
  fail)   cmd_fail   "${2:-}" ;;
  reset)  cmd_reset  "${2:-}" ;;
  status) cmd_status "${2:-}" ;;
  *)
    echo "Usage : preflight-check.sh <check|fail|reset|status>"
    echo ""
    echo "  check  <sess_id> <filepath>  → 6 checks avant écriture (exit 0=go)"
    echo "  fail   <sess_id>             → enregistre un échec (circuit breaker)"
    echo "  reset  <sess_id>             → reset fail counter après succès"
    echo "  status <sess_id>             → état circuit breaker"
    exit 1
    ;;
esac
