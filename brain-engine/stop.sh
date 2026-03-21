#!/bin/bash
# brain-engine/stop.sh — Arrêt propre
# Usage : bash brain-engine/stop.sh

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PIDFILE="$BRAIN_ROOT/.brain-engine.pid"

if [ ! -f "$PIDFILE" ]; then
    echo "brain-engine n'est pas démarré (pas de PID tracké)"
    exit 0
fi

PID=$(cat "$PIDFILE")

if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    # Attendre l'arrêt propre (max 5s)
    for i in $(seq 1 10); do
        kill -0 "$PID" 2>/dev/null || break
        sleep 0.5
    done

    if kill -0 "$PID" 2>/dev/null; then
        echo "⚠️  brain-engine ne répond pas — force kill"
        kill -9 "$PID" 2>/dev/null
    fi

    rm -f "$PIDFILE"
    echo "✅ brain-engine arrêté (PID $PID)"
else
    rm -f "$PIDFILE"
    echo "brain-engine n'était plus actif (PID $PID stale — nettoyé)"
fi
