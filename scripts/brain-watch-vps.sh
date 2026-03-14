#!/bin/bash
# brain-watch-vps.sh — Daemon SUPERVISOR VPS
# Clone le repo brain depuis Gitea, poll toutes les 30s
# Détecte les changements dans BRAIN-INDEX.md → notifie via Telegram
#
# Setup VPS (une seule fois) :
#   1. Copier ce script sur le VPS : scp brain-watch-vps.sh root@VPS:/home/tetardtek/brain-watch/
#   2. Copier brain-notify.sh aussi
#   3. Cloner le brain : git clone git@git.tetardtek.com:Tetardtek/brain.git /home/tetardtek/brain-watch/brain
#   4. Copier MYSECRETS sur le VPS : scp MYSECRETS root@VPS:/home/tetardtek/brain-watch/
#   5. Installer le service systemd : install-brain-watch-vps.sh
#   6. systemctl start brain-watch && systemctl enable brain-watch

set -euo pipefail

WATCH_ROOT="/home/tetardtek/brain-watch"
BRAIN_INDEX="$WATCH_ROOT/brain/BRAIN-INDEX.md"
NOTIFY="$WATCH_ROOT/brain-notify.sh"
BRAIN_ROOT="$WATCH_ROOT"  # pour brain-notify.sh — lit MYSECRETS ici
POLL_INTERVAL=30
LOG_PREFIX="[brain-watch-vps]"

export BRAIN_ROOT

if [[ ! -d "$WATCH_ROOT/brain" ]]; then
  echo "$LOG_PREFIX ERREUR : brain non cloné. Lancer : git clone git@git.tetardtek.com:Tetardtek/brain.git $WATCH_ROOT/brain" >&2
  exit 1
fi

if [[ ! -x "$NOTIFY" ]]; then
  chmod +x "$NOTIFY"
fi

echo "$LOG_PREFIX Démarré — poll toutes les ${POLL_INTERVAL}s"

PREV_HASH=$(md5sum "$BRAIN_INDEX" 2>/dev/null | cut -d' ' -f1 || echo "")
PREV_CLAIMS=$(grep -v '^\*Aucun claim' "$BRAIN_INDEX" 2>/dev/null | grep -c '^\| sess-' || echo 0)

while true; do
  sleep "$POLL_INTERVAL"

  # Pull silencieux
  git -C "$WATCH_ROOT/brain" pull --quiet --ff-only 2>/dev/null || {
    echo "$LOG_PREFIX WARNING : git pull échoué"
    continue
  }

  NEW_HASH=$(md5sum "$BRAIN_INDEX" | cut -d' ' -f1)
  [[ "$NEW_HASH" == "$PREV_HASH" ]] && continue
  PREV_HASH="$NEW_HASH"

  echo "$LOG_PREFIX Changement détecté dans BRAIN-INDEX.md"

  NEW_CLAIMS=$(grep -v '^\*Aucun claim' "$BRAIN_INDEX" | grep -c '^\| sess-' 2>/dev/null || echo 0)

  if [[ "$NEW_CLAIMS" -gt "$PREV_CLAIMS" ]]; then
    SESS=$(grep '^\| sess-' "$BRAIN_INDEX" | tail -1 | awk -F'|' '{print $2}' | xargs)
    "$NOTIFY" "Nouvelle session détectée\n*Session :* \`$SESS\`" "update"
    echo "$LOG_PREFIX Nouveau claim : $SESS"
  fi

  if [[ "$NEW_CLAIMS" -lt "$PREV_CLAIMS" ]]; then
    "$NOTIFY" "Session fermée — claim libéré\nClaims actifs restants : $NEW_CLAIMS" "info"
    echo "$LOG_PREFIX Claim fermé"
  fi

  PREV_CLAIMS="$NEW_CLAIMS"

  if grep -q 'BLOCKED_ON' "$BRAIN_INDEX" 2>/dev/null; then
    BLOCKED=$(grep 'BLOCKED_ON' "$BRAIN_INDEX" | head -1)
    "$NOTIFY" "Conflit inter-sessions (VPS)\n$BLOCKED\nIntervention requise." "urgent"
    echo "$LOG_PREFIX ESCALADE : BLOCKED_ON"
  fi

done
