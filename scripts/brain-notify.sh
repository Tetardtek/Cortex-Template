#!/bin/bash
# brain-notify.sh — Canal Telegram du SUPERVISOR
# Usage: brain-notify.sh "MESSAGE" [urgent|update|info] [supervisor|monitoring]
#
#   Niveaux :
#     urgent → 🔴 notification sonore — interruption humaine
#     update → ✅ notification silencieuse — info non bloquante
#     info   → 💬 notification silencieuse — log passif
#
#   Canaux :
#     supervisor  → groupe SUPERVISOR (défaut pour urgent)
#     monitoring  → channel Monitoring (défaut pour update/info)
#     (si omis)   → supervisor pour urgent, monitoring pour update/info
#
# Token lu depuis MYSECRETS — jamais hardcodé.

set -euo pipefail

MYSECRETS="${BRAIN_ROOT:-$HOME/Dev/Brain}/MYSECRETS"

if [[ ! -f "$MYSECRETS" ]]; then
  echo "[brain-notify] ERREUR : MYSECRETS introuvable à $MYSECRETS" >&2
  exit 1
fi

TOKEN=$(grep '^BRAIN_TELEGRAM_TOKEN=' "$MYSECRETS" | cut -d= -f2-)
CHAT_ID_SUPERVISOR=$(grep '^BRAIN_TELEGRAM_CHAT_ID_SUPERVISOR=' "$MYSECRETS" | cut -d= -f2- || true)
CHAT_ID_MONITORING=$(grep '^BRAIN_TELEGRAM_CHAT_ID_MONITORING=' "$MYSECRETS" | cut -d= -f2- || true)

# Fallback : ancienne clé unique si les nouvelles ne sont pas encore définies
if [[ -z "$CHAT_ID_SUPERVISOR" && -z "$CHAT_ID_MONITORING" ]]; then
  FALLBACK=$(grep '^BRAIN_TELEGRAM_CHAT_ID=' "$MYSECRETS" | cut -d= -f2- || true)
  CHAT_ID_SUPERVISOR="$FALLBACK"
  CHAT_ID_MONITORING="$FALLBACK"
fi

if [[ -z "$TOKEN" ]]; then
  echo "[brain-notify] ERREUR : BRAIN_TELEGRAM_TOKEN vide dans MYSECRETS" >&2
  exit 1
fi

MESSAGE=$(printf '%b' "${1:-}")
LEVEL="${2:-info}"
CHANNEL="${3:-}"

if [[ -z "$MESSAGE" ]]; then
  echo "[brain-notify] ERREUR : message vide" >&2
  exit 1
fi

# Niveau → préfixe + silence
case "$LEVEL" in
  urgent) PREFIX="🔴 *BRAIN ESCALADE*" ; SILENT=false ;;
  update) PREFIX="✅ *BRAIN UPDATE*"   ; SILENT=true  ;;
  info)   PREFIX="💬 *BRAIN*"          ; SILENT=true  ;;
  *)      PREFIX="💬 *BRAIN*"          ; SILENT=true  ;;
esac

# Canal par défaut selon le niveau si non spécifié
if [[ -z "$CHANNEL" ]]; then
  [[ "$LEVEL" == "urgent" ]] && CHANNEL="supervisor" || CHANNEL="monitoring"
fi

# Sélection du chat_id
case "$CHANNEL" in
  supervisor) CHAT_ID="$CHAT_ID_SUPERVISOR" ;;
  monitoring) CHAT_ID="$CHAT_ID_MONITORING" ;;
  *)          CHAT_ID="$CHAT_ID_SUPERVISOR" ;;
esac

if [[ -z "$CHAT_ID" ]]; then
  echo "[brain-notify] ERREUR : chat_id manquant pour canal '$CHANNEL' dans MYSECRETS" >&2
  exit 1
fi

FULL_MESSAGE="${PREFIX}
${MESSAGE}
_$(date '+%Y-%m-%d %H:%M')_"

DISABLE_NOTIFICATION=$( [[ "$SILENT" == "true" ]] && echo "true" || echo "false" )

curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" \
  --data-urlencode "text=$FULL_MESSAGE" \
  -d parse_mode="Markdown" \
  -d disable_notification="$DISABLE_NOTIFICATION" \
  > /dev/null

echo "[brain-notify] [$LEVEL→$CHANNEL] envoyé"
