#!/usr/bin/env bash
# brain-sync-replica.sh — Réplication master → replica (embeddings)
# Le desktop est source de vérité. Le laptop reçoit une copie read-only.
#
# Usage :
#   brain-sync-replica.sh status                    → écart master/replica
#   brain-sync-replica.sh sync <replica_host>       → sync vers replica
#   brain-sync-replica.sh sync laptop               → alias pour le peer "laptop"
#
# Prérequis : SSH sans mot de passe vers la replica
# Ne sync QUE la table embeddings — pas claims, pas locks (BSI local à chaque machine)

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_PATH="$BRAIN_ROOT/brain.db"
REMOTE_DB_PATH="Dev/Brain/brain.db"

# Résoudre le peer depuis brain-compose.local.yml
resolve_peer() {
  local name="$1"
  python3 - "$BRAIN_ROOT/brain-compose.local.yml" "$name" << 'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}
peers = data.get('peers', {})
peer = peers.get(sys.argv[2], {})
url = peer.get('url', '')
# Extraire host depuis http://192.168.1.10:7700
if '://' in url:
    host = url.split('://')[1].split(':')[0]
    print(host)
PY
}

# --- STATUS ---
cmd_status() {
  local local_count local_updated

  local_count=$(python3 "$BRAIN_ROOT/scripts/bsi-db.py" "SELECT COUNT(*) FROM embeddings WHERE indexed=1")
  local_updated=$(python3 "$BRAIN_ROOT/scripts/bsi-db.py" "SELECT MAX(updated_at) FROM embeddings")

  echo "=== Embedding master (local) ==="
  echo "  Chunks indexés : $local_count"
  echo "  Dernier update : $local_updated"

  # Check peers
  local compose="$BRAIN_ROOT/brain-compose.local.yml"
  if [ -f "$compose" ]; then
    echo ""
    echo "=== Peers ==="
    python3 - "$compose" << 'PY'
import yaml, json, urllib.request
with open(__import__('sys').argv[1]) as f:
    data = yaml.safe_load(f) or {}
for name, peer in data.get('peers', {}).items():
    if not peer.get('active', False):
        continue
    url = peer.get('url', '').rstrip('/')
    try:
        with urllib.request.urlopen(f"{url}/health", timeout=3) as r:
            health = json.loads(r.read())
            indexed = health.get('indexed', '?')
            print(f"  {name}: {indexed} chunks (online)")
    except Exception:
        print(f"  {name}: offline")
PY
  fi
}

# --- SYNC ---
cmd_sync() {
  local target="$1"
  local host

  # Résoudre si c'est un nom de peer
  host=$(resolve_peer "$target" 2>/dev/null || echo "")
  if [ -z "$host" ]; then
    host="$target"
  fi

  local user="tetardtek"
  local remote="${user}@${host}"

  echo "=== Sync embeddings → $remote ==="

  # 1. Check connexion
  if ! ssh -o ConnectTimeout=3 "$remote" "echo ok" > /dev/null 2>&1; then
    echo "❌ SSH unreachable : $remote"
    exit 1
  fi

  # 2. Stats locales
  local local_count
  local_count=$(python3 "$BRAIN_ROOT/scripts/bsi-db.py" "SELECT COUNT(*) FROM embeddings WHERE indexed=1")
  echo "  Master  : $local_count chunks"

  # 3. Stats replica
  local remote_count
  remote_count=$(ssh "$remote" "python3 ~/Dev/Brain/scripts/bsi-db.py 'SELECT COUNT(*) FROM embeddings WHERE indexed=1' 2>/dev/null || echo 0")
  echo "  Replica : $remote_count chunks"

  local delta=$((local_count - remote_count))
  if [ "$delta" -eq 0 ]; then
    echo "✅ Déjà synchronisé — 0 écart"
    exit 0
  fi
  echo "  Écart   : $delta chunks"
  echo ""

  # 4. Export embeddings → fichier temporaire
  local tmp="/tmp/brain-embeddings-sync.db"
  echo "  Exporting embeddings table..."
  python3 - "$DB_PATH" "$tmp" << 'PY'
import sqlite3, sys
src = sqlite3.connect(sys.argv[1])
dst = sqlite3.connect(sys.argv[2])
dst.execute("DROP TABLE IF EXISTS embeddings")
# Copy schema
schema = src.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='embeddings'").fetchone()[0]
dst.execute(schema)
# Copy data
rows = src.execute("SELECT * FROM embeddings").fetchall()
cols = [d[0] for d in src.execute("PRAGMA table_info(embeddings)").fetchall()]
placeholders = ','.join(['?'] * len(cols))
dst.executemany(f"INSERT INTO embeddings VALUES ({placeholders})", rows)
dst.commit()
dst.close()
src.close()
print(f"  ✅ {len(rows)} chunks exportés")
PY

  # 5. SCP vers replica
  echo "  Transferring to $remote..."
  scp -q "$tmp" "${remote}:/tmp/brain-embeddings-sync.db"

  # 6. Import sur replica
  ssh "$remote" python3 - << 'PY'
import sqlite3
src = sqlite3.connect("/tmp/brain-embeddings-sync.db")
dst = sqlite3.connect("/home/tetardtek/Dev/Brain/brain.db")
# Drop and recreate
dst.execute("DROP TABLE IF EXISTS embeddings")
schema = src.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name='embeddings'").fetchone()[0]
dst.execute(schema)
rows = src.execute("SELECT * FROM embeddings").fetchall()
cols = [d[0] for d in src.execute("PRAGMA table_info(embeddings)").fetchall()]
placeholders = ','.join(['?'] * len(cols))
dst.executemany(f"INSERT INTO embeddings VALUES ({placeholders})", rows)
dst.commit()
dst.close()
src.close()
print(f"  ✅ {len(rows)} chunks importés sur replica")
PY

  # 7. Cleanup
  rm -f "$tmp"
  ssh "$remote" "rm -f /tmp/brain-embeddings-sync.db"

  # 8. Verify
  local new_count
  new_count=$(ssh "$remote" "python3 ~/Dev/Brain/scripts/bsi-db.py 'SELECT COUNT(*) FROM embeddings WHERE indexed=1' 2>/dev/null || echo '?'")
  echo ""
  echo "=== Sync terminé ==="
  echo "  Master  : $local_count chunks"
  echo "  Replica : $new_count chunks"
  if [ "$local_count" = "$new_count" ]; then
    echo "  ✅ Synchronisé — 0 écart"
  else
    echo "  ⚠️  Écart résiduel : $((local_count - new_count))"
  fi
}

# --- Router ---
CMD="${1:-}"
case "$CMD" in
  status) cmd_status ;;
  sync)   cmd_sync "${2:-}" ;;
  *)
    echo "Usage : brain-sync-replica.sh <status|sync>"
    echo ""
    echo "  status                    → écart master/replica"
    echo "  sync <host|peer_name>     → sync embeddings vers replica"
    echo ""
    echo "  Exemple : brain-sync-replica.sh sync laptop"
    exit 1
    ;;
esac
