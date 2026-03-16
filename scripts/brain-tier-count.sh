#!/usr/bin/env bash
# brain-tier-count.sh — Audite les lignes chargées en context_tier: always
# Alerte si > 1500 lignes (seuil warn) ou > 2000 lignes (seuil KPI fail)
#
# Usage : bash scripts/brain-tier-count.sh
# Appelé par : helloWorld au boot (vérification rapide)
#
# Ref : brain-constitution.md ## KPI NORTH STAR
#   always-tier total < 1 500 lignes → ok
#   always-tier total > 2 000 lignes → context-tier-split requis (KPI fail)

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WARN_THRESHOLD=1500
FAIL_THRESHOLD=2000

total_lines=0
declare -A file_lines
files_found=()

# Extraire et vérifier uniquement le frontmatter YAML (entre les deux premiers ---)
is_always_tier() {
    python3 - "$1" <<'PYEOF'
import sys, re
with open(sys.argv[1], 'r', errors='replace') as f:
    content = f.read()
# Extraire le frontmatter (entre --- et ---)
m = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
if not m:
    sys.exit(1)
frontmatter = m.group(1)
if re.search(r'^context_tier:\s*always', frontmatter, re.MULTILINE):
    sys.exit(0)
sys.exit(1)
PYEOF
}

# Trouver tous les fichiers always-tier
while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    if is_always_tier "$file"; then
        lines=$(wc -l < "$file")
        file_lines["$file"]=$lines
        total_lines=$((total_lines + lines))
        files_found+=("$file")
    fi
done < <(find "$BRAIN_ROOT" -maxdepth 3 \( -name "*.md" -o -name "*.yml" \) | \
         grep -v '\.git\|node_modules\|_template\|\.example')

# Affichage
echo "=== Brain Context Tier: always — Audit ==="
echo ""

# Trier par taille décroissante
for file in "${files_found[@]}"; do
    rel="${file#$BRAIN_ROOT/}"
    printf "  %4d lignes  %s\n" "${file_lines[$file]}" "$rel"
done | sort -rn

echo ""
echo "────────────────────────────────────"
printf "  TOTAL : %d lignes\n" "$total_lines"

if [[ $total_lines -gt $FAIL_THRESHOLD ]]; then
    echo "  🔴 KPI FAIL — context-tier-split requis (brain-constitution.md §3)"
    echo "     Seuil : $FAIL_THRESHOLD / Actuel : $total_lines"
elif [[ $total_lines -gt $WARN_THRESHOLD ]]; then
    echo "  ⚠️  WARN — approche du seuil KPI ($WARN_THRESHOLD)"
    echo "     Seuil fail : $FAIL_THRESHOLD / Actuel : $total_lines"
else
    echo "  ✅ OK — sous le seuil ($WARN_THRESHOLD)"
fi
echo "────────────────────────────────────"
