#!/usr/bin/env bash
# brain-start-laptop.sh — Démarre l'environnement brain sur le laptop
# Lancé après un reboot ou en début de session.
#
# Usage : bash scripts/brain-start-laptop.sh
#
# Lance :
#   1. Ollama (si pas déjà up)
#   2. brain-engine/server.py → port 7700
#   3. Vérifie la connexion peer desktop
#   4. Affiche l'écart embeddings (sync si besoin)
#
# Le script reste en foreground — brain-engine tourne tant que le terminal est ouvert.
# Laisser tourner dans un terminal dédié, travailler dans un autre.
# Arrêt propre : Ctrl+C (trap SIGINT → kill brain-engine)
# Pour nous uniquement — pas dans le template.

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG_SERVER="$BRAIN_ROOT/brain-engine/server-local.log"
DESKTOP_PEER="192.168.1.11"

cleanup() {
  echo ""
  echo "→ Arrêt brain laptop..."
  kill "$PID_SERVER" 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM

echo ""
echo "=== 🧠 Brain laptop — startup ==="
echo "    Root : $BRAIN_ROOT"
echo ""

# 1. Ollama
echo "--- 1/4 Ollama ---"
if ! pgrep -x ollama > /dev/null 2>&1; then
  sudo systemctl start ollama 2>/dev/null || ollama serve &>/dev/null &
  sleep 2
fi
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
  echo "✅ Ollama up"
else
  echo "⚠️  Ollama non disponible — RAG local désactivé"
fi

# 2. Brain-engine
echo ""
echo "--- 2/4 brain-engine ---"
# Kill instance précédente si elle tourne
pkill -f "python3 brain-engine/server.py" 2>/dev/null || true
sleep 1

cd "$BRAIN_ROOT"
python3 brain-engine/server.py > "$LOG_SERVER" 2>&1 &
PID_SERVER=$!
sleep 3

if kill -0 "$PID_SERVER" 2>/dev/null; then
  echo "✅ brain-engine PID $PID_SERVER → http://localhost:7700"
else
  echo "❌ brain-engine n'a pas démarré — voir $LOG_SERVER"
  exit 1
fi

# 3. Peer desktop
echo ""
echo "--- 3/4 Peer desktop ---"
if curl -s "http://${DESKTOP_PEER}:7700/health" > /dev/null 2>&1; then
  echo "✅ Desktop online (${DESKTOP_PEER}:7700)"
else
  echo "⚠️  Desktop offline — mode autonome"
fi

# 4. Écart embeddings
echo ""
echo "--- 4/4 Embeddings ---"
bash "$BRAIN_ROOT/scripts/brain-sync-replica.sh" status 2>&1

echo ""
echo "=== Brain laptop prêt ==="
echo "    brain-engine : http://localhost:7700"
echo "    BSI network  : http://localhost:7700/bsi/network"
echo ""
echo "    Ctrl+C pour arrêter"

wait "$PID_SERVER"
