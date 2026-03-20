#!/usr/bin/env python3
"""
brain-engine/migrate.py — Migration BE-1 + BE-2b
Ingère les sources existantes du brain dans brain.db

Sources :
  - claims/*.yml        → table claims
  - BRAIN-INDEX.md ## Signals → table signals (parsing markdown)
  - handoffs/*.md       → table handoffs (parsing frontmatter)
  - claims → sessions   → table sessions (dérivée depuis claims, BE-2b)

Usage :
  python3 brain-engine/migrate.py [--dry-run] [--reset]

Anti-drift :
  - Lecture seule sur les sources — jamais de modification des .md
  - Idempotent — relancer ne duplique pas les données (UPSERT)
  - En cas d'erreur parsing → warning + skip, pas de crash
"""

import sqlite3
import os
import re
import sys
import argparse
from datetime import datetime

BRAIN_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BRAIN_ROOT, 'brain.db')
SCHEMA_PATH = os.path.join(BRAIN_ROOT, 'brain-engine', 'schema.sql')


def connect(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    return conn


def init_schema(conn: sqlite3.Connection):
    with open(SCHEMA_PATH) as f:
        schema = f.read()
    conn.executescript(schema)
    conn.commit()
    print(f"✅ Schema initialisé depuis {SCHEMA_PATH}")


def parse_yml_field(content: str, field: str, default=None) -> str:
    """Extrait un champ YAML simple (pas de parsing YAML complet — volontaire)."""
    m = re.search(rf'^{re.escape(field)}:\s*(.+)', content, re.MULTILINE)
    if m:
        return m.group(1).strip().strip('"\'')
    return default


def migrate_claims(conn: sqlite3.Connection, dry_run: bool = False) -> int:
    """Migre claims/*.yml → table claims."""
    claims_dir = os.path.join(BRAIN_ROOT, 'claims')
    if not os.path.isdir(claims_dir):
        print(f"⚠️  claims/ introuvable : {claims_dir}")
        return 0

    count = 0
    for filename in sorted(os.listdir(claims_dir)):
        if not filename.startswith('sess-') or not filename.endswith('.yml'):
            continue

        filepath = os.path.join(claims_dir, filename)
        try:
            with open(filepath) as f:
                content = f.read()
        except Exception as e:
            print(f"  ⚠️  {filename} : erreur lecture — {e}")
            continue

        # Gère v1 (name:) et v2 (sess_id:)
        sess_id = parse_yml_field(content, 'sess_id') or \
                  parse_yml_field(content, 'name', filename.replace('.yml', ''))
        scope        = parse_yml_field(content, 'scope', '—')
        status       = parse_yml_field(content, 'status', 'closed')
        opened_at    = parse_yml_field(content, 'opened_at') or \
                       parse_yml_field(content, 'opened', '—')
        closed_at    = parse_yml_field(content, 'closed_at') or \
                       parse_yml_field(content, 'closed')
        sess_type    = parse_yml_field(content, 'type', 'brain')
        handoff_lvl  = parse_yml_field(content, 'handoff_level')
        story_angle  = parse_yml_field(content, 'story_angle')

        if not sess_id or sess_id == '—':
            print(f"  ⚠️  {filename} : sess_id introuvable — skippé")
            continue

        if not dry_run:
            conn.execute("""
                INSERT INTO claims(sess_id, type, scope, status, opened_at, closed_at,
                                   handoff_level, story_angle)
                VALUES (?,?,?,?,?,?,?,?)
                ON CONFLICT(sess_id) DO UPDATE SET
                    status=excluded.status,
                    closed_at=excluded.closed_at,
                    story_angle=excluded.story_angle
            """, (sess_id, sess_type, scope, status, opened_at, closed_at,
                  handoff_lvl, story_angle))
        else:
            print(f"  [dry] claim: {sess_id} | {status} | {scope}")

        count += 1

    if not dry_run:
        conn.commit()
    print(f"✅ Claims migrés : {count}")
    return count


def migrate_signals(conn: sqlite3.Connection, dry_run: bool = False) -> int:
    """Migre ## Signals depuis BRAIN-INDEX.md → table signals."""
    index_path = os.path.join(BRAIN_ROOT, 'BRAIN-INDEX.md')
    if not os.path.exists(index_path):
        print(f"⚠️  BRAIN-INDEX.md introuvable")
        return 0

    with open(index_path) as f:
        content = f.read()

    # Extraire la section ## Signals
    m = re.search(r'## Signals.*?\n(.*?)(?=\n##|\Z)', content, re.DOTALL)
    if not m:
        print("⚠️  Section ## Signals non trouvée dans BRAIN-INDEX.md")
        return 0

    signals_section = m.group(1)

    # Parser le tableau markdown
    # Format : | sig_id | De | Pour | Type | Concerné | Payload | État |
    row_pattern = re.compile(
        r'^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|',
        re.MULTILINE
    )

    count = 0
    for m in row_pattern.finditer(signals_section):
        sig_id, from_sess, to_sess, sig_type, projet, payload, state = [
            v.strip() for v in m.groups()
        ]

        # Ignorer les lignes d'en-tête
        if sig_id.startswith('ID') or sig_id.startswith('-'):
            continue
        if not sig_id.startswith('sig-'):
            continue

        VALID_TYPES = {'READY_FOR_REVIEW', 'REVIEWED', 'BLOCKED_ON', 'HANDOFF', 'CHECKPOINT', 'INFO'}
        if sig_type not in VALID_TYPES:
            continue

        state = state.lower().strip()
        if state not in ('pending', 'delivered', 'archived'):
            state = 'delivered'

        if not dry_run:
            conn.execute("""
                INSERT INTO signals(sig_id, from_sess, to_sess, type, projet, payload, state, created_at)
                VALUES (?,?,?,?,?,?,?,?)
                ON CONFLICT(sig_id) DO UPDATE SET state=excluded.state
            """, (sig_id, from_sess, to_sess, sig_type, projet, payload, state,
                  datetime.now().isoformat()))
        else:
            print(f"  [dry] signal: {sig_id} | {sig_type} | {state}")

        count += 1

    if not dry_run:
        conn.commit()
    print(f"✅ Signals migrés : {count}")
    return count


def migrate_handoffs(conn: sqlite3.Connection, dry_run: bool = False) -> int:
    """Migre handoffs/*.md → table handoffs."""
    handoffs_dir = os.path.join(BRAIN_ROOT, 'handoffs')
    if not os.path.isdir(handoffs_dir):
        print(f"⚠️  handoffs/ introuvable : {handoffs_dir}")
        return 0

    count = 0
    for filename in sorted(os.listdir(handoffs_dir)):
        if not filename.endswith('.md') or filename.startswith('_'):
            continue

        filepath = os.path.join(handoffs_dir, filename)
        try:
            with open(filepath) as f:
                content = f.read()
        except Exception as e:
            print(f"  ⚠️  {filename} : erreur lecture — {e}")
            continue

        # Extraire le frontmatter
        fm_match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
        if not fm_match:
            continue

        fm = fm_match.group(1)
        htype    = parse_yml_field(fm, 'type', 'HANDOFF')
        projet   = parse_yml_field(fm, 'projet') or parse_yml_field(fm, 'project')
        status   = parse_yml_field(fm, 'status', 'active')
        from_s   = parse_yml_field(fm, 'from') or parse_yml_field(fm, 'source')
        created  = parse_yml_field(fm, 'created') or parse_yml_field(fm, 'date',
                   datetime.now().strftime('%Y-%m-%d'))

        if status not in ('active', 'consumed', 'archived'):
            status = 'active'

        if not dry_run:
            conn.execute("""
                INSERT INTO handoffs(filename, type, projet, status, from_sess, created_at)
                VALUES (?,?,?,?,?,?)
                ON CONFLICT(filename) DO UPDATE SET status=excluded.status
            """, (filename, htype, projet, status, from_s, created))
        else:
            print(f"  [dry] handoff: {filename} | {status}")

        count += 1

    if not dry_run:
        conn.commit()
    print(f"✅ Handoffs migrés : {count}")
    return count


def migrate_sessions(conn: sqlite3.Connection, dry_run: bool = False) -> int:
    """
    Peuple la table sessions depuis claims (BE-2b).

    Stratégie : claims = sessions — chaque claim est une session brain.
    Les champs metabolism (tokens_used, duration_min, etc.) restent NULL
    jusqu'à ce que metabolism-scribe les alimente directement.

    Mapping :
      claims.sess_id       → sessions.sess_id
      claims.opened_at     → sessions.date (partie date uniquement)
      claims.type          → sessions.type
      claims.handoff_level → sessions.handoff_level
      claims.health_score  → sessions.health_score (si présent dans yml)
      claims.cold_start_kpi_pass → sessions.cold_start_kpi_pass
    """
    if dry_run:
        rows = conn.execute("SELECT COUNT(*) as n FROM claims").fetchone()
        print(f"  [dry] sessions à créer depuis claims : {rows['n']}")
        return rows['n']

    # UPSERT : ne pas écraser les champs metabolism déjà renseignés
    conn.execute("""
        INSERT INTO sessions(sess_id, date, type, handoff_level, health_score, cold_start_kpi_pass)
        SELECT
            c.sess_id,
            SUBSTR(c.opened_at, 1, 10)  AS date,
            c.type,
            c.handoff_level,
            c.health_score,
            c.cold_start_kpi_pass
        FROM claims c
        WHERE TRUE
        ON CONFLICT(sess_id) DO UPDATE SET
            date                = COALESCE(excluded.date, sessions.date),
            type                = COALESCE(excluded.type, sessions.type),
            handoff_level       = COALESCE(excluded.handoff_level, sessions.handoff_level),
            health_score        = COALESCE(excluded.health_score, sessions.health_score),
            cold_start_kpi_pass = COALESCE(excluded.cold_start_kpi_pass, sessions.cold_start_kpi_pass)
    """)
    conn.commit()

    count = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
    kpi_row = conn.execute("""
        SELECT
            COUNT(*) as total,
            SUM(CASE WHEN cold_start_kpi_pass = 1 THEN 1 ELSE 0 END) as passes
        FROM sessions WHERE handoff_level = 'NO'
    """).fetchone()

    print(f"✅ Sessions migrées : {count}")
    if kpi_row and kpi_row[0] > 0:
        print(f"   cold_start KPI (handoff=NO) : {kpi_row[1]}/{kpi_row[0]} passes")
    return count


def main():
    parser = argparse.ArgumentParser(description='Brain state engine — migration BE-1 + BE-2b')
    parser.add_argument('--dry-run', action='store_true', help='Simulation sans écriture')
    parser.add_argument('--reset', action='store_true', help='Supprimer brain.db avant migration')
    parser.add_argument('--sessions-only', action='store_true', help='Rejouer uniquement migrate_sessions')
    args = parser.parse_args()

    if args.reset and os.path.exists(DB_PATH):
        os.remove(DB_PATH)
        print(f"♻️  brain.db supprimé — reconstruction depuis zéro")

    print(f"Brain root : {BRAIN_ROOT}")
    print(f"DB path    : {DB_PATH}")
    print(f"Mode       : {'DRY RUN' if args.dry_run else 'WRITE'}")
    print()

    conn = connect(DB_PATH)
    init_schema(conn)

    if args.sessions_only:
        print("\n── Sessions (replay) ───────────────────")
        migrate_sessions(conn, dry_run=args.dry_run)
    else:
        print("\n── Claims ──────────────────────────────")
        migrate_claims(conn, dry_run=args.dry_run)

        print("\n── Signals ─────────────────────────────")
        migrate_signals(conn, dry_run=args.dry_run)

        print("\n── Handoffs ────────────────────────────")
        migrate_handoffs(conn, dry_run=args.dry_run)

        print("\n── Sessions ────────────────────────────")
        migrate_sessions(conn, dry_run=args.dry_run)

    if not args.dry_run:
        # Vérification finale
        print("\n── Vérification ────────────────────────")
        for table in ('claims', 'signals', 'handoffs', 'agent_memory', 'sessions'):
            row = conn.execute(f"SELECT COUNT(*) as n FROM {table}").fetchone()
            print(f"  {table:<15} : {row['n']} entrées")

        print("\n── Vues ────────────────────────────────")
        row = conn.execute("SELECT * FROM v_open_claims").fetchall()
        print(f"  v_open_claims  : {len(row)} claim(s) open")
        row = conn.execute("SELECT * FROM v_stale_claims").fetchall()
        if row:
            print(f"  ⚠️  v_stale_claims : {len(row)} claim(s) stale !")
        else:
            print(f"  v_stale_claims : ✅ aucun stale")
        row = conn.execute("SELECT * FROM v_cold_start_kpi").fetchone()
        if row and row['total_no_handoff'] > 0:
            rate = row['pass_rate_pct'] or 0
            print(f"  v_cold_start_kpi: {row['passes']}/{row['total_no_handoff']} passes ({rate:.0f}%)")

    conn.close()
    print(f"\n✅ Migration terminée — brain.db prêt")


if __name__ == '__main__':
    main()
