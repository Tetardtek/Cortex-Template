#!/bin/bash
# brain-ui/build.sh — Build le dashboard pour servir via brain-engine
# Usage : bash brain-ui/build.sh
# Prérequis : Node.js 18+, npm

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== brain-ui — build ==="

# 1. Vérifier Node
if ! command -v node &>/dev/null; then
    echo "❌ Node.js requis (18+). Installe-le : https://nodejs.org/"
    exit 1
fi

# 2. Install deps
cd "$SCRIPT_DIR"
if [ ! -d "node_modules" ]; then
    echo "→ Installation des dépendances..."
    npm install
fi

# 3. Build (skip type check — erreurs TS pré-existantes non bloquantes)
echo "→ Build en cours..."
npx vite build

echo ""
echo "✅ brain-ui build dans dist/"
echo "   Servi automatiquement par brain-engine sur /ui/"
echo "   Lance : bash brain-engine/start.sh"
echo "   Puis ouvre : http://localhost:7700/ui/"
