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
    echo "✅ brain-compose.local.yml cree"
else
    echo "✅ brain-compose.local.yml existe deja"
fi

# 2. Satellites — creer les dossiers de base si absents
echo ""
echo "=== Satellites ==="
SATELLITES="todo toolkit progression reviews claims handoffs workspace"
for sat in $SATELLITES; do
    if [ ! -d "$BRAIN_ROOT/$sat" ]; then
        mkdir -p "$BRAIN_ROOT/$sat"
        echo "# $sat" > "$BRAIN_ROOT/$sat/README.md"
        echo "  → $sat/ cree (vide)"
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
echo "✅ Satellites prets"

# 3. Build dashboard
echo ""
echo "=== Dashboard ==="
if [ -d "$BRAIN_ROOT/brain-ui/dist" ]; then
    echo "✅ brain-ui deja build"
else
    if command -v node &>/dev/null && command -v npm &>/dev/null; then
        bash "$BRAIN_ROOT/brain-ui/build.sh"
    else
        echo "⚠️  Node.js/npm absent — le dashboard ne sera pas disponible."
        echo "   Installe Node.js 18+ puis relance : bash brain-ui/build.sh"
    fi
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
