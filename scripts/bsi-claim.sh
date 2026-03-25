#!/usr/bin/env bash
# bsi-claim.sh — Open/close claims dans Dolt (source unique — ADR-042)
#
# Usage :
#   bsi-claim.sh open  <sess_id> [--scope X] [--type X] [--zone X] [--mode X] [--story "X"]
#   bsi-claim.sh close <sess_id> [--result X]
#   bsi-claim.sh close-stale          → ferme tous les claims open > TTL (4h par défaut)
#   bsi-claim.sh exists <sess_id>     → exit 0 si open, exit 1 sinon
#   bsi-claim.sh init                 → vérifie Dolt repo + table claims
#
# Backend : Dolt (MySQL-compatible, version-controlled)
# Garantie tier free : python3 + dolt CLI — zéro serveur requis.
# Auto-init : si brain-dolt/ absent → dolt init automatique.
#
# Exit codes :
#   0 = succès
#   1 = argument manquant / erreur usage
#   2 = erreur Python / DB

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOLT_DIR="$BRAIN_ROOT/brain-dolt"
CMD="${1:-help}"
shift || true

python3 - "$DOLT_DIR" "$CMD" "$@" <<'PYEOF'
import subprocess
import sys
import csv
import io
import os
from datetime import datetime, timezone

dolt_dir = sys.argv[1]
cmd = sys.argv[2] if len(sys.argv) > 2 else "help"
args = sys.argv[3:]

