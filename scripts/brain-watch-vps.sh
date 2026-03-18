#!/bin/bash
# brain-watch-vps.sh — Daemon SUPERVISOR VPS
# Clone le repo brain depuis Gitea, poll toutes les 30s
# Détecte les changements dans BRAIN-INDEX.md → notifie via Telegram
#
# Setup VPS (une seule fois) :
#   1. Copier ce script sur le VPS : scp brain-watch-vps.sh root@<VPS_IP>:/home/<user>/brain-watch/
#   2. Copier brain-notify.sh aussi
#   3. Cloner le brain : git clone git@<GITEA_URL>:<USERNAME>/brain.git /home/<user>/brain-watch/brain
#   4. Copier MYSECRETS sur le VPS : scp MYSECRETS root@<VPS_IP>:/home/<user>/brain-watch/
#   5. Installer le service systemd : install-brain-watch-vps.sh
#   6. systemctl start brain-watch && systemctl enable brain-watch

set -euo pipefail

# Configurable — override via env ou MYSECRETS (VPS_WATCH_ROOT=...)
WATCH_ROOT="${VPS_WATCH_ROOT:-$HOME/brain-watch}"
BRAIN_INDEX="$WATCH_ROOT/brain/BRAIN-INDEX.md"
NOTIFY="$WATCH_ROOT/brain-notify.sh"
BRAIN_ROOT="$WATCH_ROOT"  # pour brain-notify.sh — lit MYSECRETS ici
POLL_INTERVAL=30
LOG_PREFIX="[brain-watch-vps]"

export BRAIN_ROOT

if [[ ! -d "$WATCH_ROOT/brain" ]]; then
  BRAIN_GIT_URL="${BRAIN_GIT_URL:-$(grep '^BRAIN_GIT_URL=' "$WATCH_ROOT/MYSECRETS" 2>/dev/null | cut -d= -f2-)}"
  echo "$LOG_PREFIX ERREUR : brain non cloné. Lancer : git clone $BRAIN_GIT_URL $WATCH_ROOT/brain" >&2
  exit 1
fi

if [[ ! -x "$NOTIFY" ]]; then
  chmod +x "$NOTIFY"
fi

echo "$LOG_PREFIX Démarré — poll toutes les ${POLL_INTERVAL}s"

PREV_HASH=$(md5sum "$BRAIN_INDEX" 2>/dev/null | cut -d' ' -f1 || echo "")
PREV_CLAIMS=$(grep -v '^\*Aucun claim' "$BRAIN_INDEX" 2>/dev/null | grep -c '^\| sess-' || echo 0)

# Dédup stale — évite de respammer la même notif à chaque poll
STALE_NOTIFIED_FILE="/tmp/brain-watch-stale-notified.txt"
touch "$STALE_NOTIFIED_FILE"

check_stale_claims() {
  local now_epoch
  now_epoch=$(date +%s)

  while IFS= read -r line; do
    # Extraire l'ID de session (colonne 2) et la date d'expiration (colonne 6)
    local sess_id expire_raw expire_epoch
    sess_id=$(echo "$line" | awk -F'|' '{print $2}' | xargs)
    expire_raw=$(echo "$line" | awk -F'|' '{print $6}' | xargs)

    # Normaliser : "2026-03-14 18:24" ou "2026-03-14 +4h" → epoch
    # On ne gère que le format "YYYY-MM-DD HH:MM" (format standard du BSI)
    expire_epoch=$(date -d "$expire_raw" +%s 2>/dev/null || echo 0)

    [[ "$expire_epoch" -eq 0 ]] && continue
    [[ "$now_epoch" -le "$expire_epoch" ]] && continue

    # TTL expiré — vérifier si déjà notifié
    if grep -qF "$sess_id" "$STALE_NOTIFIED_FILE" 2>/dev/null; then
      continue
    fi

    # Première détection → notifier + mémoriser
    "$NOTIFY" "Claim stale détecté\n*Session :* \`$sess_id\`\n*Expiré le :* $expire_raw\nRecovery requis dans la session superviseur." "update"
    echo "$LOG_PREFIX STALE : $sess_id (expiré $expire_raw)"
    echo "$sess_id" >> "$STALE_NOTIFIED_FILE"

  done < <(grep '^| sess-' "$BRAIN_INDEX" 2>/dev/null | grep 'active' || true)
}

