#!/bin/bash
# brain-setup.sh — Setup complet brain sur une nouvelle machine
# Usage : bash brain-setup.sh [brain_name] [brain_root]
# Ex    : bash brain-setup.sh my-brain ~/Dev/Brain
#
# Ce script est idempotent — safe à relancer si une étape a échoué.
# Détecte automatiquement la source git (GitHub public ou Gitea privé).

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────
BRAIN_NAME="${1:-my-brain}"
BRAIN_ROOT="${2:-$HOME/Dev/Brain}"

# ── Détection source git ────────────────────────────────────────────────────
# Si Gitea est accessible → mode owner (repos privés)
# Sinon → mode template (repos publics GitHub Tetardtek-Cortex)

GITEA_HOST="git.tetardtek.com"
GITHUB_ORG="git@github.com:Tetardtek-Cortex"
GITEA_ORG="git@$GITEA_HOST:Tetardtek"

detect_git_source() {
  if ssh -T "git@$GITEA_HOST" -o StrictHostKeyChecking=no -o ConnectTimeout=3 2>&1 | grep -qE "Welcome|Hi there"; then
    echo "gitea"
  else
    echo "github"
  fi
}

GIT_SOURCE=$(detect_git_source)

if [[ "$GIT_SOURCE" == "gitea" ]]; then
  GIT_BASE="$GITEA_ORG"
  # Noms repos Gitea (owner)
  SATELLITES=(
    "toolkit:$BRAIN_ROOT/toolkit"
    "progression-coach:$BRAIN_ROOT/progression"
    "brain-agent-review:$BRAIN_ROOT/reviews"
    "brain-profil:$BRAIN_ROOT/profil"
    "brain-todo:$BRAIN_ROOT/todo"
    "brain.wiki:$BRAIN_ROOT/wiki"
  )
else
  GIT_BASE="$GITHUB_ORG"
  # Noms repos GitHub (template user)
  SATELLITES=(
    "Cortex-Toolkit:$BRAIN_ROOT/toolkit"
    "Cortex-Progression:$BRAIN_ROOT/progression"
    "Cortex-Reviews:$BRAIN_ROOT/reviews"
    "Cortex-Profil:$BRAIN_ROOT/profil"
    "Cortex-Todo:$BRAIN_ROOT/todo"
  )
fi
# brain-ui est dans le monorepo principal (brain-ui/ sous BRAIN_ROOT) — pas un satellite séparé

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
echo "║     source     : $GIT_SOURCE"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ── Étape 0 — SSH key ────────────────────────────────────────────────────────
echo "[ 0/5 ] Vérification SSH..."
if [[ "$GIT_SOURCE" == "gitea" ]]; then
  ok "SSH Gitea OK"
else
  if ! ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -qE "successfully authenticated|Hi "; then
    warn "Clé SSH GitHub non configurée."
    info "Créer une clé :"
    info "  ssh-keygen -t ed25519 -C '$BRAIN_NAME@brain'"
    info "  cat ~/.ssh/id_ed25519.pub"
    info "  → Ajouter dans GitHub : Settings > SSH and GPG Keys"
    echo ""
    read -p "   Appuie sur Entrée quand la clé est ajoutée..." _
  fi
  ok "SSH GitHub OK"
fi

# ── Étape 1 — Cloner les satellites ──────────────────────────────────────────
echo ""
echo "[ 1/5 ] Clonage des satellites..."
for entry in "${SATELLITES[@]}"; do
  repo="${entry%%:*}"
  dest="${entry#*:}"
  dest="${dest/#\~/$HOME}"

  if [[ -d "$dest/.git" ]]; then
    info "$repo → déjà cloné ($dest) — git pull..."
    git -C "$dest" pull --ff-only 2>/dev/null || warn "$repo : pull échoué (conflits ?) — vérifier manuellement"
  else
    mkdir -p "$(dirname "$dest")"
    git clone "$GIT_BASE/$repo.git" "$dest"
    ok "$repo → $dest"
  fi
done
ok "Tous les satellites clonés (source: $GIT_SOURCE)"

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
KERNEL_VERSION=$(grep '^version:' "$BRAIN_ROOT/brain-compose.yml" | awk '{print $2}' | tr -d '"')

if [[ -f "$LOCAL_COMPOSE" ]]; then
  warn "brain-compose.local.yml existe déjà — skip"
else
  cat > "$LOCAL_COMPOSE" << EOF
# brain-compose.local.yml — Registre machine ($BRAIN_NAME)
# NON VERSIONNÉ — gitignored.

kernel_path: $BRAIN_ROOT
kernel_version: "$KERNEL_VERSION"
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

# ── Étape 3.5 — Brain API Key (optionnel) ────────────────────────────────────
echo ""
echo "[ 3.5/5 ] Brain API Key (optionnel)..."
info "Obtenir une clé : contacter le mainteneur du brain (tier free = aucune clé requise)"
info "Format attendu  : bk_live_<32chars> (prod) ou bk_test_<32chars> (dev)"
echo ""
read -rp "   Brain API Key (Entrée pour passer, tier free) : " api_key