def dolt_sql(query, expect_rows=False):
    """Execute a SQL query via dolt sql CLI. Returns list of dicts if expect_rows."""
    fmt = ["-r", "csv"] if expect_rows else []
    result = subprocess.run(
        ["dolt", "sql", "-q", query] + fmt,
        cwd=dolt_dir,
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"❌ Dolt SQL error: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(2)
    if expect_rows and result.stdout.strip():
        reader = csv.DictReader(io.StringIO(result.stdout))
        return list(reader)
    return []

def dolt_commit(message):
    """Stage all changes and commit to Dolt."""
    subprocess.run(["dolt", "add", "."], cwd=dolt_dir, capture_output=True)
    result = subprocess.run(
        ["dolt", "commit", "-m", message],
        cwd=dolt_dir, capture_output=True, text=True
    )
    # Silently ignore "nothing to commit"
    return result.returncode == 0

def esc(val):
    """Escape a string for SQL. Returns 'NULL' for None."""
    if val is None:
        return "NULL"
    return "'" + val.replace("'", "''") + "'"

def ensure_init():
    """Ensure Dolt repo exists with claims table."""
    if not os.path.isdir(os.path.join(dolt_dir, ".dolt")):
        os.makedirs(dolt_dir, exist_ok=True)
        subprocess.run(
            ["dolt", "init", "--name", "tetardtek", "--email", "tetardtek@tetardtek.com"],
            cwd=dolt_dir, capture_output=True
        )
    # Check table exists (Dolt schema is managed separately — schema.sql)
    rows = dolt_sql("SELECT COUNT(*) as n FROM claims", expect_rows=True)
    return int(rows[0]["n"]) if rows else 0

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
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    ensure_init()

    # Vérifier si déjà open
    existing = dolt_sql(
        f"SELECT status FROM claims WHERE sess_id = {esc(sess_id)}", expect_rows=True
    )
    if existing and existing[0].get("status") == "open":
        print(f"⚠️  Claim déjà ouvert : {sess_id}")
        sys.exit(0)

    new_scope = opts.get("scope", "brain/")

    # Scope overlap detection — BSI mutex
    open_claims = dolt_sql(
        "SELECT sess_id, scope, zone FROM claims WHERE status = 'open'", expect_rows=True
    )

    for oc in open_claims:
        oc_scope = oc.get("scope") or ""
        if (new_scope.startswith(oc_scope) or oc_scope.startswith(new_scope)
                or new_scope == oc_scope):
            oc_zone = oc.get("zone") or "project"

            # Zone kernel = hard block
            if oc_zone == "kernel" or opts.get("zone") == "kernel":
                print(f"🔴 SCOPE CONFLICT — zone kernel verrouillée")
                print(f"   Existant : {oc['sess_id']} → scope: {oc_scope} (zone: {oc_zone})")
                print(f"   Demandé  : {sess_id} → scope: {new_scope}")
                print(f"   → Fermer le claim existant d'abord : bsi-claim.sh close {oc['sess_id']}")
                sys.exit(1)

            # Zone project = soft warning
            print(f"⚠️  SCOPE OVERLAP détecté")
            print(f"   Existant : {oc['sess_id']} → scope: {oc_scope}")
            print(f"   Demandé  : {sess_id} → scope: {new_scope}")
            print(f"   → Parallélisme autorisé — attention aux conflits d'écriture")

    claim_type = esc(opts.get("type", "navigate"))
    zone = esc(opts.get("zone", "project"))
    mode = esc(opts.get("mode"))
    story = esc(opts.get("story"))
    handoff = esc(opts.get("handoff", "0"))
    instance = esc(opts.get("instance"))

    dolt_sql(f"""
        REPLACE INTO claims
            (sess_id, type, scope, status, opened_at, zone, mode, story_angle,
             handoff_level, instance, ttl_hours, expires_at)
        VALUES ({esc(sess_id)}, {claim_type}, {esc(new_scope)}, 'open', {esc(now)},
                {zone}, {mode}, {story}, {handoff}, {instance},
                4.0, DATE_ADD({esc(now)}, INTERVAL 4 HOUR))
    """)

    dolt_commit(f"bsi: open claim {sess_id}")
    print(f"✅ Claim ouvert : {sess_id}")

def cmd_close():
    if not args:
        print("❌ Usage: bsi-claim.sh close <sess_id> [--result X]", file=sys.stderr)
        sys.exit(1)

    sess_id = args[0]
    opts = parse_opts(args[1:])
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    result_status = esc(opts.get("result", "success"))

    ensure_init()

    # Check if open first
    existing = dolt_sql(
        f"SELECT sess_id FROM claims WHERE sess_id = {esc(sess_id)} AND status = 'open'",
        expect_rows=True
    )

    if not existing:
        print(f"⚠️  Claim non trouvé ou déjà fermé : {sess_id}")
        return

    dolt_sql(f"""
        UPDATE claims
        SET status = 'closed', closed_at = {esc(now)}, result_status = {result_status}
        WHERE sess_id = {esc(sess_id)} AND status = 'open'
    """)

    dolt_commit(f"bsi: close claim {sess_id}")
    print(f"✅ Claim fermé : {sess_id}")

def cmd_close_stale():
    ensure_init()

    # Find stale claims first
    stale = dolt_sql("""
        SELECT sess_id FROM claims
        WHERE status = 'open'
          AND TIMESTAMPDIFF(HOUR, opened_at, NOW()) > COALESCE(ttl_hours, 4)
    """, expect_rows=True)

    if not stale:
        print("ℹ️  Aucun claim stale")
        return

    dolt_sql("""
        UPDATE claims
        SET status = 'closed',
            closed_at = NOW(),
            result_status = 'stale-auto-closed'
        WHERE status = 'open'
          AND TIMESTAMPDIFF(HOUR, opened_at, NOW()) > COALESCE(ttl_hours, 4)
    """)

    n = len(stale)
    dolt_commit(f"bsi: auto-close {n} stale claim(s)")
    print(f"✅ {n} claim(s) stale fermé(s)")

def cmd_exists():
    if not args:
        print("❌ Usage: bsi-claim.sh exists <sess_id>", file=sys.stderr)
        sys.exit(1)

    ensure_init()
    rows = dolt_sql(
        f"SELECT status FROM claims WHERE sess_id = {esc(args[0])} AND status = 'open'",
        expect_rows=True
    )
    sys.exit(0 if rows else 1)

def cmd_init():
    n = ensure_init()
    print(f"✅ brain-dolt prêt — table claims ({n} entrées)")

def cmd_help():
    print("Usage: bsi-claim.sh <open|close|close-stale|exists|init>")
    print("  open  <sess_id> [--scope X] [--type X] [--zone X] [--mode X] [--story 'X']")
    print("  close <sess_id> [--result X]")
    print("  close-stale       — ferme les claims open > TTL")
    print("  exists <sess_id>  — exit 0 si open, exit 1 sinon")
    print("  init              — vérifie Dolt repo + table claims")

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
