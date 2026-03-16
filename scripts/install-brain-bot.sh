#!/bin/bash
# install-brain-bot.sh — Installe brain-bot.py sur le VPS
# =========================================================
#
# Ce script configure le webhook Telegram sur le VPS :
#   1. Copie brain-bot.py dans le dossier brain-watch
#   2. Crée le service systemd brain-bot
#   3. Configure Apache pour proxifier bot.<domaine> → localhost:5001
#   4. Enregistre le webhook Telegram (setWebhook)
#
# Prérequis VPS :
#   - Python 3 installé (python3)
#   - Apache avec mod_proxy activé
#   - Certbot pour le SSL (Let's Encrypt)
#   - brain-watch déjà installé (MYSECRETS présent)
#
# Usage :
#   bash install-brain-bot.sh
#
# Le script demande les infos manquantes interactivement.

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration — à adapter si besoin
# ---------------------------------------------------------------------------

WATCH_ROOT="/home/tetardtek/brain-watch"
MYSECRETS="$WATCH_ROOT/MYSECRETS"
BOT_PORT=5001
BOT_SCRIPT="$WATCH_ROOT/brain-bot.py"
SERVICE_NAME="brain-bot"
LOG_PREFIX="[install-brain-bot]"

# ---------------------------------------------------------------------------
# Vérifications préalables
# ---------------------------------------------------------------------------

echo "$LOG_PREFIX Vérification des prérequis..."

if [[ ! -f "$MYSECRETS" ]]; then
  echo "$LOG_PREFIX ERREUR : MYSECRETS introuvable à $MYSECRETS" >&2
  echo "  → Lance d'abord install-brain-watch.sh vps" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "$LOG_PREFIX ERREUR : python3 non trouvé" >&2
  exit 1
fi

TOKEN=$(grep '^BRAIN_TELEGRAM_TOKEN=' "$MYSECRETS" | cut -d= -f2-)
CHAT_ID=$(grep '^BRAIN_TELEGRAM_CHAT_ID_SUPERVISOR=' "$MYSECRETS" | cut -d= -f2-)

if [[ -z "$TOKEN" || -z "$CHAT_ID" ]]; then
  echo "$LOG_PREFIX ERREUR : BRAIN_TELEGRAM_TOKEN ou BRAIN_TELEGRAM_CHAT_ID_SUPERVISOR manquant dans MYSECRETS" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Récupérer le domaine pour le webhook
# ---------------------------------------------------------------------------

echo ""
echo "Domaine pour le webhook (ex: bot.tetardtek.com) :"
echo -n "→ "
read -r BOT_DOMAIN

WEBHOOK_URL="https://${BOT_DOMAIN}/webhook"

# ---------------------------------------------------------------------------
# Copie du script
# ---------------------------------------------------------------------------

SCRIPT_SRC="$(dirname "$0")/brain-bot.py"

if [[ ! -f "$SCRIPT_SRC" ]]; then
  echo "$LOG_PREFIX ERREUR : brain-bot.py introuvable à $SCRIPT_SRC" >&2
  exit 1
fi

cp "$SCRIPT_SRC" "$BOT_SCRIPT"
chmod +x "$BOT_SCRIPT"
echo "$LOG_PREFIX brain-bot.py copié → $BOT_SCRIPT ✓"

# ---------------------------------------------------------------------------
# Service systemd
# ---------------------------------------------------------------------------

cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Brain SUPERVISOR Telegram Bot
After=network.target

[Service]
Type=simple
User=tetardtek
WorkingDirectory=${WATCH_ROOT}
Environment=BRAIN_WATCH_ROOT=${WATCH_ROOT}
Environment=BRAIN_BOT_PORT=${BOT_PORT}
ExecStart=/usr/bin/python3 ${BOT_SCRIPT}
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"
echo "$LOG_PREFIX Service systemd ${SERVICE_NAME} activé ✓"

# ---------------------------------------------------------------------------
# Apache vhost — proxy vers localhost:5001
# ---------------------------------------------------------------------------

VHOST_FILE="/etc/apache2/sites-available/${BOT_DOMAIN}.conf"

cat > "$VHOST_FILE" << EOF
<VirtualHost *:80>
    ServerName ${BOT_DOMAIN}
    # Redirect HTTP → HTTPS (Certbot complétera)
    RewriteEngine On
    RewriteRule ^(.*)$ https://${BOT_DOMAIN}\$1 [R=301,L]
</VirtualHost>

<VirtualHost *:443>
    ServerName ${BOT_DOMAIN}

    # Proxy vers brain-bot Python
    ProxyPreserveHost On
    ProxyPass        /webhook  http://127.0.0.1:${BOT_PORT}/webhook
    ProxyPassReverse /webhook  http://127.0.0.1:${BOT_PORT}/webhook
    ProxyPass        /health   http://127.0.0.1:${BOT_PORT}/health
    ProxyPassReverse /health   http://127.0.0.1:${BOT_PORT}/health

    # SSL — sera complété par Certbot
    # SSLCertificateFile ...
    # SSLCertificateKeyFile ...
</VirtualHost>
EOF

a2enmod proxy proxy_http rewrite 2>/dev/null || true
a2ensite "${BOT_DOMAIN}" 2>/dev/null || true

echo "$LOG_PREFIX Vhost Apache créé : $VHOST_FILE ✓"
echo ""
echo "→ Lance Certbot pour le SSL :"
echo "   sudo certbot --apache -d ${BOT_DOMAIN}"
echo ""
echo -n "SSL Certbot déjà configuré ? (o/n) : "
read -r SSL_DONE

if [[ "$SSL_DONE" == "o" || "$SSL_DONE" == "O" ]]; then
  apache2ctl configtest && systemctl reload apache2
  echo "$LOG_PREFIX Apache rechargé ✓"
else
  echo "$LOG_PREFIX En attente SSL — relance ce script ou recharge Apache après Certbot"
fi

# ---------------------------------------------------------------------------
# Enregistrement webhook Telegram (setWebhook)
# ---------------------------------------------------------------------------

echo ""
echo "$LOG_PREFIX Enregistrement webhook Telegram → $WEBHOOK_URL"

RESPONSE=$(curl -s -X POST \
  "https://api.telegram.org/bot${TOKEN}/setWebhook" \
  -d "url=${WEBHOOK_URL}")

OK=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('ok','false'))")

if [[ "$OK" == "True" ]]; then
  echo "$LOG_PREFIX ✅ Webhook enregistré → $WEBHOOK_URL"
else
  echo "$LOG_PREFIX ⚠️  Réponse Telegram inattendue (vérifier SSL et domaine)"
  # Ne pas afficher RESPONSE — peut contenir le token
fi

# ---------------------------------------------------------------------------
# Test de santé
# ---------------------------------------------------------------------------

echo ""
sleep 2
STATUS=$(curl -s "http://127.0.0.1:${BOT_PORT}/health" || echo "DOWN")
if echo "$STATUS" | grep -q '"ok"'; then
  echo "$LOG_PREFIX ✅ brain-bot actif sur port ${BOT_PORT}"
else
  echo "$LOG_PREFIX ⚠️  brain-bot ne répond pas — vérifier : journalctl -u ${SERVICE_NAME} -n 20"
fi

echo ""
echo "────────────────────────────────────────"
echo " brain-bot installé"
echo "  Webhook : $WEBHOOK_URL"
echo "  Service : systemctl status ${SERVICE_NAME}"
echo "  Logs    : journalctl -u ${SERVICE_NAME} -f"
echo "────────────────────────────────────────"
