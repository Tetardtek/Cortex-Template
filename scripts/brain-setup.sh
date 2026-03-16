#!/bin/bash
# brain-setup.sh — Setup complet brain sur une nouvelle machine
# Usage : bash brain-setup.sh [brain_name] [brain_root]
# Ex    : bash brain-setup.sh prod-laptop ~/Dev/Brain
#
# Ce script est idempotent — safe à relancer si une étape a échoué.

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
GITEA="git@git.tetardtek.com:Tetardtek"
BRAIN_NAME="${1:-prod-laptop}"
BRAIN_ROOT="${2:-$HOME/Dev/Brain}"

REPOS=(
  "brain:$BRAIN_ROOT"
  "toolkit:$BRAIN_ROOT/toolkit"
  "progression-coach:$BRAIN_ROOT/progression"
  "brain-agent-review:$BRAIN_ROOT/reviews"
  "brain-profil:$BRAIN_ROOT/profil"
  "brain-todo:$BRAIN_ROOT/todo"
  "brain.wiki:$BRAIN_ROOT/wiki"
)

# ── Couleurs ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
info() { echo -e "   $1"; }

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║     brain-setup.sh — nouvelle machine        ║"
echo "║     brain_name : $BRAIN_NAME"
echo "║     brain_root : $BRAIN_ROOT"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Étape 0 — SSH key ────────────────────────────────────────────────────────
echo "[ 0/5 ] Vérification SSH key Gitea..."
if ! ssh -T git@git.tetardtek.com -o StrictHostKeyChecking=no 2>&1 | grep -qE "Welcome|Hi there"; then
  warn "Clé SSH Gitea non configurée."
  info "Créer une clé :"
  info "  ssh-keygen -t ed25519 -C 'laptop@brain'"
  info "  cat ~/.ssh/id_ed25519.pub"
  info "  → Ajouter dans Gitea : Settings > SSH Keys"
  echo ""
  read -p "   Appuie sur Entrée quand la clé est ajoutée dans Gitea..." _
fi
ok "SSH Gitea OK"

# ── Étape 1 — Cloner les satellites ──────────────────────────────────────────
echo ""
echo "[ 1/5 ] Clonage des satellites..."
for entry in "${REPOS[@]}"; do
  repo="${entry%%:*}"
  dest="${entry#*:}"
  dest="${dest/#\~/$HOME}"

  if [[ -d "$dest/.git" ]]; then
    info "$repo → déjà cloné ($dest) — git pull..."
    git -C "$dest" pull --ff-only 2>/dev/null || warn "$repo : pull échoué (conflits ?) — vérifier manuellement"
  else
    mkdir -p "$(dirname "$dest")"
    git clone "$GITEA/$repo.git" "$dest"
    ok "$repo → $dest"
  fi
done
ok "Tous les satellites clonés"

# ── Étape 2 — CLAUDE.md ──────────────────────────────────────────────────────
echo ""
echo "[ 2/5 ] Configuration CLAUDE.md..."
CLAUDE_TARGET="$HOME/.claude/CLAUDE.md"
CLAUDE_EXAMPLE="$BRAIN_ROOT/profil/CLAUDE.md.example"

mkdir -p "$HOME/.claude"

if [[ -f "$CLAUDE_TARGET" ]]; then
  warn "~/.claude/CLAUDE.md existe déjà — backup → CLAUDE.md.bak"
  cp "$CLAUDE_TARGET" "$CLAUDE_TARGET.bak"
fi

cp "$CLAUDE_EXAMPLE" "$CLAUDE_TARGET"
sed -i "s|<BRAIN_ROOT>|$BRAIN_ROOT|g" "$CLAUDE_TARGET"
sed -i "s|<BRAIN_NAME>|$BRAIN_NAME|g" "$CLAUDE_TARGET"
ok "~/.claude/CLAUDE.md configuré (brain_name=$BRAIN_NAME, brain_root=$BRAIN_ROOT)"

# ── Étape 3 — brain-compose.local.yml ────────────────────────────────────────
echo ""
echo "[ 3/5 ] brain-compose.local.yml..."
LOCAL_COMPOSE="$BRAIN_ROOT/brain-compose.local.yml"

if [[ -f "$LOCAL_COMPOSE" ]]; then
  warn "brain-compose.local.yml existe déjà — skip"
else
  cat > "$LOCAL_COMPOSE" << EOF
# brain-compose.local.yml — Registre machine ($BRAIN_NAME)
# NON VERSIONNÉ — gitignored.

kernel_path: $BRAIN_ROOT
kernel_version: "0.5.1"
last_kernel_sync: "$(date +%Y-%m-%d)"
machine: $BRAIN_NAME
write_mode: readonly_kernel   # nouvelle machine = jamais kernel writer

instances:
  $BRAIN_NAME:
    path: $BRAIN_ROOT
    brain_name: $BRAIN_NAME
    feature_set: full
    mode: prod
    docs_fetch: ask
    config_status: hydrated
    active: true
EOF
  ok "brain-compose.local.yml créé"
fi

# ── Lock kernel push (nouvelle machine = readonly) ────────────────────────────
git -C "$BRAIN_ROOT" remote set-url --push origin no_push
ok "Kernel push lockée (write_mode: readonly_kernel)"

# ── Étape 4 — MYSECRETS ──────────────────────────────────────────────────────
echo ""
echo "[ 4/5 ] MYSECRETS..."
MYSECRETS="$BRAIN_ROOT/MYSECRETS"

if [[ -f "$MYSECRETS" ]]; then
  ok "MYSECRETS présent"
else
  warn "MYSECRETS absent — jamais versionné."
  info ""
  info "Options pour le récupérer :"
  info "  A) Copie sécurisée depuis le desktop :"
  info "     scp tetardtek@<desktop-ip>:~/Dev/Brain/MYSECRETS $MYSECRETS"
  info ""
  info "  B) Recréer manuellement :"
  info "     cp $BRAIN_ROOT/MYSECRETS.example $MYSECRETS  (si le fichier exemple existe)"
  info "     → Remplir les valeurs manuellement"
  info ""
  warn "Le brain fonctionne sans MYSECRETS mais les sessions secrets seront bloquées."
fi

# ── Étape 5 — Claude Code ────────────────────────────────────────────────────
echo ""
echo "[ 5/5 ] Claude Code..."
if command -v claude &>/dev/null; then
  ok "Claude Code installé ($(claude --version 2>/dev/null || echo 'version inconnue'))"
else
  warn "Claude Code non installé."
  info "  npm install -g @anthropic-ai/claude-code"
  info "  ou : https://claude.ai/code"
fi

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║              Setup terminé                   ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  brain_name : $BRAIN_NAME"
echo "  brain_root : $BRAIN_ROOT"
echo ""
echo "  Prochaine étape :"
echo "  → Ouvrir Claude Code dans $BRAIN_ROOT"
echo "  → Le brain se boot automatiquement via CLAUDE.md"
echo ""
warn "Si MYSECRETS est absent : le remplir avant la première session work."
echo ""
