#!/usr/bin/env bash
# bsi-query.sh — Requêtes BSI via brain.db (SQLite)
# Remplace les grep sur BRAIN-INDEX.md pour les opérations courantes.
#
# Usage :
#   bsi-query.sh open          → liste les claims open (sess_id | scope | opened_at | age_h)
#   bsi-query.sh stale         → claims open depuis > 4h
#   bsi-query.sh count-open    → nombre de claims open (entier, stdout)
#   bsi-query.sh count-stale   → nombre de claims stale (entier, stdout)
#   bsi-query.sh signals       → signaux pending (CHECKPOINT | HANDOFF | BLOCKED_ON)
#   bsi-query.sh health        → dernière session : health_score + type
#   bsi-query.sh peers         → claims open sur toutes les instances (SSH)
#
# Retour :
#   Exit 0 = succès (même si 0 résultats)
#   Exit 1 = brain.db absent (fallback : utiliser grep BRAIN-INDEX.md)
#   Exit 2 = erreur Python
#
# Sécurité : lecture seule sur brain.db — aucune écriture
# Fallback  : si brain.db absent → le script sort 1, l'appelant gère

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_PATH="$BRAIN_ROOT/brain.db"
CMD="${1:-help}"

# Fallback propre si brain.db absent
if [[ ! -f "$DB_PATH" ]]; then
    echo "⚠️  brain.db absent ($DB_PATH) — lancer: python3 brain-engine/migrate.py" >&2
    exit 1
fi

run_query() {
    python3 - "$DB_PATH" "$@" <<'PYEOF'
import sqlite3, sys, os

db_path = sys.argv[1]
cmd     = sys.argv[2] if len(sys.argv) > 2 else 'help'

conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
conn.row_factory = sqlite3.Row

if cmd == 'open':
    rows = conn.execute("""
        SELECT sess_id, scope, opened_at,
               ROUND((julianday('now') - julianday(opened_at)) * 24, 1) AS age_h
        FROM claims WHERE status = 'open'
        ORDER BY opened_at DESC
    """).fetchall()
    for r in rows:
        print(f"{r['sess_id']} | {r['scope']} | {r['opened_at']} | {r['age_h']}h")

elif cmd == 'stale':
    rows = conn.execute("""
        SELECT sess_id, scope, opened_at,
               ROUND((julianday('now') - julianday(opened_at)) * 24, 1) AS age_h
        FROM claims
        WHERE status = 'open'
          AND julianday('now') > julianday(opened_at, '+4 hours')
        ORDER BY age_h DESC
    """).fetchall()
    for r in rows:
        print(f"{r['sess_id']} | {r['scope']} | {r['opened_at']} | {r['age_h']}h")

elif cmd == 'count-open':
    n = conn.execute("SELECT COUNT(*) FROM claims WHERE status='open'").fetchone()[0]
    print(n)

elif cmd == 'count-stale':
    n = conn.execute("""
        SELECT COUNT(*) FROM claims
        WHERE status='open'
          AND julianday('now') > julianday(opened_at, '+4 hours')
    """).fetchone()[0]
    print(n)

elif cmd == 'signals':
    rows = conn.execute("""
        SELECT sig_id, type, from_sess, to_sess, projet, payload
        FROM signals
        WHERE state = 'pending'
          AND type IN ('CHECKPOINT','HANDOFF','BLOCKED_ON')
        ORDER BY created_at DESC
    """).fetchall()
    for r in rows:
        print(f"{r['sig_id']} | {r['type']} | {r['from_sess']} → {r['to_sess']} | {r['projet']}")

elif cmd == 'health':
    row = conn.execute("""
        SELECT sess_id, date, type, health_score, cold_start_kpi_pass
        FROM sessions
        ORDER BY date DESC, sess_id DESC
        LIMIT 1
    """).fetchone()
    if row:
        kpi = {1:'✅', 0:'❌', None:'—'}.get(row['cold_start_kpi_pass'], '—')
        print(f"{row['sess_id']} | {row['type']} | health={row['health_score']} | cold_start={kpi}")
    else:
        print("aucune session dans brain.db")

else:
    print("Usage: bsi-query.sh open|stale|count-open|count-stale|signals|health", file=sys.stderr)
    sys.exit(0)

conn.close()
PYEOF
}

# ── Commande peers : interroge les instances distantes via SSH ─────────
if [[ "$CMD" == "peers" ]]; then
    COMPOSE_LOCAL="$BRAIN_ROOT/brain-compose.local.yml"
    MACHINE=$(python3 -c "
import yaml
with open('$COMPOSE_LOCAL') as f:
    print(yaml.safe_load(f).get('machine', 'unknown'))
" 2>/dev/null || echo "unknown")

    echo "🖥  $MACHINE (local)"
    run_query "open"

    # Interroger chaque peer
    python3 -c "
import yaml, subprocess, sys
with open('$COMPOSE_LOCAL') as f:
    c = yaml.safe_load(f)
peers = c.get('peers', {})
for name, info in peers.items():
    if not info.get('active', False):
        continue
    url = info.get('url', '')
    host = url.replace('http://','').replace('https://','').split(':')[0]
    print(f'PEER:{name}:{host}')
" 2>/dev/null | while IFS=: read -r _ name host; do
        echo ""
        echo "💻 $name ($host)"
        ssh_user="${SSH_USER:-$(whoami)}"
        result=$(ssh -o BatchMode=yes -o ConnectTimeout=3 "${ssh_user}@${host}" \
            "cd \$BRAIN_ROOT && bash scripts/bsi-query.sh open" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
        else
            echo "  (aucun claim ouvert ou machine injoignable)"
        fi
    done
    exit 0
fi

run_query "$CMD"
