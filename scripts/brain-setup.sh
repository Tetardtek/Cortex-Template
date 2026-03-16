#!/bin/bash
# brain-setup.sh — First boot setup (fresh fork)
# Idempotent — safe à relancer si une étape a échoué.
#
# Usage : bash scripts/brain-setup.sh

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

ok()   { echo "OK  $1"; }
warn() { echo "WRN $1"; }
ask()  { printf "\n?   %s\n> " "$1"; }

echo ""
echo "=== brain-template — First boot setup ==="
echo "    Chemin : $BRAIN_ROOT"
echo ""

# ETAPE 1 — PATHS.md
echo "--- 1/5 Chemins machine ---"
if grep -q '<BRAIN_ROOT>' "$BRAIN_ROOT/PATHS.md" 2>/dev/null; then
  ask "Chemin absolu du brain [Entree = $BRAIN_ROOT]"
  read -r brain_path; brain_path="${brain_path:-$BRAIN_ROOT}"

  ask "Chemin projets [ex: $HOME/Dev/Projects]"
  read -r projects_path; projects_path="${projects_path:-$HOME/Dev/Projects}"

  ask "URL Git [ex: git@github.com:alice]"
  read -r gitea_url; gitea_url="${gitea_url:-git@github.com:<USERNAME>}"

  ask "Username Git"
  read -r username; username="${username:-<USERNAME>}"

  sed -i \
    -e "s|<BRAIN_ROOT>|$brain_path|g" \
    -e "s|<PROJECTS_ROOT>|$projects_path|g" \
    -e "s|<GITEA_URL>|$gitea_url|g" \
    -e "s|<USERNAME>|$username|g" \
    -e "s|<HOME>|$HOME|g" \
    "$BRAIN_ROOT/PATHS.md"
  ok "PATHS.md configure"
else
  ok "PATHS.md deja configure"
  brain_path="$BRAIN_ROOT"
fi

# ETAPE 2 — CLAUDE.md global
echo ""
echo "--- 2/5 CLAUDE.md global ---"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
brain_name="prod"
if [ ! -f "$CLAUDE_MD" ]; then
  ask "Nom de cette instance ? [prod / dev / laptop]"
  read -r brain_name; brain_name="${brain_name:-prod}"
  mkdir -p "$CLAUDE_DIR"
  cat > "$CLAUDE_MD" << EOF
# CLAUDE.md

brain_root: ${brain_path:-$BRAIN_ROOT}
brain_name: $brain_name

## Bootstrap

0. ${brain_path:-$BRAIN_ROOT}/PATHS.md
1. ${brain_path:-$BRAIN_ROOT}/profil/collaboration.md
2. ${brain_path:-$BRAIN_ROOT}/agents/coach.md
3. ${brain_path:-$BRAIN_ROOT}/agents/helloWorld.md

helloWorld prend le relais.
EOF
  ok "~/.claude/CLAUDE.md cree (brain_name: $brain_name)"
else
  ok "~/.claude/CLAUDE.md existe"
  brain_name=$(grep 'brain_name:' "$CLAUDE_MD" | sed 's/.*: *//' | tr -d ' ' | head -1 || echo "prod")
fi

# ETAPE 3 — brain-compose.local.yml
echo ""
echo "--- 3/5 brain-compose.local.yml ---"
LOCAL="$BRAIN_ROOT/brain-compose.local.yml"
tier="free"
if [ ! -f "$LOCAL" ]; then
  ask "Tier ? [free / pro / full]"
  read -r tier; tier="${tier:-free}"
  api_key=""
  if [ "$tier" != "free" ]; then
    ask "Cle API"
    read -r api_key
  fi
  cat > "$LOCAL" << EOF
brain_name: $brain_name
kernel_path: ${brain_path:-$BRAIN_ROOT}
tier: $tier
$([ -n "${api_key:-}" ] && echo "api_key: $api_key" || echo "# api_key: (tier free)")
instances:
  $brain_name:
    path: ${brain_path:-$BRAIN_ROOT}
    brain_name: $brain_name
EOF
  ok "brain-compose.local.yml cree (tier: $tier)"
else
  ok "brain-compose.local.yml existe"
fi

# ETAPE 4 — Git remote
echo ""
echo "--- 4/5 Git remote ---"
current_origin=$(git -C "$BRAIN_ROOT" remote get-url origin 2>/dev/null || echo "")
if echo "$current_origin" | grep -q "brain-template"; then
  ask "URL de TON repo ? (skip pour ignorer)"
  read -r new_remote
  if [ "$new_remote" != "skip" ] && [ -n "$new_remote" ]; then
    git -C "$BRAIN_ROOT" remote set-url origin "$new_remote"
    git -C "$BRAIN_ROOT" remote add upstream "$current_origin" 2>/dev/null || true
    ok "origin -> $new_remote / upstream -> brain-template"
  else
    warn "Remote non modifie"
  fi
else
  ok "Remote : $current_origin"
fi

# ETAPE 5 — Validation
echo ""
echo "--- 5/5 Validation ---"
bash "$BRAIN_ROOT/scripts/kernel-isolation-check.sh" 2>&1 | tail -2

echo ""
echo "=== Setup termine ==="
echo ""
echo "    brain_name : ${brain_name:-prod}"
echo "    tier       : ${tier:-free}"
echo "    brain_root : ${brain_path:-$BRAIN_ROOT}"
echo ""
echo "    Ouvre Claude Code dans ce dossier."
echo "    Dis : 'Bonjour — demarre le brain (helloWorld)'"
