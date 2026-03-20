#!/bin/bash
# brain-engine/start.sh — Démarrage standalone
# Usage : bash brain-engine/start.sh
# Prérequis : Python 3.10+, Ollama (pour l'embedding — optionnel au premier boot)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRAIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== brain-engine — standalone boot ==="
echo "Brain root : $BRAIN_ROOT"

# 1. Vérifier Python
if ! command -v python3 &>/dev/null; then
    echo "❌ Python 3 requis. Installe-le : sudo apt install python3 python3-pip python3-venv"
    exit 1
fi

# 2. Installer les dépendances (venv recommandé)
if [ ! -d "$SCRIPT_DIR/.venv" ]; then
    echo "→ Création environnement virtuel..."
    python3 -m venv "$SCRIPT_DIR/.venv"
fi
source "$SCRIPT_DIR/.venv/bin/activate"
pip install -q -r "$SCRIPT_DIR/requirements.txt"

# 3. Initialiser brain.db si absent
if [ ! -f "$BRAIN_ROOT/brain.db" ]; then
    echo "→ Initialisation brain.db..."
    python3 "$SCRIPT_DIR/migrate.py" --reset 2>/dev/null || python3 "$SCRIPT_DIR/migrate.py"
    echo "✅ brain.db créé"
else
    echo "✅ brain.db existant"
fi

# 4. Embedding (optionnel — requiert Ollama)
if command -v ollama &>/dev/null; then
    INDEXED=$(python3 -c "
import sqlite3, os
db = os.path.join('$BRAIN_ROOT', 'brain.db')
if os.path.exists(db):
    c = sqlite3.connect(db)
    try: print(c.execute('SELECT COUNT(*) FROM embeddings WHERE indexed=1').fetchone()[0])
    except: print(0)
    c.close()
else: print(0)
" 2>/dev/null || echo "0")

    if [ "$INDEXED" = "0" ]; then
        echo "→ Premier embedding du corpus (Ollama détecté)..."
        python3 "$SCRIPT_DIR/embed.py"
        echo "✅ Corpus indexé"
    else
        echo "✅ $INDEXED chunks déjà indexés"
    fi
else
    echo "⚠️  Ollama non détecté — la recherche sémantique ne fonctionnera pas."
    echo "   Installe Ollama : curl -fsSL https://ollama.com/install.sh | sh"
    echo "   Puis : ollama pull nomic-embed-text && bash brain-engine/start.sh"
    echo "   Le serveur démarre quand même (BSI, docs, endpoints basiques)."
fi

# 5. Lancer le serveur
PORT="${BRAIN_PORT:-7700}"
echo ""
echo "=== Lancement brain-engine sur port $PORT ==="
echo "  Health : http://localhost:$PORT/health"
echo "  Search : http://localhost:$PORT/search?q=comment+ca+marche"
echo "  Agents : http://localhost:$PORT/agents"
echo ""

cd "$BRAIN_ROOT"
python3 "$SCRIPT_DIR/server.py"
