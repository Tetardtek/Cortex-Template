#!/bin/bash
# get-telegram-chatid.sh — Récupère le chat_id Telegram et l'écrit dans MYSECRETS
# NE JAMAIS afficher la valeur dans le terminal — écriture directe dans MYSECRETS
#
# Prérequis : avoir envoyé /start au bot sur Telegram

set -euo pipefail

MYSECRETS="${BRAIN_ROOT:-$HOME/Dev/Docs}/MYSECRETS"

TOKEN=$(grep '^BRAIN_TELEGRAM_TOKEN=' "$MYSECRETS" | cut -d= -f2-)

if [[ -z "$TOKEN" ]]; then
  echo "ERREUR : BRAIN_TELEGRAM_TOKEN vide dans MYSECRETS" >&2
  exit 1
fi

# Récupérer le chat_id sans l'afficher
RESPONSE=$(curl -s "https://api.telegram.org/bot${TOKEN}/getUpdates")
CHAT_ID=$(echo "$RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('result', [])
if not results:
    print('NONE')
else:
    print(results[-1].get('message', {}).get('chat', {}).get('id', 'NONE'))
" 2>/dev/null)

if [[ "$CHAT_ID" == "NONE" || -z "$CHAT_ID" ]]; then
  echo "Aucun message reçu. Envoie /start au bot sur Telegram puis relance ce script." >&2
  exit 1
fi

# Écrire dans MYSECRETS sans afficher la valeur
if grep -q '^BRAIN_TELEGRAM_CHAT_ID=' "$MYSECRETS"; then
  sed -i "s/^BRAIN_TELEGRAM_CHAT_ID=.*/BRAIN_TELEGRAM_CHAT_ID=${CHAT_ID}/" "$MYSECRETS"
else
  echo "BRAIN_TELEGRAM_CHAT_ID=${CHAT_ID}" >> "$MYSECRETS"
fi

echo "✅ BRAIN_TELEGRAM_CHAT_ID enregistré dans MYSECRETS — valeur non affichée"
