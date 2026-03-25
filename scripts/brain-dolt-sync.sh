#!/usr/bin/env bash
# brain-dolt-sync.sh — Push/pull brain-dolt entre desktop et VPS via rsync
#
# Usage :
#   brain-dolt-sync.sh push    → desktop → VPS
#   brain-dolt-sync.sh pull    → VPS → desktop
#   brain-dolt-sync.sh status  → compare les deux instances
#
# Prérequis : SSH configuré vers le VPS (voir infrastructure/ssh.md)
# Le VPS stocke dans /var/lib/dolt/brain-dolt/

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL_DIR="$BRAIN_ROOT/brain-dolt/"
REMOTE_USER="root"
REMOTE_HOST="31.97.154.126"
REMOTE_DIR="/var/lib/dolt/brain-dolt/"
CMD="${1:-status}"

# Couleurs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "$CMD" in
  push)
    echo -e "${GREEN}⬆ Push brain-dolt → VPS${NC}"
    # Ensure remote dir exists
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}"
    # Sync — archive mode, compress, delete extraneous on remote
    rsync -avz --delete \
      --exclude='import/' \
      "$LOCAL_DIR" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
    echo -e "${GREEN}✅ Push terminé${NC}"
    # Show remote commit count
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_DIR} && dolt log --oneline -n 3 2>/dev/null" || true
    ;;

  pull)
    echo -e "${GREEN}⬇ Pull brain-dolt ← VPS${NC}"
    rsync -avz --delete \
      --exclude='import/' \
      "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}" "$LOCAL_DIR"
    echo -e "${GREEN}✅ Pull terminé${NC}"
    cd "$LOCAL_DIR" && dolt log --oneline -n 3 2>/dev/null || true
    ;;

  status)
    echo -e "${YELLOW}📊 Comparaison desktop ↔ VPS${NC}"
    echo ""
    echo "--- Desktop ---"
    cd "$LOCAL_DIR" && dolt log --oneline -n 1 2>/dev/null || echo "(pas de commits)"
    LOCAL_CLAIMS=$(cd "$LOCAL_DIR" && dolt sql -q "SELECT COUNT(*) as n FROM claims;" -r csv 2>/dev/null | tail -1)
    echo "Claims: ${LOCAL_CLAIMS:-?}"
    echo ""
    echo "--- VPS ---"
    VPS_LOG=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_DIR} && dolt log --oneline -n 1 2>/dev/null" 2>/dev/null) || VPS_LOG="(pas de commits)"
    VPS_CLAIMS=$(ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ${REMOTE_DIR} && dolt sql -q 'SELECT COUNT(*) as n FROM claims;' -r csv 2>/dev/null | tail -1" 2>/dev/null) || VPS_CLAIMS="?"
    echo "$VPS_LOG"
    echo "Claims: ${VPS_CLAIMS}"
    echo ""
    if [ "$LOCAL_CLAIMS" = "$VPS_CLAIMS" ]; then
      echo -e "${GREEN}✅ Synchronized${NC}"
    else
      echo -e "${YELLOW}⚠️  Out of sync — desktop: ${LOCAL_CLAIMS} / VPS: ${VPS_CLAIMS}${NC}"
    fi
    ;;

  *)
    echo "Usage: brain-dolt-sync.sh <push|pull|status>"
    exit 1
    ;;
esac
