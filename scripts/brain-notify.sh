#!/bin/bash
# brain-notify.sh — Canal Telegram du SUPERVISOR
# Usage: brain-notify.sh "MESSAGE" [urgent|update|info]
#   urgent → 🔴 notification sonore — interruption humaine
#   update → ✅ notification silencieuse — info non bloquante
#   info   → 💬 notification silencieuse — log passif
#
# Token lu depuis MYSECRETS — jamais hardcodé.

set -euo pipefail

MYSECRETS="${BRAIN_ROOT:-$HOME/Dev/Docs}/MYSECRETS"

if [[ ! -f "$MYSECRETS" ]]; then
  echo "[brain-notify] ERREUR : MYSECRETS introuvable à $MYSECRETS" >&2
  exit 1
fi

# Lire token + chat_id depuis MYSECRETS (source .env style)
TOKEN=$(grep '^BRAIN_TELEGRAM_TOKEN=' "$MYSECRETS" | cut -d= -f2-)
CHAT_ID=$(grep '^BRAIN_TELEGRAM_CHAT_ID=' "$MYSECRETS" | cut -d= -f2-)

if [[ -z "$TOKEN" || -z "$CHAT_ID" ]]; then
  echo "[brain-notify] ERREUR : BRAIN_TELEGRAM_TOKEN ou BRAIN_TELEGRAM_CHAT_ID vide dans MYSECRETS" >&2
  exit 1
fi

MESSAGE="${1:-}"
LEVEL="${2:-info}"

if [[ -z "$MESSAGE" ]]; then
  echo "[brain-notify] ERREUR : message vide" >&2
  exit 1
fi

# Préfixe selon le niveau
case "$LEVEL" in
  urgent) PREFIX="🔴 *BRAIN ESCALADE*" ; SILENT=false ;;
  update) PREFIX="✅ *BRAIN UPDATE*"   ; SILENT=true  ;;
  info)   PREFIX="💬 *BRAIN*"          ; SILENT=true  ;;
  *)      PREFIX="💬 *BRAIN*"          ; SILENT=true  ;;
esac

FULL_MESSAGE="${PREFIX}
${MESSAGE}
_$(date '+%Y-%m-%d %H:%M')_"

# Envoi Telegram
DISABLE_NOTIFICATION=$( [[ "$SILENT" == "true" ]] && echo "true" || echo "false" )

curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d text="$FULL_MESSAGE" \
  -d parse_mode="Markdown" \
  -d disable_notification="$DISABLE_NOTIFICATION" \
  > /dev/null

echo "[brain-notify] [$LEVEL] envoyé"
