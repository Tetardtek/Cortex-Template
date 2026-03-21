#!/bin/bash
# setup.sh — Installation complete du brain
# Usage : bash setup.sh
# Fait tout : build dashboard + init brain-engine + affiche les instructions

set -e

BRAIN_ROOT="$(cd "$(dirname "$0")" && pwd)"
echo "=== Brain Setup ==="
echo "Root : $BRAIN_ROOT"
echo ""

# 1. Config locale
if [ ! -f "$BRAIN_ROOT/brain-compose.local.yml" ]; then
    echo "→ Creation brain-compose.local.yml depuis l'exemple..."
    cp "$BRAIN_ROOT/brain-compose.local.yml.example" "$BRAIN_ROOT/brain-compose.local.yml"
    # Remplacer les placeholders par les valeurs detectees
    sed -i "s|<BRAIN_ROOT>|$BRAIN_ROOT|g" "$BRAIN_ROOT/brain-compose.local.yml"
    MACHINE=$(hostname)
    sed -i "s|<MACHINE_NAME>|$MACHINE|g" "$BRAIN_ROOT/brain-compose.local.yml"
    sed -i "s|<YYYY-MM-DD>|$(date +%Y-%m-%d)|g" "$BRAIN_ROOT/brain-compose.local.yml"
    # brain_name : dérivé du nom du dossier parent (ex: ~/Dev/Brain → brain)
    BRAIN_NAME=$(basename "$BRAIN_ROOT" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    sed -i "s|<BRAIN_NAME>|$BRAIN_NAME|g" "$BRAIN_ROOT/brain-compose.local.yml"
    echo "✅ brain-compose.local.yml cree (brain_name: $BRAIN_NAME)"
else
    echo "✅ brain-compose.local.yml existe deja"
fi

# 2. Satellites — cloner les repos si dispo, sinon creer les dossiers
echo ""
echo "=== Satellites ==="

# Satellites git (repos autonomes) — clones si l'org GitHub est detectee
# L'utilisateur peut definir BRAIN_GIT_ORG pour pointer vers son fork
if [ -z "${BRAIN_GIT_ORG:-}" ]; then
    # Detecter l'org depuis le remote origin du brain
    ORIGIN_URL=$(git -C "$BRAIN_ROOT" remote get-url origin 2>/dev/null || echo "")
    if echo "$ORIGIN_URL" | grep -q "github.com"; then
        BRAIN_GIT_ORG=$(echo "$ORIGIN_URL" | sed -E 's|.*github.com[:/]([^/]+)/.*|\1|')
        BRAIN_GIT_HOST="https://github.com"
    fi
fi

# Table des satellites git : dossier local → nom du repo
declare -A SAT_REPOS=(
    [profil]="Cortex-Profil"
    [todo]="Cortex-Todo"
    [toolkit]="Cortex-Toolkit"
    [progression]="Cortex-Progression"
    [reviews]="Cortex-Reviews"
)

for sat in "${!SAT_REPOS[@]}"; do
    if [ -d "$BRAIN_ROOT/$sat/.git" ]; then
        echo "  ✅ $sat/ — repo git present"
    elif [ -n "${BRAIN_GIT_ORG:-}" ] && [ -n "${BRAIN_GIT_HOST:-}" ]; then
        REPO_URL="$BRAIN_GIT_HOST/$BRAIN_GIT_ORG/${SAT_REPOS[$sat]}.git"
        echo "  → Clone $sat/ depuis $REPO_URL..."
        if git clone "$REPO_URL" "$BRAIN_ROOT/$sat" 2>/dev/null; then
            echo "  ✅ $sat/ clone"
        else
            echo "  ⚠️  $sat/ — clone echoue (repo inexistant ?). Creation dossier vide."
            mkdir -p "$BRAIN_ROOT/$sat"
            echo "# $sat" > "$BRAIN_ROOT/$sat/README.md"
        fi
    else
        if [ ! -d "$BRAIN_ROOT/$sat" ]; then
            mkdir -p "$BRAIN_ROOT/$sat"
            echo "# $sat" > "$BRAIN_ROOT/$sat/README.md"
            echo "  → $sat/ cree (vide — pas de remote detecte)"
        fi
    fi
done

# Dossiers internes (pas des repos git)
for dir in claims handoffs workspace; do
    if [ ! -d "$BRAIN_ROOT/$dir" ]; then
        mkdir -p "$BRAIN_ROOT/$dir"
        echo "# $dir" > "$BRAIN_ROOT/$dir/README.md"
        echo "  → $dir/ cree"
    fi
done

# focus.md — fichier critique pour helloWorld
if [ ! -f "$BRAIN_ROOT/focus.md" ]; then
    cat > "$BRAIN_ROOT/focus.md" << 'FOCUSEOF'
# Focus

> Direction actuelle du brain. Mis a jour par le scribe en fin de session.

Aucun focus defini — c'est un fresh fork. Lance `brain boot` pour commencer.
FOCUSEOF
    echo "  → focus.md cree"
fi
# profil/collaboration.md — si seulement le .example existe
if [ ! -f "$BRAIN_ROOT/profil/collaboration.md" ] && [ -f "$BRAIN_ROOT/profil/collaboration.md.example" ]; then
    cp "$BRAIN_ROOT/profil/collaboration.md.example" "$BRAIN_ROOT/profil/collaboration.md"
    echo "  → profil/collaboration.md cree depuis l'exemple"
fi
echo ""
echo "✅ Satellites prets"
echo ""
echo "  Satellites git (repos autonomes, gitignores) :"
echo "    profil/       → specs, ADRs, contextes, collaboration"
echo "    todo/         → tes intentions de session"
echo "    progression/  → ton parcours et tes metriques"
echo "    toolkit/      → tes patterns valides en prod"
echo "    reviews/      → audits de tes agents"
echo "  Dossiers internes :"
echo "    claims/       → sessions BSI actives"
echo "    handoffs/     → transferts entre sessions"
echo "    workspace/    → espace de travail temporaire"
echo "  Pour versionner les satellites : docs/satellites.md"

# 3. Build dashboard
echo ""
echo "=== Dashboard ==="
if [ -d "$BRAIN_ROOT/brain-ui" ]; then
    # Creer .env.local si absent — pointe vers brain-engine local
    if [ ! -f "$BRAIN_ROOT/brain-ui/.env.local" ]; then
        cat > "$BRAIN_ROOT/brain-ui/.env.local" << 'ENVEOF'
# VITE_BRAIN_API vide = requetes relatives (meme serveur)
# brain-engine sert l'UI ET l'API sur le meme port
VITE_BRAIN_API=
VITE_USE_MOCK=false
ENVEOF
        echo "✅ brain-ui/.env.local cree"
    fi
    if [ -d "$BRAIN_ROOT/brain-ui/dist" ]; then
        echo "✅ brain-ui deja build"
    else
        if command -v node &>/dev/null && command -v npm &>/dev/null; then
            echo "→ Build brain-ui..."
            cd "$BRAIN_ROOT/brain-ui" && npm install --silent && npm run build && cd "$BRAIN_ROOT"
            echo "✅ brain-ui build"
        else
            echo "⚠️  Node.js/npm absent — le dashboard ne sera pas disponible."
            echo "   Installe Node.js 18+ puis relance setup.sh"
        fi
    fi
else
    echo "⚠️  brain-ui/ absent — dashboard non disponible."
fi

# 3. Init brain-engine
echo ""
echo "=== Brain Engine ==="
if ! command -v python3 &>/dev/null; then
    echo "❌ Python 3 requis. Installe-le puis relance setup.sh"
    exit 1
fi

SCRIPT_DIR="$BRAIN_ROOT/brain-engine"
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "→ Creation environnement virtuel..."
    python3 -m venv "$SCRIPT_DIR/.venv"
fi
source "$SCRIPT_DIR/.venv/bin/activate"
pip install -q -r "$SCRIPT_DIR/requirements.txt"

if [ ! -f "$BRAIN_ROOT/brain.db" ]; then
    echo "→ Initialisation brain.db..."
    python3 "$SCRIPT_DIR/migrate.py" --reset 2>/dev/null || python3 "$SCRIPT_DIR/migrate.py"
    echo "✅ brain.db cree"
fi

# 4. Ollama check
echo ""
if command -v ollama &>/dev/null; then
    echo "✅ Ollama detecte — la recherche semantique fonctionnera"
else
    echo "⚠️  Ollama absent — la recherche semantique ne sera pas disponible."
    echo "   Optionnel : curl -fsSL https://ollama.com/install.sh | sh"
    echo "               ollama pull nomic-embed-text"
fi

# 5. Instructions finales
echo ""
echo "==========================================="
echo "  ✅ Brain installe !"
echo "==========================================="
echo ""
echo "  Lancer brain-engine :"
echo "    bash brain-engine/start.sh"
echo ""
echo "  Dashboard :"
echo "    http://localhost:7700/ui/"
echo ""
echo "  Premier boot Claude Code :"
echo "    cd $BRAIN_ROOT"
echo "    brain boot"
echo ""
echo "  Config Claude Code (si pas encore fait) :"
echo "    cp profil/CLAUDE.md.example ~/.claude/CLAUDE.md"
echo "    # Editer brain_root dans ~/.claude/CLAUDE.md"
echo ""
