#!/usr/bin/env bash
# bsi-claim.sh — Open/close claims dans brain.db (source unique — ADR-042)
#
# Usage :
#   bsi-claim.sh open  <sess_id> [--scope X] [--type X] [--zone X] [--mode X] [--story "X"]
#   bsi-claim.sh close <sess_id> [--result X]
#   bsi-claim.sh close-stale          → ferme tous les claims open > TTL (4h par défaut)
#   bsi-claim.sh exists <sess_id>     → exit 0 si open, exit 1 sinon
#   bsi-claim.sh init                 → crée brain.db + table claims si absent
#
# Garantie tier free : python3 + sqlite3 stdlib — zéro dépendance externe.
# Auto-init : si brain.db ou table claims absente → créée automatiquement.
#
# Exit codes :
#   0 = succès
#   1 = argument manquant / erreur usage
#   2 = erreur Python / DB

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_PATH="$BRAIN_ROOT/brain.db"
CMD="${1:-help}"
shift || true

python3 - "$DB_PATH" "$CMD" "$@" <<'PYEOF'
import sqlite3
import sys
from datetime import datetime, timezone

db_path = sys.argv[1]
cmd = sys.argv[2] if len(sys.argv) > 2 else "help"
args = sys.argv[3:]

CLAIMS_SCHEMA = """
CREATE TABLE IF NOT EXISTS claims (
    sess_id TEXT PRIMARY KEY,
    type TEXT,
    scope TEXT,
    status TEXT DEFAULT 'open',
    opened_at TEXT,
    closed_at TEXT,
    handoff_level TEXT,
    story_angle TEXT,
    health_score REAL,
    context_at_close REAL,
    cold_start_kpi_pass INTEGER,
    ttl_hours REAL DEFAULT 4.0,
    expires_at TEXT,
    instance TEXT,
    parent_sess TEXT,
    satellite_type TEXT,
    satellite_level TEXT,
    theme_branch TEXT,
    zone TEXT,
    mode TEXT,
    workflow TEXT,
    workflow_step INTEGER,
    result_status TEXT,
    result_json TEXT
)
"""

