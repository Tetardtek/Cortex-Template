#!/usr/bin/env bash
# brain-audit.sh — Audit hebdomadaire du brain (métriques Dolt)
#
# Usage :
#   brain-audit.sh              → affiche + sauvegarde snapshot
#   brain-audit.sh --diff       → compare avec le dernier snapshot
#   brain-audit.sh --history    → liste tous les snapshots
#
# Les snapshots sont stockés dans brain-dolt et versionnés.
# Rituel : chaque dimanche → audit + ménage + commit Dolt.

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOLT_DIR="$BRAIN_ROOT/brain-dolt"
AUDIT_DIR="$BRAIN_ROOT/metrics"
TODAY=$(date +%Y-%m-%d)
SNAPSHOT="$AUDIT_DIR/snapshot-$TODAY.json"
CMD="${1:-snapshot}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

mkdir -p "$AUDIT_DIR"

generate_snapshot() {
  cd "$DOLT_DIR"
  python3 - "$DOLT_DIR" "$TODAY" <<'PYEOF'
import subprocess, json, sys, csv, io

dolt_dir = sys.argv[1]
date = sys.argv[2]

def dolt_query(sql):
    result = subprocess.run(
        ["dolt", "sql", "-q", sql, "-r", "csv"],
        cwd=dolt_dir, capture_output=True, text=True
    )
    if result.returncode != 0 or not result.stdout.strip():
        return []
    return list(csv.DictReader(io.StringIO(result.stdout)))

def dolt_val(sql):
    rows = dolt_query(sql)
    if rows:
        return list(rows[0].values())[0]
    return "0"

# Row counts
tables = {}
for t in ['claims', 'sessions', 'embeddings', 'signals', 'handoffs', 'agent_memory', 'agent_loads', 'locks', 'circuit_breaker']:
    tables[t] = int(dolt_val(f"SELECT COUNT(*) FROM {t}"))

# Claims breakdown
claims_by_status = {r['status']: int(r['n']) for r in dolt_query("SELECT status, COUNT(*) as n FROM claims GROUP BY status")}
claims_by_type = {r['type']: int(r['n']) for r in dolt_query("SELECT type, COUNT(*) as n FROM claims GROUP BY type ORDER BY n DESC")}

# Sessions
sessions_by_type = {r['type']: int(r['n']) for r in dolt_query("SELECT COALESCE(type, 'null') as type, COUNT(*) as n FROM sessions GROUP BY type ORDER BY n DESC")}

# Embeddings
emb = dolt_query("SELECT COUNT(*) as total, SUM(CASE WHEN `indexed`=1 THEN 1 ELSE 0 END) as indexed, COUNT(DISTINCT filepath) as fichiers, SUM(hit_count) as hits, SUM(permanent) as permanent FROM embeddings")
emb_data = emb[0] if emb else {}
emb_by_scope = {r['scope']: int(r['n']) for r in dolt_query("SELECT scope, COUNT(*) as n FROM embeddings GROUP BY scope ORDER BY n DESC")}

# Top queried files
top_files = dolt_query("SELECT filepath, SUM(hit_count) as hits FROM embeddings WHERE hit_count > 0 GROUP BY filepath ORDER BY hits DESC LIMIT 10")

# Dolt meta
commits = int(dolt_val("SELECT COUNT(*) FROM dolt_log"))

# Repo size
import os
dolt_size = 0
for dirpath, _, filenames in os.walk(os.path.join(dolt_dir, '.dolt')):
    for f in filenames:
        dolt_size += os.path.getsize(os.path.join(dirpath, f))

snapshot = {
    "date": date,
    "dolt": {
        "commits": commits,
        "size_mb": round(dolt_size / 1024 / 1024, 1),
    },
    "tables": tables,
    "claims": {
        "total": tables.get("claims", 0),
        "by_status": claims_by_status,
        "by_type": claims_by_type,
    },
    "sessions": {
        "total": tables.get("sessions", 0),
        "by_type": sessions_by_type,
    },
    "embeddings": {
        "total": int(emb_data.get("total", 0)),
        "indexed": int(emb_data.get("indexed", 0)),
        "fichiers": int(emb_data.get("fichiers", 0)),
        "hits_total": int(emb_data.get("hits", 0)),
        "permanent": int(emb_data.get("permanent", 0)),
        "by_scope": emb_by_scope,
        "top_queried": [{"file": r["filepath"], "hits": int(r["hits"])} for r in top_files],
    },
    "signals": tables.get("signals", 0),
}

print(json.dumps(snapshot, indent=2, ensure_ascii=False))
PYEOF
}

