#!/bin/bash
# brain-status.sh — Vue live du brain pour toute instance
# Lecture seule. Aucune écriture.
#
# Usage :
#   brain-status.sh          → résumé complet
#   brain-status.sh claims   → claims open uniquement
#   brain-status.sh locks    → fichiers verrouillés
#   brain-status.sh signals  → signaux pending

set -euo pipefail

BRAIN_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
CLAIMS_DIR="$BRAIN_ROOT/claims"
LOCKS_DIR="$BRAIN_ROOT/locks"
NOW=$(date +%s)

# --- Helpers ---
claim_field() { grep "^${2}:" "$1" | sed 's/^[^:]*: *//' | tr -d '"' | head -1; }

status_icon() {
  case "$1" in
    open)          echo "🟢" ;;
    waiting_human) echo "🔶" ;;
    paused)        echo "⏸ " ;;
    closed)        echo "✅" ;;
    failed)        echo "❌" ;;
    *)             echo "❓" ;;
  esac
}

# --- CLAIMS ---
show_claims() {
  local filter="${1:-open waiting_human paused}"
  local found=0

  echo "── Claims ──────────────────────────────────────"
  for f in "$CLAIMS_DIR"/*.yml; do
    [ -f "$f" ] || continue
    local status sess_id scope type opened_at
    status=$(claim_field "$f" status)
    # Filter
    echo "$filter" | grep -qw "$status" || continue
    sess_id=$(claim_field "$f" sess_id)
    scope=$(claim_field "$f" scope)
    type=$(claim_field "$f" type)
    opened_at=$(claim_field "$f" opened_at)
    printf "  %s %-12s  %-42s  [%s]\n" \
      "$(status_icon "$status")" "$type" "$sess_id" "$scope"
    found=1
  done
  [ "$found" -eq 0 ] && echo "  (aucun)" || true
}

# --- LOCKS ---
show_locks() {
  local found=0

  echo "── Locks fichiers ──────────────────────────────"
  for f in "$LOCKS_DIR"/*.lock; do
    [ -f "$f" ] || continue
    local file holder expires_at epoch
    file=$(grep '^file:' "$f" | sed 's/^[^:]*: *//')
    holder=$(grep '^holder:' "$f" | sed 's/^[^:]*: *//')
    expires_at=$(grep '^expires_at:' "$f" | sed 's/^[^:]*: *//')
    epoch=$(date -d "$expires_at" +%s 2>/dev/null \
      || date -j -f "%Y-%m-%dT%H:%M" "$expires_at" +%s 2>/dev/null || echo 0)
    if [ "$NOW" -lt "$epoch" ]; then
      printf "  🔴 %-40s  %s  (exp: %s)\n" "$file" "$holder" "$expires_at"
    else
      printf "  ⚠️  %-40s  expiré\n" "$file"
    fi
    found=1
  done
  [ "$found" -eq 0 ] && echo "  (aucun)" || true
}

# --- SIGNALS ---
show_signals() {
  local brain_index="$BRAIN_ROOT/BRAIN-INDEX.md"
  echo "── Signaux pending ─────────────────────────────"

  if [ ! -f "$brain_index" ]; then
    echo "  (BRAIN-INDEX.md introuvable)"
    return
  fi

  local found=0
  # Lire les lignes de la table signals avec status=pending
  while IFS='|' read -r _ sig_id from_sess to_sess sig_type summary status _; do
    sig_id=$(echo "$sig_id" | xargs)
    status=$(echo "$status" | xargs)
    [ "$status" = "pending" ] || continue
    [ -z "$sig_id" ] && continue
    [[ "$sig_id" == sig-* ]] || continue
    sig_type=$(echo "$sig_type" | xargs)
    from_sess=$(echo "$from_sess" | xargs)
    summary=$(echo "$summary" | xargs | cut -c1-40)
    printf "  📡 %-30s  %-16s  %s\n" "$sig_id" "$sig_type" "$summary"
    found=1
  done < "$brain_index"
  [ "$found" -eq 0 ] && echo "  (aucun)" || true
}

# --- CIRCUIT BREAKERS ---
show_circuit_breakers() {
  local fails_dir="$LOCKS_DIR/fails"
  local max_fails
  max_fails=$(grep -A5 'circuit_breaker:' "$BRAIN_ROOT/brain-compose.yml" \
    | grep 'max_consecutive_fails:' | awk '{print $2}' | head -1 2>/dev/null || echo 3)
  local found=0

  echo "── Circuit breakers ────────────────────────────"
  for f in "$fails_dir"/*.count; do
    [ -f "$f" ] || continue
    local count sess_id
    count=$(cat "$f")
    sess_id=$(basename "$f" .count)
    if [ "$count" -ge "$max_fails" ] 2>/dev/null; then
      printf "  🔴 %s : %s/%s fails\n" "$sess_id" "$count" "$max_fails"
    else
      printf "  ⚠️  %s : %s/%s fails\n" "$sess_id" "$count" "$max_fails"
    fi
    found=1
  done
  [ "$found" -eq 0 ] && echo "  (aucun)" || true
}

# --- HEADER ---
show_header() {
  local branch
  branch=$(git -C "$BRAIN_ROOT" branch --show-current 2>/dev/null || echo "?")
  local open_count=0 lock_count=0
  while IFS= read -r f; do [ -f "$f" ] && open_count=$((open_count+1)); done \
    < <(find "$CLAIMS_DIR" -name "*.yml" 2>/dev/null)
  # recount only open/waiting/paused
  open_count=0
  for f in "$CLAIMS_DIR"/*.yml; do
    [ -f "$f" ] || continue
    s=$(claim_field "$f" status)
    case "$s" in open|waiting_human|paused) open_count=$((open_count+1)) ;; esac
  done
  for f in "$LOCKS_DIR"/*.lock; do
    [ -f "$f" ] && lock_count=$((lock_count+1))
  done

  echo "╔══════════════════════════════════════════════╗"
  printf "║  🧠 Brain status  %-27s║\n" "$(date +%H:%M)"
  printf "║  branch: %-36s║\n" "$branch"
  printf "║  open: %s claims  locks: %s                   ║\n" "$open_count" "$lock_count"
  echo "╚══════════════════════════════════════════════╝"
}

# --- Router ---
CMD="${1:-all}"
case "$CMD" in
  claims)  show_claims "open waiting_human paused" ;;
  locks)   show_locks ;;
  signals) show_signals ;;
  all|"")
    show_header
    echo ""
    show_claims "open waiting_human paused"
    echo ""
    show_locks
    echo ""
    show_signals
    echo ""
    show_circuit_breakers
    ;;
  *)
    echo "Usage : brain-status.sh [all|claims|locks|signals]"
    exit 1
    ;;
esac
