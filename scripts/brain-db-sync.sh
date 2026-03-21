#!/usr/bin/env bash
# brain-db-sync.sh — Sync brain.db depuis les sources brain
#
# Usage :
#   brain-db-sync.sh             → migrate + log résultat
#   brain-db-sync.sh --quiet     → log fichier uniquement (pour hooks git)
#   brain-db-sync.sh --check     → exit 0 si brain.db à jour, exit 2 si stale
#
# Headless : zéro notify-send, zéro dépendance Wayland/display.
# Appelable depuis hook git post-commit, cron, ou manuellement.
#
# Exit codes :
#   0 = sync réussi
#   1 = migrate.py introuvable ou Python absent
#   2 = brain.db stale (--check uniquement)
#   3 = migrate.py a échoué

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MIGRATE="$BRAIN_ROOT/brain-engine/migrate.py"
DB_PATH="$BRAIN_ROOT/brain.db"
LOG_FILE="$BRAIN_ROOT/brain-engine/sync.log"
QUIET=false
CHECK_ONLY=false

for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=true ;;
        --check) CHECK_ONLY=true ;;
    esac
done

log() {
    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S')
    echo "[$ts] $*" >> "$LOG_FILE"
    $QUIET || echo "[brain-db-sync] $*"
}

# Vérifications préalables
if [[ ! -f "$MIGRATE" ]]; then
    log "ERROR: migrate.py introuvable ($MIGRATE)"
    exit 1
fi

if ! python3 -c "import sqlite3" 2>/dev/null; then
    log "ERROR: python3/sqlite3 absent"
    exit 1
fi

# --check : brain.db stale si plus vieux que le dernier commit touchant handoffs/ ou agents/
# Note: claims/ retiré (ADR-042 — brain.db est la source unique, plus de claims YAML)
if $CHECK_ONLY; then
    if [[ ! -f "$DB_PATH" ]]; then
        log "STALE: brain.db absent"
        exit 2
    fi
    db_mtime=$(stat -c %Y "$DB_PATH" 2>/dev/null || echo 0)
    last_commit_ts=$(git -C "$BRAIN_ROOT" log -1 --format="%ct" -- handoffs/ agents/ BRAIN-INDEX.md 2>/dev/null || echo 0)
    if [[ "$last_commit_ts" -gt "$db_mtime" ]]; then
        log "STALE: brain.db ($db_mtime) < dernier commit handoffs/agents ($last_commit_ts)"
        exit 2
    fi
    log "OK: brain.db à jour"
    exit 0
fi

# Sync
log "Démarrage migrate.py..."
if python3 "$MIGRATE" >> "$LOG_FILE" 2>&1; then
    claim_count=$(python3 -c "
import sqlite3
conn = sqlite3.connect('$DB_PATH')
n = conn.execute(\"SELECT COUNT(*) FROM claims\").fetchone()[0]
o = conn.execute(\"SELECT COUNT(*) FROM claims WHERE status='open'\").fetchone()[0]
print(f'{o} open / {n} total')
conn.close()
" 2>/dev/null || echo "?")
    log "OK — claims: $claim_count"
else
    log "ERROR: migrate.py a échoué (voir $LOG_FILE)"
    exit 3
fi