case "$CMD" in
  snapshot|"")
    echo -e "${CYAN}📊 Brain Audit — $TODAY${NC}"
    echo ""

    # Generate and save
    RESULT=$(generate_snapshot)
    echo "$RESULT" > "$SNAPSHOT"
    echo "$RESULT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(f\"Dolt          : {d['dolt']['commits']} commits, {d['dolt']['size_mb']} Mo\")
print(f\"Claims        : {d['claims']['total']} ({d['claims']['by_status'].get('open', 0)} open, {d['claims']['by_status'].get('closed', 0)} closed)\")
print(f\"Sessions      : {d['sessions']['total']}\")
print(f\"Embeddings    : {d['embeddings']['total']} chunks, {d['embeddings']['fichiers']} fichiers, {d['embeddings']['hits_total']} hits\")
print(f\"  scopes      : {', '.join(f'{k}={v}' for k,v in d['embeddings']['by_scope'].items())}\")
print(f\"  permanent   : {d['embeddings']['permanent']}\")
print(f\"Signals       : {d['signals']}\")
print()
top = d['embeddings']['top_queried'][:5]
if top:
    print('Top fichiers consultés :')
    for t in top:
        print(f\"  {t['hits']:3d} hits — {t['file']}\")
"
    echo ""
    echo -e "${GREEN}✅ Snapshot sauvegardé : $SNAPSHOT${NC}"

    echo -e "${YELLOW}→ git add metrics/ && git commit pour versionner${NC}"
    ;;

  --diff)
    # Find last two snapshots
    SNAPSHOTS=($(ls -1 "$AUDIT_DIR"/snapshot-*.json 2>/dev/null | sort | tail -2))
    if [ ${#SNAPSHOTS[@]} -lt 2 ]; then
      echo "⚠️  Pas assez de snapshots pour comparer (${#SNAPSHOTS[@]} trouvé)"
      exit 0
    fi
    OLD="${SNAPSHOTS[0]}"
    NEW="${SNAPSHOTS[1]}"
    echo -e "${CYAN}📊 Diff : $(basename $OLD) → $(basename $NEW)${NC}"
    echo ""
    python3 -c "
import json, sys
old = json.load(open('$OLD'))
new = json.load(open('$NEW'))

def diff(label, old_val, new_val):
    delta = new_val - old_val
    sign = '+' if delta > 0 else ''
    marker = '🟢' if delta > 0 else ('🔴' if delta < 0 else '⚪')
    print(f'  {marker} {label:20s} {old_val:>6} → {new_val:>6}  ({sign}{delta})')

print(f\"Période : {old['date']} → {new['date']}\")
print()
diff('Claims', old['claims']['total'], new['claims']['total'])
diff('Sessions', old['sessions']['total'], new['sessions']['total'])
diff('Embeddings', old['embeddings']['total'], new['embeddings']['total'])
diff('Fichiers', old['embeddings']['fichiers'], new['embeddings']['fichiers'])
diff('Hits RAG', old['embeddings']['hits_total'], new['embeddings']['hits_total'])
diff('Signals', old['signals'], new['signals'])
diff('Dolt commits', old['dolt']['commits'], new['dolt']['commits'])
diff('Taille (Mo)', old['dolt']['size_mb'], new['dolt']['size_mb'])
"
    ;;

  --history)
    echo -e "${CYAN}📊 Historique des snapshots${NC}"
    ls -1 "$AUDIT_DIR"/snapshot-*.json 2>/dev/null | while read f; do
      date=$(python3 -c "import json; print(json.load(open('$f'))['date'])")
      claims=$(python3 -c "import json; print(json.load(open('$f'))['claims']['total'])")
      emb=$(python3 -c "import json; print(json.load(open('$f'))['embeddings']['total'])")
      echo "  $date — $claims claims, $emb embeddings"
    done
    ;;

  *)
    echo "Usage: brain-audit.sh [--diff|--history]"
    exit 1
    ;;
esac
