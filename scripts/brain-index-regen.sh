#!/usr/bin/env bash
# brain-index-regen.sh — Régénère la table ## Claims dans BRAIN-INDEX.md
# depuis les fichiers claims/sess-*.yml (BSI v3 — source unique de vérité)
#
# Gère les formats :
#   v1 : name: + opened: + status:
#   v2 : sess_id: + opened_at: + status:
#   v3 : + satellite_type + zone (inféré) + result.status
#
# Usage : bash scripts/brain-index-regen.sh
# Appelé par : session-orchestrator (close sequence step 5)
#              helloWorld (boot claim open)
#
# Anti-drift : lecture seule sur claims/*.yml — écriture uniquement sur BRAIN-INDEX.md ## Claims
# Sécurité   : aucun secret dans les claims (garanti par secrets-guardian)

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAIMS_DIR="$BRAIN_ROOT/claims"
INDEX_FILE="$BRAIN_ROOT/BRAIN-INDEX.md"

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "❌ BRAIN-INDEX.md introuvable — chemin : $INDEX_FILE"
  exit 1
fi

if [[ ! -d "$CLAIMS_DIR" ]]; then
  echo "❌ claims/ introuvable — chemin : $CLAIMS_DIR"
  exit 1
fi

# ── Parser tous les claims via Python (gère YAML multi-format proprement) ────

python3 - "$CLAIMS_DIR" "$INDEX_FILE" <<'PYEOF'
import sys, os, re

claims_dir = sys.argv[1]
index_path = sys.argv[2]

rows = []
open_count = 0

for filename in sorted(os.listdir(claims_dir)):
    if not filename.startswith('sess-') or not filename.endswith('.yml'):
        continue

    filepath = os.path.join(claims_dir, filename)
    with open(filepath, 'r') as f:
        content = f.read()

    def extract(pattern, text, default='—'):
        m = re.search(pattern, text, re.MULTILINE)
        if m:
            return m.group(1).strip().strip('"\'')
        return default

    # Gère v1 (name:) et v2 (sess_id:)
    def extract_first(*patterns):
        for p in patterns:
            m = re.search(p, content, re.MULTILINE)
            if m:
                return m.group(1).strip().strip('"\'')
        return '—'

    sess_id   = extract_first(r'^sess_id:\s*(.+)', r'^name:\s*(sess-.+)')
    scope     = extract_first(r'^scope:\s*(.+)')
    status    = extract_first(r'^status:\s*(.+)')
    opened    = extract_first(r'^opened_at:\s*(.+)', r'^opened:\s*(.+)')
    sat_type  = extract_first(r'^satellite_type:\s*(.+)')
    theme_br  = extract_first(r'^theme_branch:\s*(.+)')

    # Inférer zone depuis scope (BSI v3 — ADR-014)
    KERNEL_SCOPES = ['agents/', 'profil/', 'scripts/', 'KERNEL.md',
                     'brain-constitution.md', 'brain-compose.yml']
    PERSONAL_SCOPES = ['profil/capital', 'profil/objectifs', 'progression/', 'MYSECRETS']
    zone = 'project'
    for ks in KERNEL_SCOPES:
        if ks in scope:
            zone = 'kernel'
            break
    for ps in PERSONAL_SCOPES:
        if ps in scope:
            zone = 'personal'
            break

    # Résultat du close si disponible
    result_status = extract(r'^\s+status:\s*(.+)', content)
    if result_status in ('open', 'closed', 'stale', '—'):
        result_status = '—'

    # Indicateur satellite_type
    type_display = sat_type if sat_type != '—' else '—'
    theme_display = theme_br.replace('theme/', '') if theme_br != '—' else '—'

    rows.append(f"| {sess_id} | {scope} | {status} | {opened} | {type_display} | {zone} | {result_status} |")
    if status == 'open':
        open_count += 1

table_rows = "\n".join(rows)
comment = ("<!-- ⚠️ TABLE GÉNÉRÉE — ne pas éditer manuellement.\n"
           "     Régénérée par : scripts/brain-index-regen.sh\n"
           "     Appelée par   : session-orchestrator (close) + helloWorld (boot)\n"
           "     Source unique : claims/sess-*.yml (BSI v3) -->\n")
new_table = (f"{comment}Sessions actives à ce jour :\n\n"
             f"| sess_id | scope | status | opened_at | type | zone | result |\n"
             f"|---------|-------|--------|-----------|------|------|--------|\n"
             f"{table_rows}")

# Lire BRAIN-INDEX.md
with open(index_path, 'r') as f:
    content = f.read()

# Remplacer depuis le commentaire HTML (ou "Sessions actives") jusqu'au prochain "---"
# Deux patterns : avec ou sans commentaire généré
pattern = r'(?:<!--.*?-->\s*\n)?Sessions actives à ce jour :.*?(?=\n---)'
if not re.search(pattern, content, flags=re.DOTALL):
    print("⚠️  Pattern claims non trouvé dans BRAIN-INDEX.md — pas de modification")
    sys.exit(0)

new_content = re.sub(pattern, new_table, content, flags=re.DOTALL)

with open(index_path, 'w') as f:
    f.write(new_content)

print(f"✅ BRAIN-INDEX.md régénéré — {open_count} claim(s) open / {len(rows)} total")
PYEOF