if [[ -n "$api_key" ]]; then
  if [[ ! "$api_key" =~ ^bk_(live|test)_ ]]; then
    warn "Format invalide — clé ignorée (attendu : bk_live_... ou bk_test_...)"
  else
    sed -i "s|^brain_api_key:.*|brain_api_key: $api_key|" "$BRAIN_ROOT/brain-compose.yml"
    ok "Clé enregistrée dans brain-compose.yml"
    info "Le key-guardian validera au prochain boot (timeout 3s, grace 72h si VPS down)."
  fi
else
  info "Tier free — aucune clé configurée."
fi

# ── Étape 4 — MYSECRETS ──────────────────────────────────────────────────────
echo ""
echo "[ 4/5 ] MYSECRETS..."
SECRETS_DIR="$(dirname "$BRAIN_ROOT")/BrainSecrets"
MYSECRETS="$SECRETS_DIR/MYSECRETS"

if [[ -f "$MYSECRETS" ]]; then
  ok "MYSECRETS présent ($MYSECRETS)"
else
  warn "MYSECRETS absent — fichier de secrets personnels."
  info ""
  info "Créer le dossier et le fichier :"
  info "  mkdir -p $SECRETS_DIR"
  info "  cp $BRAIN_ROOT/MYSECRETS.example $MYSECRETS"
  info "  → Remplir les valeurs (DB_PASSWORD, JWT_SECRET, etc.)"
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

# ── Étape 5.5 — Node.js ──────────────────────────────────────────────────────
echo ""
echo "[ 5.5 ] Node.js..."
if command -v node &>/dev/null && command -v npm &>/dev/null; then
  ok "Node.js $(node --version) / npm $(npm --version)"
else
  warn "Node.js ou npm absent."
  info "  Option A — nvm (recommandé) :"
  info "    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
  info "    nvm install --lts"
  info "  Option B — apt :"
  info "    sudo apt install nodejs npm"
fi

# ── Étape 5.75 — Python3 + pip + brain-engine deps ───────────────────────────
echo ""
echo "[ 5.75 ] Python3 + brain-engine..."
if ! command -v python3 &>/dev/null; then
  warn "python3 absent — installer via : sudo apt install python3 python3-pip"
elif ! command -v pip3 &>/dev/null; then
  warn "pip3 absent — installer via : sudo apt install python3-pip"
else
  ok "Python $(python3 --version 2>&1 | awk '{print $2}') / pip $(pip3 --version 2>&1 | awk '{print $2}')"
  REQUIREMENTS="$BRAIN_ROOT/brain-engine/requirements.txt"
  if [[ -f "$REQUIREMENTS" ]]; then
    info "Installation des dépendances brain-engine..."
    pip3 install -r "$REQUIREMENTS" --break-system-packages --quiet && ok "brain-engine deps OK" || warn "pip3 install a échoué — vérifier manuellement"
  else
    warn "brain-engine/requirements.txt absent — skip pip install"
  fi
fi

# ── Étape 5.9 — brain-ui (npm install) ───────────────────────────────────────
echo ""
echo "[ 5.9 ] brain-ui..."
BRAIN_UI="$BRAIN_ROOT/brain-ui"
if [[ -f "$BRAIN_UI/package.json" ]]; then
  if [[ -d "$BRAIN_UI/node_modules" ]]; then
    ok "brain-ui node_modules présent"
  else
    info "Installation des dépendances brain-ui..."
    (cd "$BRAIN_UI" && npm install --silent) && ok "brain-ui deps OK" || warn "npm install brain-ui échoué — vérifier manuellement"
  fi
  # Créer .env.local si absent
  if [[ ! -f "$BRAIN_UI/.env.local" ]]; then
    cat > "$BRAIN_UI/.env.local" << 'ENVEOF'
VITE_USE_MOCK=true
VITE_BRAIN_API=
ENVEOF
    ok "brain-ui/.env.local créé (mode mock)"
  fi
else
  warn "brain-ui/package.json absent — skip"
fi

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║              Setup terminé                   ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  brain_name : $BRAIN_NAME"
echo "  brain_root : $BRAIN_ROOT"
echo "  source git : $GIT_SOURCE"
echo ""
echo "  Satellites clonés :"
for entry in "${SATELLITES[@]}"; do
  repo="${entry%%:*}"
  dest="${entry#*:}"
  echo "    $repo → $dest"
done
echo ""
echo "  Modes de démarrage :"
echo "  → Dev local (mock, pas de VPS) :"
echo "      bash $BRAIN_ROOT/scripts/brain-dev.sh"
echo "  → Dev local + engine :"
echo "      bash $BRAIN_ROOT/scripts/brain-dev.sh --engine"
echo "  → Session Claude Code :"
echo "      Ouvrir Claude Code dans $BRAIN_ROOT"
echo "      Le brain se boot automatiquement via CLAUDE.md"
echo ""
warn "Si MYSECRETS est absent : le remplir avant la première session work."
echo ""
