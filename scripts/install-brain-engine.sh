#!/usr/bin/env bash
# install-brain-engine.sh — Installe Brain-as-a-Service sur le VPS (BE-3c)
#
# Usage :
#   bash scripts/install-brain-engine.sh          → installation complète
#   bash scripts/install-brain-engine.sh --check  → vérifie l'état sans modifier
#
# Prérequis :
#   - BRAIN_TOKEN défini dans MYSECRETS
#   - Ollama actif + nomic-embed-text pullé
#   - brain.db indexé (embed.py déjà lancé)
#
# Après installation :
#   sudo systemctl status brain-engine
#   curl http://localhost:7700/health

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVICE_SRC="$BRAIN_ROOT/toolkit/systemd/brain-engine.service"
SERVICE_DST="/etc/systemd/system/brain-engine.service"
MYSECRETS="$BRAIN_ROOT/MYSECRETS"

# ── Check mode ─────────────────────────────────────────────────────────────────

check_mode() {
    echo "=== brain-engine install --check ==="
    local ok=true

    # BRAIN_TOKEN dans MYSECRETS
    if grep -q "^BRAIN_TOKEN=.\+" "$MYSECRETS" 2>/dev/null; then
        echo "✅ BRAIN_TOKEN défini dans MYSECRETS"
    else
        echo "❌ BRAIN_TOKEN absent ou vide dans MYSECRETS"
        ok=false
    fi

    # Service installé
    if [[ -f "$SERVICE_DST" ]]; then
        echo "✅ Service installé : $SERVICE_DST"
    else
        echo "⚠️  Service non installé (sudo requis)"
        ok=false
    fi

    # Service actif
    if systemctl is-active --quiet brain-engine 2>/dev/null; then
        echo "✅ brain-engine actif"
    else
        echo "⚠️  brain-engine non actif"
        ok=false
    fi

    # /health répond
    if curl -sf http://localhost:7700/health &>/dev/null; then
        echo "✅ /health répond sur :7700"
    else
        echo "⚠️  /health injoignable (serveur non démarré ?)"
        ok=false
    fi

    $ok && exit 0 || exit 1
}

# ── Install ────────────────────────────────────────────────────────────────────

install_mode() {
    echo "=== brain-engine install ==="

    # Vérifications préalables
    if ! grep -q "^BRAIN_TOKEN=.\+" "$MYSECRETS" 2>/dev/null; then
        echo "❌ BRAIN_TOKEN absent ou vide dans MYSECRETS — arrêt." >&2
        echo "   Ajouter : BRAIN_TOKEN=<token> dans $MYSECRETS" >&2
        exit 1
    fi
    echo "✅ BRAIN_TOKEN présent"

    if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
        echo "⚙️  Installation des dépendances Python..."
        pip3 install fastapi uvicorn httpx --break-system-packages
    fi
    echo "✅ Dépendances Python OK"

    # Copie du service
    echo "⚙️  Installation du service systemd..."
    sudo cp "$SERVICE_SRC" "$SERVICE_DST"
    sudo systemctl daemon-reload
    sudo systemctl enable brain-engine
    sudo systemctl restart brain-engine
    echo "✅ Service installé et démarré"

    sleep 2
    if curl -sf http://localhost:7700/health | python3 -m json.tool; then
        echo "✅ brain-engine opérationnel — port 7700"
    else
        echo "⚠️  /health injoignable — vérifier : sudo journalctl -u brain-engine -n 50"
        exit 1
    fi
}

# ── Main ───────────────────────────────────────────────────────────────────────

case "${1:-}" in
    --check) check_mode ;;
    "")      install_mode ;;
    *)       echo "Usage : install-brain-engine.sh [--check]" >&2; exit 1 ;;
esac
