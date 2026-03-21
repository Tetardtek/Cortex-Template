#!/usr/bin/env bash
# brain-template-push.sh — Export brain-template.db + push vers VPS + restart
# Usage: bash scripts/brain-template-push.sh
#
# Workflow : export local → scp → restart brain-engine sur VPS
# Prérequis : VPS_IP et VPS_SSH_USER dans MYSECRETS

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
scp -q "$TEMPLATE_DB" "${VPS_USER}@${VPS_IP}:~/Dev/Brain/brain-template.db"
echo "✅ brain-template.db transféré"

# Step 3 : Restart
echo ""
echo "3/3 Restart brain-engine..."
ssh "${VPS_USER}@${VPS_IP}" "sudo systemctl restart brain-engine"
echo "✅ brain-engine redémarré"

echo ""
echo "🏁 Template déployé sur VPS — brain.tetardtek.com sert le template."
