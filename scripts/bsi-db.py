#!/usr/bin/env python3
"""
bsi-db.py — Wrapper SQLite léger pour les scripts BSI bash.
Remplace sqlite3 CLI (pas toujours installé).

Usage :
  python3 scripts/bsi-db.py "SELECT * FROM claims"           → query, pipe-separated
  python3 scripts/bsi-db.py -exec "INSERT INTO ..."           → write (no output)
  python3 scripts/bsi-db.py -script "CREATE TABLE ...; ..."   → multi-statement
"""

import sys
import sqlite3
from pathlib import Path

DB_PATH = str(Path(__file__).parent.parent / 'brain.db')

def main():
    if len(sys.argv) < 2:
        print("Usage: bsi-db.py [-exec|-script] <sql>", file=sys.stderr)
        sys.exit(1)

    mode = 'query'
    sql = sys.argv[1]

    if sys.argv[1] == '-exec':
        mode = 'exec'
        sql = sys.argv[2] if len(sys.argv) > 2 else ''
    elif sys.argv[1] == '-script':
        mode = 'script'
        sql = sys.argv[2] if len(sys.argv) > 2 else ''

    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")

    try:
        if mode == 'script':
            conn.executescript(sql)
        elif mode == 'exec':
            conn.execute(sql)
            conn.commit()
        else:
            rows = conn.execute(sql).fetchall()
            for row in rows:
                print('|'.join(str(v) if v is not None else '' for v in row))
    finally:
        conn.close()

if __name__ == '__main__':
    main()
