#!/bin/bash
# file-lock.sh — Mutex fichier BSI-v3-7
# Empêche deux satellites d'écrire simultanément dans le même fichier.
# Complète le scope-lock BSI (niveau dossier) avec une granularité fichier.
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
LOCKS_DIR="$BRAIN_ROOT/locks"
DEFAULT_TTL=60   # minutes

mkdir -p "$LOCKS_DIR"

# Convertit un chemin fichier en nom de lock (remplace / et . par -)
filepath_to_lockname() {
  echo "$1" | sed 's|/|-|g' | sed 's|\.|-|g' | sed 's|^-||'
}

# --- ACQUIRE ---
cmd_acquire() {
  local filepath="$1"
  local sess_id="$2"
  local ttl="${3:-$DEFAULT_TTL}"

  local lockname
  lockname=$(filepath_to_lockname "$filepath")
  local lockfile="$LOCKS_DIR/${lockname}.lock"
  local now
  now=$(date +%s)
  local expires_at
  expires_at=$(date -d "+${ttl} minutes" +%Y-%m-%dT%H:%M 2>/dev/null \
    || date -v+${ttl}M +%Y-%m-%dT%H:%M)  # macOS compat

  # Vérifier si lock existant et non expiré
  if [ -f "$lockfile" ]; then
    existing_holder=$(grep '^holder:' "$lockfile" | sed 's/holder: //')
    existing_expires=$(grep '^expires_at:' "$lockfile" | sed 's/expires_at: //')
    existing_epoch=$(date -d "$existing_expires" +%s 2>/dev/null \
      || date -j -f "%Y-%m-%dT%H:%M" "$existing_expires" +%s 2>/dev/null || echo 0)

    if [ "$now" -lt "$existing_epoch" ]; then
      echo "🔴 LOCK — $filepath"
      echo "   Détenu par : $existing_holder"
      echo "   Expire à   : $existing_expires"
      echo ""
      echo "   Attendre le release ou contacter : $existing_holder"
      exit 1
    else
      # Lock expiré — on peut le prendre
      echo "⚠️  Lock expiré de $existing_holder — acquisition automatique"
      rm -f "$lockfile"
    fi
  fi

  # Écrire le lock
  cat > "$lockfile" << EOF
file: $filepath
holder: $sess_id
claimed_at: $(date +%Y-%m-%dT%H:%M)
expires_at: $expires_at
ttl_min: $ttl
EOF

  echo "✅ Lock acquis : $filepath"
  echo "   Session  : $sess_id"
  echo "   Expire   : $expires_at"
}

# --- RELEASE ---
cmd_release() {
  local filepath="$1"
  local sess_id="$2"

  local lockname
  lockname=$(filepath_to_lockname "$filepath")
  local lockfile="$LOCKS_DIR/${lockname}.lock"

  if [ ! -f "$lockfile" ]; then
    echo "ℹ️  Pas de lock actif sur : $filepath"
    exit 0
  fi

  existing_holder=$(grep '^holder:' "$lockfile" | sed 's/holder: //')
  if [ "$existing_holder" != "$sess_id" ]; then
    echo "🚨 Release refusé — lock détenu par : $existing_holder (pas $sess_id)"
    exit 2
  fi

  rm -f "$lockfile"
  echo "✅ Lock libéré : $filepath"
}

# --- CHECK ---
cmd_check() {
  local filepath="$1"

  local lockname
  lockname=$(filepath_to_lockname "$filepath")
  local lockfile="$LOCKS_DIR/${lockname}.lock"

  if [ ! -f "$lockfile" ]; then
    echo "✅ Libre : $filepath"
    exit 0
  fi

  local now
  now=$(date +%s)
  existing_holder=$(grep '^holder:' "$lockfile" | sed 's/holder: //')
  existing_expires=$(grep '^expires_at:' "$lockfile" | sed 's/expires_at: //')
  existing_epoch=$(date -d "$existing_expires" +%s 2>/dev/null \
    || date -j -f "%Y-%m-%dT%H:%M" "$existing_expires" +%s 2>/dev/null || echo 0)

  if [ "$now" -lt "$existing_epoch" ]; then
    echo "🔴 Locké : $filepath"
    echo "   Holder  : $existing_holder"
    echo "   Expire  : $existing_expires"
  else
    echo "⚠️  Lock expiré (nettoyable) : $filepath"
    echo "   Ancien holder : $existing_holder"
  fi
}

# --- LIST ---
cmd_list() {
  local locks
  locks=$(find "$LOCKS_DIR" -name "*.lock" | sort)

  if [ -z "$locks" ]; then
    echo "✅ Aucun lock actif"
    exit 0
  fi

  local now
  now=$(date +%s)
  echo "Locks actifs :"
  echo ""

  while IFS= read -r lockfile; do
    local file holder expires_at epoch status
    file=$(grep '^file:' "$lockfile" | sed 's/file: *//')
    holder=$(grep '^holder:' "$lockfile" | sed 's/holder: *//')
    expires_at=$(grep '^expires_at:' "$lockfile" | sed 's/expires_at: *//')
    epoch=$(date -d "$expires_at" +%s 2>/dev/null \
      || date -j -f "%Y-%m-%dT%H:%M" "$expires_at" +%s 2>/dev/null || echo 0)

    if [ "$now" -lt "$epoch" ]; then
      status="🔴 actif"
    else
      status="⚠️  expiré"
    fi

    echo "  $status | $file | $holder | exp: $expires_at"
  done <<< "$locks"
}

# --- CLEANUP ---
cmd_cleanup() {
  local now
  now=$(date +%s)
  local count=0

  for lockfile in "$LOCKS_DIR"/*.lock; do
    [ -f "$lockfile" ] || continue
    expires_at=$(grep '^expires_at:' "$lockfile" | sed 's/expires_at: *//')
    epoch=$(date -d "$expires_at" +%s 2>/dev/null \
      || date -j -f "%Y-%m-%dT%H:%M" "$expires_at" +%s 2>/dev/null || echo 0)

    if [ "$now" -ge "$epoch" ]; then
      file=$(grep '^file:' "$lockfile" | sed 's/file: *//')
      rm -f "$lockfile"
      echo "🗑️  Lock expiré supprimé : $file"
      count=$((count + 1))
    fi
  done

  if [ "$count" -eq 0 ]; then
    echo "✅ Aucun lock expiré à nettoyer"
  else
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