while true; do
  sleep "$POLL_INTERVAL"

  # Pull silencieux
  git -C "$WATCH_ROOT/brain" pull --quiet --ff-only 2>/dev/null || {
    echo "$LOG_PREFIX WARNING : git pull échoué"
    continue
  }

  # Vérification stale à chaque poll (indépendante du hash)
  check_stale_claims

  NEW_HASH=$(md5sum "$BRAIN_INDEX" | cut -d' ' -f1)
  [[ "$NEW_HASH" == "$PREV_HASH" ]] && continue
  PREV_HASH="$NEW_HASH"

  echo "$LOG_PREFIX Changement détecté dans BRAIN-INDEX.md"

  NEW_CLAIMS=$(grep -v '^\*Aucun claim' "$BRAIN_INDEX" | grep -c '^\| sess-' 2>/dev/null || echo 0)

  if [[ "$NEW_CLAIMS" -gt "$PREV_CLAIMS" ]]; then
    SESS=$(grep '^| sess-' "$BRAIN_INDEX" | grep 'active' | tail -1 | awk -F'|' '{print $2}' | xargs)
    "$NOTIFY" "Nouvelle session détectée\n*Session :* \`$SESS\`" "update"
    echo "$LOG_PREFIX Nouveau claim : $SESS"
  fi

  if [[ "$NEW_CLAIMS" -lt "$PREV_CLAIMS" ]]; then
    "$NOTIFY" "Session fermée — claim libéré\nClaims actifs restants : $NEW_CLAIMS" "info"
    echo "$LOG_PREFIX Claim fermé"
  fi

  PREV_CLAIMS="$NEW_CLAIMS"

  # BLOCKED_ON : uniquement dans les lignes de signaux réels (commence par "| sig-")
  # Évite le faux positif sur la doc du fichier ("- `BLOCKED_ON` — ...")
  BLOCKED=$(grep '^| sig-' "$BRAIN_INDEX" 2>/dev/null | grep 'BLOCKED_ON' | head -1 || true)
  if [[ -n "$BLOCKED" ]]; then
    "$NOTIFY" "Conflit inter-sessions\n$BLOCKED\nIntervention requise." "urgent"
    echo "$LOG_PREFIX ESCALADE : BLOCKED_ON"
  fi

  # CHECKPOINT / HANDOFF signal — notifier le supervisor
  SIGNAL=$(grep '^| sig-' "$BRAIN_INDEX" 2>/dev/null | grep -E 'CHECKPOINT|HANDOFF' | grep 'pending' | head -1 || true)
  if [[ -n "$SIGNAL" ]]; then
    SIG_TYPE=$(echo "$SIGNAL" | awk -F'|' '{print $5}' | xargs)
    SIG_FROM=$(echo "$SIGNAL" | awk -F'|' '{print $3}' | xargs)
    SIG_TO=$(echo "$SIGNAL" | awk -F'|' '{print $4}' | xargs)
    SIG_PAYLOAD=$(echo "$SIGNAL" | awk -F'|' '{print $7}' | xargs)
    "$NOTIFY" "📋 *$SIG_TYPE*\n*De :* \`$SIG_FROM\`\n*Pour :* \`$SIG_TO\`\n*Payload :* $SIG_PAYLOAD\nSession cible : lire le fichier au prochain boot." "update"
    echo "$LOG_PREFIX SIGNAL : $SIG_TYPE $SIG_FROM → $SIG_TO"
  fi

done
