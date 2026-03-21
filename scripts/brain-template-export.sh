#!/usr/bin/env bash
# brain-template-export.sh — Extrait brain-template.db depuis brain.db (kernel+public only)
# Usage: bash scripts/brain-template-export.sh [output_path]
#
# Fast path : copie les vecteurs existants, pas besoin d'Ollama.
# Zéro table session (claims, signals, handoffs, sessions, agent_loads, locks, circuit_breaker, agent_memory).

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${BRAIN_ROOT}/brain.db"
DST="${1:-${BRAIN_ROOT}/brain-template.db}"

if [[ ! -f "$SRC" ]]; then
    echo "❌ brain.db introuvable : $SRC" >&2
    exit 1
fi

echo "brain-template-export : $SRC → $DST"
echo "Scopes inclus : kernel, public"

python3 - "$SRC" "$DST" << 'PY'
import sqlite3
import sys

src_path = sys.argv[1]
dst_path = sys.argv[2]

# Connexion source (lecture seule)
src = sqlite3.connect(f'file:{src_path}?mode=ro', uri=True)
src.row_factory = sqlite3.Row

# Créer le template DB
dst = sqlite3.connect(dst_path)
dst.execute("PRAGMA journal_mode=WAL")

# Créer la table embeddings (seule table du template)
dst.execute("""
    CREATE TABLE IF NOT EXISTS embeddings (
        chunk_id    TEXT PRIMARY KEY,
        filepath    TEXT NOT NULL,
        title       TEXT,
        chunk_text  TEXT NOT NULL,
        vector      BLOB,
        model       TEXT,
        indexed     INTEGER DEFAULT 0,
        scope       TEXT NOT NULL DEFAULT 'work',
        created_at  TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
    )
""")
dst.execute("CREATE INDEX IF NOT EXISTS idx_emb_filepath ON embeddings(filepath)")
dst.execute("CREATE INDEX IF NOT EXISTS idx_emb_indexed ON embeddings(indexed)")
dst.execute("CREATE INDEX IF NOT EXISTS idx_emb_scope ON embeddings(scope)")
dst.commit()

# Copier uniquement les embeddings kernel + public
ALLOWED_SCOPES = ('kernel', 'public')
placeholders = ','.join('?' * len(ALLOWED_SCOPES))

rows = src.execute(f"""
    SELECT chunk_id, filepath, title, chunk_text, vector, model, indexed, scope, created_at, updated_at
    FROM embeddings
    WHERE indexed = 1 AND vector IS NOT NULL AND scope IN ({placeholders})
""", ALLOWED_SCOPES).fetchall()

for r in rows:
    dst.execute("""
        INSERT OR REPLACE INTO embeddings
            (chunk_id, filepath, title, chunk_text, vector, model, indexed, scope, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, tuple(r))

dst.commit()
dst.execute("VACUUM")

# Stats
total = len(rows)
scopes = {}
for r in rows:
    s = r['scope']
    scopes[s] = scopes.get(s, 0) + 1

src.close()
dst.close()

print(f"✅ Template généré : {dst_path}")
print(f"   Chunks : {total}")
for s, c in sorted(scopes.items()):
    print(f"   - {s} : {c}")
print(f"   Tables session : 0 (aucune)")
PY
