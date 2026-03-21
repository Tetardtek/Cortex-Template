#!/bin/bash
# brain-engine/status.sh — Statut rapide
# Usage : bash brain-engine/status.sh
# Exit 0 si running, 1 si stopped — utilisable dans des scripts/briefings

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIDFILE="$BRAIN_ROOT/.brain-engine.pid"
PORT="${BRAIN_PORT:-7700}"

if [ ! -f "$PIDFILE" ]; then
    echo "brain-engine: stopped"
    exit 1
fi

PID=$(cat "$PIDFILE")

if kill -0 "$PID" 2>/dev/null; then
    # Vérifier que le port répond
    if curl -s --max-time 2 "http://localhost:$PORT/health" > /dev/null 2>&1; then
        echo "brain-engine: running (PID $PID, port $PORT)"
    else
        echo "brain-engine: starting (PID $PID, port $PORT pas encore prêt)"
    fi
    exit 0
else
    rm -f "$PIDFILE"
    echo "brain-engine: stopped (PID $PID stale — nettoyé)"
    exit 1
fi
