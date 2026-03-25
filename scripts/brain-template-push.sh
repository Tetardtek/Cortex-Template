#!/usr/bin/env bash
# brain-template-push.sh — Export brain-template.db + push vers VPS + restart
# Usage: bash scripts/brain-template-push.sh
#
# Workflow : export local → scp → restart brain-engine sur VPS
# Prérequis : VPS_IP, VPS_SSH_USER, VPS_TEMPLATE_PATH dans MYSECRETS
# VPS_TEMPLATE_PATH optionnel — défaut : /home/tetardtek/Dev/Cortex-Template

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DB="${BRAIN_ROOT}/brain-template.db"
SECRETS="${HOME}/Dev/BrainSecrets/MYSECRETS"

# Lire VPS config depuis MYSECRETS (silencieux — pas de valeur affichée)
if [[ ! -f "$SECRETS" ]]; then
    echo "❌ MYSECRETS introuvable" >&2
    exit 1
fi

VPS_IP=$(grep '^VPS_IP=' "$SECRETS" | cut -d= -f2-)
VPS_USER=$(grep '^VPS_SSH_USER=' "$SECRETS" | cut -d= -f2-)
VPS_TEMPLATE_PATH=$(grep '^VPS_TEMPLATE_PATH=' "$SECRETS" 2>/dev/null | cut -d= -f2- || true)
VPS_TEMPLATE_PATH="${VPS_TEMPLATE_PATH:-/home/tetardtek/Dev/Cortex-Template}"

if [[ -z "$VPS_IP" || -z "$VPS_USER" ]]; then
    echo "❌ VPS_IP ou VPS_SSH_USER manquant dans MYSECRETS" >&2
    exit 1
fi

# Step 1 : Export
echo "1/3 Export brain-template.db..."
bash "${BRAIN_ROOT}/scripts/brain-template-export.sh" "$TEMPLATE_DB"

# Step 2 : SCP
echo ""
echo "2/3 Push vers VPS..."
scp -q "$TEMPLATE_DB" "${VPS_USER}@${VPS_IP}:${VPS_TEMPLATE_PATH}/brain-template.db"
echo "✅ brain-template.db transféré"

# Step 3 : Restart brain-engine (si systemd disponible, sinon skip)
echo ""
echo "3/3 Restart brain-engine..."
if ssh "${VPS_USER}@${VPS_IP}" "systemctl is-active brain-engine >/dev/null 2>&1"; then
    ssh "${VPS_USER}@${VPS_IP}" "sudo systemctl restart brain-engine"
    echo "✅ brain-engine redémarré"
else
    echo "ℹ️  brain-engine pas en systemd — skip restart"
fi

echo ""
echo "🏁 Template déployé sur VPS (${VPS_TEMPLATE_PATH})"