def get_db():
    """Connect and ensure table exists (auto-init for fresh forks)."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute(CLAIMS_SCHEMA)
    conn.commit()
    return conn

def parse_opts(args):
    """Parse --key value pairs from args."""
    opts = {}
    i = 0
    while i < len(args):
        if args[i].startswith("--") and i + 1 < len(args):
            opts[args[i][2:]] = args[i + 1]
            i += 2
        else:
            i += 1
    return opts

def cmd_open():
    if not args:
        print("❌ Usage: bsi-claim.sh open <sess_id> [--scope X] [--type X] ...", file=sys.stderr)
        sys.exit(1)

    sess_id = args[0]
    opts = parse_opts(args[1:])
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M")

    conn = get_db()

    # Vérifier si déjà open
    existing = conn.execute(
        "SELECT status FROM claims WHERE sess_id = ?", (sess_id,)
    ).fetchone()
    if existing and existing["status"] == "open":
        print(f"⚠️  Claim déjà ouvert : {sess_id}")
        conn.close()
        sys.exit(0)

    new_scope = opts.get("scope", "brain/")

    # Scope overlap detection — BSI mutex
    open_claims = conn.execute(
        "SELECT sess_id, scope, zone FROM claims WHERE status = 'open'"
    ).fetchall()

    for oc in open_claims:
        oc_scope = oc["scope"] or ""
        # Overlap = un scope est préfixe de l'autre, ou identique
        if (new_scope.startswith(oc_scope) or oc_scope.startswith(new_scope)
                or new_scope == oc_scope):
            oc_zone = oc["zone"] or "project"

            # Zone kernel = hard block
            if oc_zone == "kernel" or opts.get("zone") == "kernel":
                print(f"🔴 SCOPE CONFLICT — zone kernel verrouillée")
                print(f"   Existant : {oc['sess_id']} → scope: {oc_scope} (zone: {oc_zone})")
                print(f"   Demandé  : {sess_id} → scope: {new_scope}")
                print(f"   → Fermer le claim existant d'abord : bsi-claim.sh close {oc['sess_id']}")
                conn.close()
                sys.exit(1)

            # Zone project = soft warning (parallélisme autorisé avec avertissement)
            print(f"⚠️  SCOPE OVERLAP détecté")
            print(f"   Existant : {oc['sess_id']} → scope: {oc_scope}")
            print(f"   Demandé  : {sess_id} → scope: {new_scope}")
            print(f"   → Parallélisme autorisé — attention aux conflits d'écriture")

    conn.execute("""
        INSERT OR REPLACE INTO claims
            (sess_id, type, scope, status, opened_at, zone, mode, story_angle,
             handoff_level, instance, ttl_hours, expires_at)
        VALUES (?, ?, ?, 'open', ?, ?, ?, ?, ?, ?, 4.0, datetime(?, '+4 hours'))
    """, (
        sess_id,
        opts.get("type", "navigate"),
        new_scope,
        now,
        opts.get("zone", "project"),
        opts.get("mode"),
        opts.get("story"),
        opts.get("handoff", "0"),
        opts.get("instance"),
        now,
    ))
    conn.commit()
    conn.close()
    print(f"✅ Claim ouvert : {sess_id}")

def cmd_close():
    if not args:
        print("❌ Usage: bsi-claim.sh close <sess_id> [--result X]", file=sys.stderr)
        sys.exit(1)

    sess_id = args[0]
    opts = parse_opts(args[1:])
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M")

    conn = get_db()
    cur = conn.execute(
        "UPDATE claims SET status = 'closed', closed_at = ?, result_status = ? WHERE sess_id = ? AND status = 'open'",
        (now, opts.get("result", "success"), sess_id)
    )
    conn.commit()

    if cur.rowcount == 0:
        print(f"⚠️  Claim non trouvé ou déjà fermé : {sess_id}")
    else:
        print(f"✅ Claim fermé : {sess_id}")
    conn.close()

def cmd_close_stale():
    conn = get_db()
    cur = conn.execute("""
        UPDATE claims
        SET status = 'closed',
            closed_at = datetime('now'),
            result_status = 'stale-auto-closed'
        WHERE status = 'open'
          AND julianday('now') > julianday(opened_at, '+' || COALESCE(ttl_hours, 4) || ' hours')
    """)
    conn.commit()
    n = cur.rowcount
    if n > 0:
        print(f"✅ {n} claim(s) stale fermé(s)")
    else:
        print("ℹ️  Aucun claim stale")
    conn.close()

def cmd_exists():
    if not args:
        print("❌ Usage: bsi-claim.sh exists <sess_id>", file=sys.stderr)
        sys.exit(1)

    conn = get_db()
    row = conn.execute(
        "SELECT status FROM claims WHERE sess_id = ? AND status = 'open'", (args[0],)
    ).fetchone()
    conn.close()
    sys.exit(0 if row else 1)

def cmd_init():
    conn = get_db()
    n = conn.execute("SELECT COUNT(*) FROM claims").fetchone()[0]
    conn.close()
    print(f"✅ brain.db prêt — table claims ({n} entrées)")

def cmd_help():
    print("Usage: bsi-claim.sh <open|close|close-stale|exists|init>")
    print("  open  <sess_id> [--scope X] [--type X] [--zone X] [--mode X] [--story 'X']")
    print("  close <sess_id> [--result X]")
    print("  close-stale       — ferme les claims open > TTL")
    print("  exists <sess_id>  — exit 0 si open, exit 1 sinon")
    print("  init              — crée brain.db + table si absent")

commands = {
    "open": cmd_open,
    "close": cmd_close,
    "close-stale": cmd_close_stale,
    "exists": cmd_exists,
    "init": cmd_init,
    "help": cmd_help,
}

fn = commands.get(cmd, cmd_help)
fn()
PYEOF
