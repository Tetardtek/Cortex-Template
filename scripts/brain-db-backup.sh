#!/usr/bin/env bash
# brain-db-backup.sh — Backup journalier brain.db → repo git dédié
# Usage: bash scripts/brain-db-backup.sh [backup_dir]
# Cron:  0 4 * * * bash ~/Dev/Brain/scripts/brain-db-backup.sh
#
# Stratégie :
#   1. SQLite vacuum into backup (copie propre, pas de lock stale)
#   2. Commit daté dans le repo backup
#   3. Push Gitea (silencieux si remote absent)
#   4. Rétention : 30 fichiers max (rotation automatique)

set -euo pipefail

BRAIN_DB="${BRAIN_DB:-$HOME/Dev/Brain/brain.db}"
BACKUP_DIR="${1:-$HOME/Dev/Brain/brain-db-backup}"
RETENTION=30
DATE=$(date '+%Y-%m-%d')
BACKUP_FILE="brain-${DATE}.db"

# --- Vérifications ---
if [[ ! -f "$BRAIN_DB" ]]; then
    echo "❌ brain.db introuvable : $BRAIN_DB" >&2
    exit 1
fi

# --- Init repo backup si premier run ---
if [[ ! -d "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
    git -C "$BACKUP_DIR" init
    echo "# brain-db-backup" > "$BACKUP_DIR/README.md"
    echo "Backups journaliers de brain.db — généré par brain-db-backup.sh" >> "$BACKUP_DIR/README.md"
    echo "" >> "$BACKUP_DIR/README.md"
    echo "*.db binary" > "$BACKUP_DIR/.gitattributes"
    git -C "$BACKUP_DIR" add .
    git -C "$BACKUP_DIR" commit -m "init: brain-db-backup repo"
    echo "✅ Repo backup initialisé : $BACKUP_DIR"
fi

# --- Backup via SQLite vacuum (copie propre) ---
python3 -c "
import sqlite3, shutil, sys
src = '${BRAIN_DB}'
dst = '${BACKUP_DIR}/${BACKUP_FILE}'
conn = sqlite3.connect(src)
bkp = sqlite3.connect(dst)
conn.backup(bkp)
bkp.close()
conn.close()
print(f'✅ Backup : {dst}')
"

# --- Rotation : garder les N plus récents ---
cd "$BACKUP_DIR"
ls -1t brain-*.db 2>/dev/null | tail -n +$((RETENTION + 1)) | while read old; do
    rm -f "$old"
    echo "🗑 Rotation : $old supprimé"
done

# --- Commit ---
git -C "$BACKUP_DIR" add -A
if git -C "$BACKUP_DIR" diff --cached --quiet; then
    echo "ℹ️  Aucun changement — brain.db identique au dernier backup"
    exit 0
fi
git -C "$BACKUP_DIR" commit -m "backup: brain.db ${DATE}"

# --- Push (silencieux si pas de remote) ---
if git -C "$BACKUP_DIR" remote get-url origin &>/dev/null; then
    git -C "$BACKUP_DIR" push -q && echo "✅ Push Gitea OK" || echo "⚠️ Push échoué (réseau ?)"
else
    echo "ℹ️  Pas de remote — backup local uniquement. Ajouter : git -C $BACKUP_DIR remote add origin <url>"
fi
