#!/bin/bash
# preflight-check.sh — BSI-v3-8 Pre-flight check (ADR-036 : brain.db)
# Valide les 6 conditions avant qu'un satellite commence à écrire.
# Source : tables claims, locks, circuit_breaker dans brain.db
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
DB_PATH="$BRAIN_ROOT/brain.db"

# Chemins zone:kernel — synchronisés avec KERNEL.md
KERNEL_SCOPES="agents/ profil/ scripts/ KERNEL.md CLAUDE.md PATHS.md brain-compose.yml brain-constitution.md BRAIN-INDEX.md"

# Init tables si absentes
python3 "$BRAIN_ROOT/scripts/bsi-db.py" -script "
  CREATE TABLE IF NOT EXISTS circuit_breaker (
    sess_id     TEXT PRIMARY KEY,
    fail_count  INTEGER NOT NULL DEFAULT 0,
    last_fail_at TEXT,
    updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
  );
"

# Helper : query brain.db (SELECT → stdout)
q() {
  python3 "$BRAIN_ROOT/scripts/bsi-db.py" "$1"
}
# Helper : write brain.db (INSERT/UPDATE/DELETE)
qw() {
  python3 "$BRAIN_ROOT/scripts/bsi-db.py" -exec "$1"
}

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

  echo "🛫 PRE-FLIGHT — $sess_id → $filepath"
  echo ""

  # CHECK 1 — Claim status
  local claim_status
  claim_status=$(q "SELECT status FROM claims WHERE sess_id = '$sess_id';")
  if [ -z "$claim_status" ]; then
    echo "❌ CHECK 1 — Claim introuvable : $sess_id"
    exit 4
  fi
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
  parent_id=$(q "SELECT parent_sess FROM claims WHERE sess_id = '$sess_id';")
  if [ -n "$parent_id" ]; then
    local parent_status
    parent_status=$(q "SELECT status FROM claims WHERE sess_id = '$parent_id';")
    if [ "$parent_status" = "paused" ]; then
      echo "❌ CHECK 1b — Parent en pause : $parent_id"
      echo "   → human-gate-ack.sh resume $parent_id"
      exit 4
    fi
    if [ "$parent_status" = "failed" ]; then
      echo "❌ CHECK 1b — Parent failed : $parent_id — satellite orphelin"
      exit 4
    fi
    echo "✅ CHECK 1b — Parent ok"
  fi

  # CHECK 2 — Scope check
  local claim_scope
  claim_scope=$(q "SELECT scope FROM claims WHERE sess_id = '$sess_id';")
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
        exit 5
      fi
    fi
  fi
  if ! is_kernel_path "$filepath" || scope_is_kernel "$claim_scope"; then
    echo "✅ CHECK 3 — Zone ok"
  fi

  # CHECK 4 — Lock check
  local lock_holder
  lock_holder=$(q "
    SELECT holder FROM locks
    WHERE filepath = '$filepath'
      AND julianday('now') < julianday(expires_at)
      AND holder != '$sess_id'
    LIMIT 1;
  ")
  if [ -n "$lock_holder" ]; then
    local lock_expires
    lock_expires=$(q "SELECT expires_at FROM locks WHERE filepath = '$filepath';")
    echo "❌ CHECK 4 — Fichier locké par : $lock_holder (expire : $lock_expires)"
    exit 2
  fi
  echo "✅ CHECK 4 — Lock ok"

  # CHECK 5 — Circuit breaker
  local fail_count
  fail_count=$(q "SELECT COALESCE(fail_count, 0) FROM circuit_breaker WHERE sess_id = '$sess_id';")
  fail_count="${fail_count:-0}"
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
  theme_branch=$(q "SELECT COALESCE(theme_branch, '') FROM claims WHERE sess_id = '$sess_id';")
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
  qw "
    INSERT INTO circuit_breaker (sess_id, fail_count, last_fail_at, updated_at)
    VALUES ('$sess_id', 1, datetime('now'), datetime('now'))
    ON CONFLICT(sess_id) DO UPDATE SET
      fail_count = fail_count + 1,
      last_fail_at = datetime('now'),
      updated_at = datetime('now')
  "

  local fail_count
  fail_count=$(q "SELECT fail_count FROM circuit_breaker WHERE sess_id = '$sess_id';")
  local max_fails
  max_fails=$(grep -A5 'circuit_breaker:' "$BRAIN_ROOT/brain-compose.yml" \
    | grep 'max_consecutive_fails:' | sed 's/^[^:]*: *//' | awk '{print $1}' | head -1 2>/dev/null || echo 3)
  echo "⚠️  Fail enregistré : $fail_count/$max_fails ($sess_id)"
  if [ "$fail_count" -ge "$max_fails" ] 2>/dev/null; then
    echo "🔴 Circuit breaker déclenché — signal BLOCKED_ON pilote"
  fi
}

# --- RESET (après succès) ---
cmd_reset() {
  local sess_id="$1"
  qw "DELETE FROM circuit_breaker WHERE sess_id = '$sess_id'"
  echo "✅ Circuit breaker reset : $sess_id"
}

# --- STATUS ---
cmd_status() {
  local sess_id="$1"
  local fail_count
  fail_count=$(q "SELECT COALESCE(fail_count, 0) FROM circuit_breaker WHERE sess_id = '$sess_id';")
  fail_count="${fail_count:-0}"
  local max_fails
  max_fails=$(grep -A5 'circuit_breaker:' "$BRAIN_ROOT/brain-compose.yml" \
    | grep 'max_consecutive_fails:' | sed 's/^[^:]*: *//' | awk '{print $1}' | head -1 2>/dev/null || echo 3)
  if [ "$fail_count" -ge "$max_fails" ] 2>/dev/null; then
    echo "🔴 Circuit breaker déclenché : $fail_count/$max_fails ($sess_id)"
  else
    echo "✅ Circuit breaker ok : $fail_count/$max_fails ($sess_id)"
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
