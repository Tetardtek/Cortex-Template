#!/bin/bash
# kernel-lock-gen.sh — Génère kernel.lock
# Checksums SHA-256 de tous les fichiers zone:kernel trackés
# Usage : bash scripts/kernel-lock-gen.sh

set -euo pipefail

BRAIN_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
LOCK_FILE="$BRAIN_ROOT/kernel.lock"

# Extraire la version depuis brain-compose.yml
VERSION=$(grep '^version:' "$BRAIN_ROOT/brain-compose.yml" | head -1 | sed 's/version: "//;s/"//')
GENERATED_AT=$(date +%Y-%m-%dT%H:%M)

# --- Écriture du header ---
cat > "$LOCK_FILE" << EOF
# kernel.lock — généré automatiquement
# Ne pas éditer manuellement.
# Régénérer : bash scripts/kernel-lock-gen.sh
# Vérifier  : bash scripts/kernel-isolation-check.sh

kernel_version: "$VERSION"
generated_at: "$GENERATED_AT"

files:
EOF

# --- Fichiers kernel racine ---
KERNEL_ROOT_FILES=(
  "KERNEL.md"
  "brain-compose.yml"
  "brain-constitution.md"
)

for f in "${KERNEL_ROOT_FILES[@]}"; do
  if [ -f "$BRAIN_ROOT/$f" ]; then
    hash=$(sha256sum "$BRAIN_ROOT/$f" | cut -d' ' -f1)
    echo "  $f: $hash" >> "$LOCK_FILE"
  fi
done

# --- agents/ (hors reviews/) ---
while IFS= read -r -d '' f; do
  rel="${f#$BRAIN_ROOT/}"
  hash=$(sha256sum "$f" | cut -d' ' -f1)
  echo "  $rel: $hash" >> "$LOCK_FILE"
done < <(find "$BRAIN_ROOT/agents" -name "*.md" \
  -not -path "*/reviews/*" \
  -not -path "*/_template*" \
  | sort | tr '\n' '\0')

# --- scripts/ ---
while IFS= read -r -d '' f; do
  rel="${f#$BRAIN_ROOT/}"
  hash=$(sha256sum "$f" | cut -d' ' -f1)
  echo "  $rel: $hash" >> "$LOCK_FILE"
done < <(find "$BRAIN_ROOT/scripts" -name "*.sh" -o -name "*.py" \
  | sort | tr '\n' '\0')

echo "✅ kernel.lock généré — version $VERSION ($(grep -c ': [a-f0-9]\{64\}' "$LOCK_FILE") fichiers)"
