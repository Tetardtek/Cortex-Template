#!/usr/bin/env bash
# brain-index-regen.sh — Vérifie l'état des claims dans brain.db
# Post-ADR-042 : ne modifie plus BRAIN-INDEX.md (claims = brain.db source unique)
# Conservé pour compatibilité — les appels existants ne cassent pas.
#
# Usage : bash scripts/brain-index-regen.sh
# Output : 1 ligne résumé (open/total)

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_PATH="$BRAIN_ROOT/brain.db"

if [[ ! -f "$DB_PATH" ]]; then
  echo "⚠️  brain.db absent — lancer: bash scripts/bsi-claim.sh init"
  exit 1
fi

python3 -c "
import sqlite3, sys
conn = sqlite3.connect(sys.argv[1])
try:
    total = conn.execute('SELECT COUNT(*) FROM claims').fetchone()[0]
    opens = conn.execute(\"SELECT COUNT(*) FROM claims WHERE status='open'\").fetchone()[0]
    print(f'✅ brain.db — {opens} claim(s) open / {total} total')
except Exception:
    print('⚠️  Table claims absente — lancer: bash scripts/bsi-claim.sh init')
conn.close()
" "$DB_PATH"
