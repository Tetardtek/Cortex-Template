#!/bin/bash
# file-lock.sh — Mutex fichier BSI-v3-7 (ADR-036 : brain.db)
# Empêche deux satellites d'écrire simultanément dans le même fichier.
# Source : table locks dans brain.db (ex : locks/*.lock)
#
# Usage :
#   file-lock.sh acquire <filepath> <sess-id> [ttl_minutes]  → acquiert le lock
#   file-lock.sh release <filepath> <sess-id>                → libère le lock
#   file-lock.sh check   <filepath>                          → qui détient le lock ?
#   file-lock.sh list                                        → tous les locks actifs
#   file-lock.sh cleanup                                     → supprime les locks expirés
#
# Exit codes :
#   0 = succès
#   1 = lock déjà détenu par une autre session (acquire)
#   2 = erreur (sess-id incorrect pour release, fichier introuvable)

set -euo pipefail

BRAIN_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
DB_PATH="$BRAIN_ROOT/brain.db"
DEFAULT_TTL=60   # minutes

# Init table si absente
python3 "$BRAIN_ROOT/scripts/bsi-db.py" -script "
  CREATE TABLE IF NOT EXISTS locks (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    filepath    TEXT NOT NULL UNIQUE,
    holder      TEXT NOT NULL,
    claimed_at  TEXT NOT NULL DEFAULT (datetime('now')),
    expires_at  TEXT NOT NULL,
    ttl_min     INTEGER NOT NULL DEFAULT 60
  );
"

# --- ACQUIRE ---
cmd_acquire() {
  local filepath="$1"
  local sess_id="$2"
  local ttl="${3:-$DEFAULT_TTL}"

  # Check existing active lock held by someone else
  local existing
  existing=$(python3 "$BRAIN_ROOT/scripts/bsi-db.py" "
    SELECT holder, expires_at FROM locks
    WHERE filepath = '$filepath'
      AND julianday('now') < julianday(expires_at)
      AND holder != '$sess_id'
    LIMIT 1;
  ")

  if [ -n "$existing" ]; then
    local holder expires
    holder=$(echo "$existing" | cut -d'|' -f1)
    expires=$(echo "$existing" | cut -d'|' -f2)
    echo "🔴 LOCK — $filepath"
    echo "   Détenu par : $holder"
    echo "   Expire à   : $expires"
    echo ""
    echo "   Attendre le release ou contacter : $holder"
    exit 1
  fi

  # Upsert — remplace si même holder ou expiré
  python3 "$BRAIN_ROOT/scripts/bsi-db.py" -script "
    DELETE FROM locks WHERE filepath = '$filepath';
    INSERT INTO locks (filepath, holder, claimed_at, expires_at, ttl_min)
    VALUES ('$filepath', '$sess_id', datetime('now'), datetime('now', '+$ttl minutes'), $ttl);
  "

  local expires_at
  expires_at=$(python3 "$BRAIN_ROOT/scripts/bsi-db.py" "SELECT expires_at FROM locks WHERE filepath = '$filepath';")

  echo "✅ Lock acquis : $filepath"
  echo "   Session  : $sess_id"
  echo "   Expire   : $expires_at"
}

# --- RELEASE ---
cmd_release() {
  local filepath="$1"
  local sess_id="$2"

  local holder
  holder=$(python3 "$BRAIN_ROOT/scripts/bsi-db.py" "SELECT holder FROM locks WHERE filepath = '$filepath';")

  if [ -z "$holder" ]; then
    echo "ℹ️  Pas de lock actif sur : $filepath"
    exit 0
  fi

  if [ "$holder" != "$sess_id" ]; then
    echo "🚨 Release refusé — lock détenu par : $holder (pas $sess_id)"
    exit 2
  fi

  python3 "$BRAIN_ROOT/scripts/bsi-db.py" -exec "DELETE FROM locks WHERE filepath = '$filepath' AND holder = '$sess_id'"
  echo "✅ Lock libéré : $filepath"
}

# --- CHECK ---
cmd_check() {
  local filepath="$1"

  local row
  row=$(python3 "$BRAIN_ROOT/scripts/bsi-db.py" "
    SELECT holder, expires_at,
           CASE WHEN julianday('now') < julianday(expires_at) THEN 'active' ELSE 'expired' END
    FROM locks WHERE filepath = '$filepath';
  ")

  if [ -z "$row" ]; then
    echo "✅ Libre : $filepath"
    exit 0
  fi

  local holder expires status
  holder=$(echo "$row" | cut -d'|' -f1)
  expires=$(echo "$row" | cut -d'|' -f2)
  status=$(echo "$row" | cut -d'|' -f3)

  if [ "$status" = "active" ]; then
    echo "🔴 Locké : $filepath"
    echo "   Holder  : $holder"
    echo "   Expire  : $expires"
  else
    echo "⚠️  Lock expiré (nettoyable) : $filepath"
    echo "   Ancien holder : $holder"
  fi
}

# --- LIST ---
cmd_list() {
  local rows
  rows=$(python3 "$BRAIN_ROOT/scripts/bsi-db.py" "
    SELECT filepath, holder, expires_at,
           CASE WHEN julianday('now') < julianday(expires_at) THEN 'actif' ELSE 'expiré' END
    FROM locks ORDER BY claimed_at DESC;
  ")

  if [ -z "$rows" ]; then
    echo "✅ Aucun lock actif"
    exit 0
  fi

  echo "Locks actifs :"
  echo ""
  while IFS='|' read -r filepath holder expires status; do
    local icon="🔴"
    [ "$status" = "expiré" ] && icon="⚠️ "
    echo "  $icon $status | $filepath | $holder | exp: $expires"
  done <<< "$rows"
}

# --- CLEANUP ---
cmd_cleanup() {
  local count
  count=$(python3 "$BRAIN_ROOT/scripts/bsi-db.py" "
    SELECT COUNT(*) FROM locks WHERE julianday('now') >= julianday(expires_at);
  ")

  if [ "$count" -eq 0 ]; then
    echo "✅ Aucun lock expiré à nettoyer"
  else
    python3 "$BRAIN_ROOT/scripts/bsi-db.py" -exec "DELETE FROM locks WHERE julianday('now') >= julianday(expires_at)"
    echo "✅ $count lock(s) nettoyé(s)"
  fi
}

# --- Router ---
CMD="${1:-}"
case "$CMD" in
  acquire) cmd_acquire "${2:-}" "${3:-}" "${4:-}" ;;
  release) cmd_release "${2:-}" "${3:-}" ;;
  check)   cmd_check   "${2:-}" ;;
  list)    cmd_list ;;
  cleanup) cmd_cleanup ;;
  *)
    echo "Usage : file-lock.sh <acquire|release|check|list|cleanup>"
    echo ""
    echo "  acquire <filepath> <sess-id> [ttl_min]  → acquiert le lock (défaut: 60min)"
    echo "  release <filepath> <sess-id>             → libère le lock"
    echo "  check   <filepath>                       → état du lock"
    echo "  list                                     → tous les locks actifs"
    echo "  cleanup                                  → supprime les locks expirés"
    exit 1
    ;;
esac
