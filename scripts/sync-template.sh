#!/bin/bash
# sync-template.sh — Synchronise brain/ → brain-template/
# Copie les fichiers kernel en excluant tout ce qui est instance/personnel.
# À lancer après chaque modification kernel significative.
#
# Usage :
#   sync-template.sh          → sync + rapport
#   sync-template.sh --dry    → rapport sans écrire
#   sync-template.sh --push   → sync + commit + push

set -euo pipefail

BRAIN_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
TEMPLATE_DIR="$BRAIN_ROOT/brain-template"
DRY="${1:-}"
PUSH=""
[ "$DRY" = "--push" ] && PUSH=true && DRY=""

if [ ! -d "$TEMPLATE_DIR/.git" ]; then
  echo "❌ brain-template/ introuvable ou pas un repo git"
  exit 1
fi

echo "🔄 Sync brain → brain-template"
[ -n "$DRY" ] && echo "   (dry run — aucune écriture)"
echo ""

# --- Scripts : tout sauf distillation/privé ---
SCRIPTS_EXCLUDE="bsi-server.sh bsi-rag.sh bsi-search.sh brain-bot.py brain-engine.service get-telegram-chatid.sh get-telegram-chatids.sh rotate-oauth-secrets.sh brain-key-server.py brain-key-admin.sh key-guardian.sh"

echo "── scripts/ ────────────────────────────────────"
for f in "$BRAIN_ROOT/scripts/"*.sh "$BRAIN_ROOT/scripts/"*.py; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  skip=false
  for ex in $SCRIPTS_EXCLUDE; do [ "$base" = "$ex" ] && skip=true; done
  if [ "$skip" = true ]; then
    echo "  ⏭  $base (exclu)"
    continue
  fi
  if [ -z "$DRY" ]; then
    cp "$f" "$TEMPLATE_DIR/scripts/"
  fi
  echo "  ✅ $base"
done

# --- Agents : tout sauf reviews/ ---
echo ""
echo "── agents/ ─────────────────────────────────────"
if [ -z "$DRY" ]; then
  rsync -a --delete --exclude='reviews/' --exclude='bact-scribe.md' \
    "$BRAIN_ROOT/agents/" "$TEMPLATE_DIR/agents/"
fi
agent_count=$(ls "$BRAIN_ROOT/agents/"*.md 2>/dev/null | wc -l | tr -d ' ')
echo "  ✅ $agent_count agents (reviews/ exclu)"

# --- Fichiers kernel racine ---
echo ""
echo "── kernel racine ───────────────────────────────"
KERNEL_FILES="KERNEL.md brain-compose.yml brain-constitution.md"
for f in $KERNEL_FILES; do
  if [ -f "$BRAIN_ROOT/$f" ]; then
    [ -z "$DRY" ] && cp "$BRAIN_ROOT/$f" "$TEMPLATE_DIR/$f"
    echo "  ✅ $f"
  fi
done

# --- Workflows ---
echo ""
echo "── workflows/ ──────────────────────────────────"
if [ -d "$BRAIN_ROOT/workflows" ]; then
  if [ -z "$DRY" ]; then
    mkdir -p "$TEMPLATE_DIR/workflows"
    cp "$BRAIN_ROOT/workflows/_template.yml" "$TEMPLATE_DIR/workflows/" 2>/dev/null || true
    cp "$BRAIN_ROOT/workflows/brain-engine.yml" "$TEMPLATE_DIR/workflows/" 2>/dev/null || true
  fi
  echo "  ✅ _template.yml + brain-engine.yml"
fi

# --- Wiki (submodule) ---
echo ""
echo "── wiki/ ───────────────────────────────────────"
WIKI_FILES="multi-instance.md concepts.md patterns.md vocabulary.md session-lifecycle.md cold-start.md"
if [ -d "$BRAIN_ROOT/wiki" ]; then
  if [ -z "$DRY" ]; then
    mkdir -p "$TEMPLATE_DIR/wiki"
    for wf in $WIKI_FILES; do
      [ -f "$BRAIN_ROOT/wiki/$wf" ] && cp "$BRAIN_ROOT/wiki/$wf" "$TEMPLATE_DIR/wiki/" && echo "  ✅ $wf"
    done
  else
    echo "  (dry) wiki/$WIKI_FILES"
  fi
fi

# --- Gitkeep ---
[ -z "$DRY" ] && mkdir -p "$TEMPLATE_DIR/locks" && \
  touch "$TEMPLATE_DIR/locks/.gitkeep"

# --- Isolation check ---
echo ""
echo "── kernel-isolation-check ──────────────────────"
if [ -z "$DRY" ]; then
  result=$(bash "$BRAIN_ROOT/scripts/kernel-isolation-check.sh" 2>&1 | tail -3)
  echo "$result"
fi

# --- Push ---
if [ -n "$PUSH" ]; then
  echo ""
  echo "── commit + push ───────────────────────────────"
  cd "$TEMPLATE_DIR"
  if git diff --quiet && git diff --staged --quiet; then
    echo "  ℹ️  Aucune modification à commiter"
  else
    version=$(grep '^version:' "$BRAIN_ROOT/brain-compose.yml" | head -1 | sed 's/version: "//;s/"//')
    git add -A
    git commit -m "sync: kernel v$version → template"
    git push
    echo "  ✅ Pushé"
  fi
fi

echo ""
echo "✅ Sync terminé"
