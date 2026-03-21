#!/usr/bin/env bash
# install-brain-hooks.sh — Installe les hooks git brain
#
# Usage :
#   scripts/install-brain-hooks.sh          → installe dans .git/hooks/
#   scripts/install-brain-hooks.sh --check  → vérifie si les hooks sont installés
#
# Hooks installés :
#   post-commit → déclenche brain-db-sync.sh si handoffs/ agents/ ou BRAIN-INDEX.md changent
#
# Idempotent — peut être relancé sans risque.
# À relancer sur chaque clone frais (hooks non versionnés dans git).

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$BRAIN_ROOT/.git/hooks"
CHECK_ONLY=false

[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

hook_installed() {
    [[ -f "$HOOKS_DIR/post-commit" ]] && grep -q "brain-db-sync" "$HOOKS_DIR/post-commit" 2>/dev/null
}

if $CHECK_ONLY; then
    if hook_installed; then
        echo "✅ Hooks brain installés"
        exit 0
    else
        echo "⚠️  Hooks brain non installés — lancer: scripts/install-brain-hooks.sh"
        exit 1
    fi
fi

mkdir -p "$HOOKS_DIR"

# ── post-commit ────────────────────────────────────────────────────────────────

POST_COMMIT="$HOOKS_DIR/post-commit"

# Préserver un hook post-commit existant non-brain (append)
if [[ -f "$POST_COMMIT" ]] && ! grep -q "brain-db-sync" "$POST_COMMIT"; then
    echo "" >> "$POST_COMMIT"
    echo "# ── brain-db-sync (ajouté par install-brain-hooks.sh) ──" >> "$POST_COMMIT"
    cat >> "$POST_COMMIT" <<'HOOK'
# Déclenche brain-db-sync.sh si claims, handoffs ou BRAIN-INDEX ont changé
_brain_changed=$(git diff HEAD~1 --name-only 2>/dev/null \
    | grep -qE '^(handoffs/|agents/|BRAIN-INDEX\.md)' && echo yes || echo no)
if [[ "$_brain_changed" == "yes" ]]; then
    BRAIN_ROOT="$(git rev-parse --show-toplevel)"
    bash "$BRAIN_ROOT/scripts/brain-db-sync.sh" --quiet || true
fi
HOOK
    echo "✅ Hook post-commit existant complété"
else
    # Créer from scratch
    cat > "$POST_COMMIT" <<'HOOK'
#!/usr/bin/env bash
# brain post-commit hook — installé par scripts/install-brain-hooks.sh

# Sync brain.db si claims, handoffs ou BRAIN-INDEX ont changé
_brain_changed=$(git diff HEAD~1 --name-only 2>/dev/null \
    | grep -qE '^(handoffs/|agents/|BRAIN-INDEX\.md)' && echo yes || echo no)
if [[ "$_brain_changed" == "yes" ]]; then
    BRAIN_ROOT="$(git rev-parse --show-toplevel)"
    bash "$BRAIN_ROOT/scripts/brain-db-sync.sh" --quiet || true
fi
HOOK
    chmod +x "$POST_COMMIT"
    echo "✅ Hook post-commit installé"
fi

# ── commit-msg — strip Co-Authored-By Claude ─────────────────────────────────

COMMIT_MSG="$HOOKS_DIR/commit-msg"

if [[ ! -f "$COMMIT_MSG" ]] || ! grep -q "Co-Authored-By" "$COMMIT_MSG" 2>/dev/null; then
    cat > "$COMMIT_MSG" <<'HOOK'
#!/usr/bin/env bash
# brain commit-msg hook — strip Co-Authored-By Claude
# Le brain a sa propre identite — pas de signature Claude dans les commits.

sed -i '/Co-Authored-By:.*[Cc]laude/d' "$1"
# Nettoyer les lignes vides en fin de message
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$1"
HOOK
    chmod +x "$COMMIT_MSG"
    echo "✅ Hook commit-msg installé (strip Co-Authored-By Claude)"
fi

echo ""
echo "Hooks brain actifs :"
echo "  post-commit → brain-db-sync.sh (déclenché sur handoffs/ agents/ BRAIN-INDEX.md)"
echo "  commit-msg  → strip Co-Authored-By Claude (le brain a sa propre identite)"
echo ""
echo "Pour vérifier : scripts/install-brain-hooks.sh --check"
