#!/usr/bin/env python3
"""
migrate-claims-to-db.py — Migration one-shot : claims/*.yml → brain.db
ADR-036 : BSI hors git — les claims deviennent la source de vérité dans brain.db.

Usage :
  python3 scripts/migrate-claims-to-db.py              → migrer tout
  python3 scripts/migrate-claims-to-db.py --dry-run    → preview sans écriture
  python3 scripts/migrate-claims-to-db.py --archive    → migrer + archiver les .yml

Idempotent : INSERT OR IGNORE sur sess_id PRIMARY KEY.
"""

import os
import re
import sys
import sqlite3
import shutil
from pathlib import Path
from datetime import datetime, timedelta

BRAIN_ROOT = Path(__file__).parent.parent
CLAIMS_DIR = BRAIN_ROOT / 'claims'
DB_PATH    = BRAIN_ROOT / 'brain.db'
ARCHIVE_DIR = BRAIN_ROOT / 'archive' / 'claims-git-era'

# Kernel scopes — synchronisé avec KERNEL.md
KERNEL_SCOPES = ['agents/', 'profil/', 'scripts/', 'KERNEL.md',
                 'brain-constitution.md', 'brain-compose.yml']
PERSONAL_SCOPES = ['profil/capital', 'profil/objectifs', 'progression/', 'MYSECRETS']


def extract(content, *patterns, default=''):
    """Extract first matching pattern from content."""
    for p in patterns:
        m = re.search(p, content, re.MULTILINE)
        if m:
            return m.group(1).strip().strip('"\'')
    return default


def infer_zone(scope):
    """Infer zone from scope — ADR-014."""
    for ks in KERNEL_SCOPES:
        if ks in scope:
            return 'kernel'
    for ps in PERSONAL_SCOPES:
        if ps in scope:
            return 'personal'
    return 'project'


def parse_claim(filepath):
    """Parse a claim YAML file into a dict."""
    with open(filepath, 'r') as f:
        content = f.read()

    sess_id = extract(content, r'^sess_id:\s*(.+)', r'^name:\s*(sess-.+)')
    if not sess_id:
        return None

    scope = extract(content, r'^scope:\s*(.+)')
    status = extract(content, r'^status:\s*(.+)', default='closed')
    opened_at = extract(content, r'^opened_at:\s*(.+)', r'^opened:\s*(.+)')
    type_ = extract(content, r'^type:\s*(.+)', default='work')
    handoff = extract(content, r'^handoff_level:\s*(.+)')
    story = extract(content, r'^story_angle:\s*(.+)')
    parent = extract(content, r'^parent_satellite:\s*(.+)')
    sat_type = extract(content, r'^satellite_type:\s*(.+)')
    sat_level = extract(content, r'^satellite_level:\s*(.+)')
    theme_branch = extract(content, r'^theme_branch:\s*(.+)')
    zone = extract(content, r'^zone:\s*(.+)') or infer_zone(scope)
    mode = extract(content, r'^mode:\s*(.+)')

    # Check if TTL expired → mark stale
    if status == 'open' and opened_at:
        try:
            opened_dt = datetime.fromisoformat(opened_at.replace('Z', '+00:00'))
            if datetime.now(opened_dt.tzinfo or None) - opened_dt.replace(tzinfo=None) > timedelta(hours=4):
                status = 'stale'
        except (ValueError, TypeError):
            pass

    return {
        'sess_id': sess_id,
        'type': type_,
        'scope': scope,
        'status': status,
        'opened_at': opened_at,
        'handoff_level': handoff or None,
        'story_angle': story or None,
        'parent_sess': parent or None,
        'satellite_type': sat_type or None,
        'satellite_level': sat_level or None,
        'theme_branch': theme_branch or None,
        'zone': zone,
        'mode': mode or None,
        'ttl_hours': 4,
    }


def main():
    dry_run = '--dry-run' in sys.argv
    archive = '--archive' in sys.argv

    if not CLAIMS_DIR.exists():
        print(f"❌ claims/ introuvable : {CLAIMS_DIR}")
        sys.exit(1)

    yml_files = sorted(CLAIMS_DIR.glob('sess-*.yml'))
    print(f"📦 {len(yml_files)} fichiers claims trouvés")

    if dry_run:
        print("   (mode dry-run — aucune écriture)")

    conn = sqlite3.connect(str(DB_PATH))
    conn.execute("PRAGMA journal_mode=WAL")

    migrated = 0
    skipped = 0
    stale_marked = 0
    errors = 0

    for yml in yml_files:
        claim = parse_claim(yml)
        if not claim:
            print(f"  ⚠️  SKIP {yml.name} — pas de sess_id")
            skipped += 1
            continue

        if claim['status'] == 'stale':
            stale_marked += 1

        if dry_run:
            print(f"  → {claim['sess_id']} | {claim['status']} | {claim['scope'][:40]}")
            migrated += 1
            continue

        try:
            conn.execute("""
                INSERT OR IGNORE INTO claims
                    (sess_id, type, scope, status, opened_at, handoff_level,
                     story_angle, parent_sess, satellite_type, satellite_level,
                     theme_branch, zone, mode, ttl_hours)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                claim['sess_id'], claim['type'], claim['scope'],
                claim['status'], claim['opened_at'], claim['handoff_level'],
                claim['story_angle'], claim['parent_sess'],
                claim['satellite_type'], claim['satellite_level'],
                claim['theme_branch'], claim['zone'], claim['mode'],
                claim['ttl_hours'],
            ))
            migrated += 1
        except Exception as e:
            print(f"  ❌ ERROR {yml.name} : {e}")
            errors += 1

    conn.commit()
    conn.close()

    print(f"\n✅ Migration terminée :")
    print(f"   Migrés   : {migrated}")
    print(f"   Skippés  : {skipped}")
    print(f"   Stale    : {stale_marked} (open > 4h → marqués stale)")
    print(f"   Erreurs  : {errors}")

    if archive and not dry_run:
        ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
        for yml in yml_files:
            shutil.move(str(yml), str(ARCHIVE_DIR / yml.name))
        print(f"\n📁 {len(yml_files)} fichiers archivés → {ARCHIVE_DIR}")
        print("   → Ajouter 'claims/' à .gitignore pour finaliser")


if __name__ == '__main__':
    main()
