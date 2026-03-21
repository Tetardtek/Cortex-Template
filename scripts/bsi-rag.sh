#!/bin/bash
# bsi-rag.sh — Wrapper bash pour brain-engine/rag.py
# Appele par helloWorld au boot pour enrichir le contexte RAG.
#
# Usage : bash scripts/bsi-rag.sh [query] [--json] [--full] [--top N]
#
# Silencieux si :
#   - Ollama indisponible
#   - brain-engine/.venv absent
#   - Aucun resultat
# Exit 0 dans tous les cas — le boot ne doit jamais echouer sur le RAG.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRAIN_ROOT="$(dirname "$SCRIPT_DIR")"
RAG_PY="$BRAIN_ROOT/brain-engine/rag.py"
VENV="$BRAIN_ROOT/brain-engine/.venv"

# ── Pre-checks (silencieux) ──────────────────────────────────────────────────

if [[ ! -f "$RAG_PY" ]]; then
  exit 0
fi

# ── Activation venv si disponible ────────────────────────────────────────────

if [[ -d "$VENV" ]]; then
  source "$VENV/bin/activate" 2>/dev/null
fi

# ── Execution ────────────────────────────────────────────────────────────────

python3 "$RAG_PY" "$@" 2>/dev/null
exit 0
