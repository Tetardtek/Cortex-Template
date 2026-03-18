#!/bin/bash
# install-brain-watch.sh — Installation du SUPERVISOR daemon
# Usage : bash install-brain-watch.sh [local|vps|both]
#
# Prérequis :
#   - inotify-tools installé localement (sudo apt install inotify-tools)
#   - MYSECRETS rempli (BRAIN_TELEGRAM_TOKEN + BRAIN_TELEGRAM_CHAT_ID)
#   - Accès SSH root@VPS configuré

set -euo pipefail

TARGET="${1:-both}"
BRAIN_ROOT="${BRAIN_ROOT:-$HOME/Dev/Brain}"
VPS_USER="root"
VPS_IP=$(grep '^VPS_IP=' "$BRAIN_ROOT/MYSECRETS" | cut -d= -f2-)
# Configurable — lues depuis MYSECRETS si non définies en env
VPS_WATCH_ROOT="${VPS_WATCH_ROOT:-$(grep '^VPS_WATCH_ROOT=' "$BRAIN_ROOT/MYSECRETS" 2>/dev/null | cut -d= -f2- || echo "/home/$VPS_USER/brain-watch")}"
GITEA_BRAIN_URL="${BRAIN_GIT_URL:-$(grep '^BRAIN_GIT_URL=' "$BRAIN_ROOT/MYSECRETS" 2>/dev/null | cut -d= -f2-)}"
if [[ -z "$GITEA_BRAIN_URL" ]]; then
  echo "❌ BRAIN_GIT_URL manquant — ajouter dans MYSECRETS : BRAIN_GIT_URL=git@<host>:<user>/brain.git"
  exit 1
fi

install_local() {
  echo "=== Installation SUPERVISOR local (systemd user) ==="

  chmod +x "$BRAIN_ROOT/scripts/brain-notify.sh"
  chmod +x "$BRAIN_ROOT/scripts/brain-watch-local.sh"

  # Créer le service systemd user
  SERVICE_DIR="$HOME/.config/systemd/user"
  mkdir -p "$SERVICE_DIR"

  cat > "$SERVICE_DIR/brain-watch-local.service" << EOF
[Unit]
Description=Brain SUPERVISOR local — crash handler + BSI watcher
After=default.target

[Service]
Type=simple
ExecStart=$BRAIN_ROOT/scripts/brain-watch-local.sh
Restart=on-failure
RestartSec=10
Environment=BRAIN_ROOT=$BRAIN_ROOT
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable brain-watch-local
  systemctl --user start  brain-watch-local
  systemctl --user status brain-watch-local --no-pager | head -8

  # Linger : service actif même sans session ouverte
  loginctl enable-linger "$USER" 2>/dev/null || true

  echo ""
  echo "✅ brain-watch-local installé (systemd user)"
  echo "   Logs : journalctl --user -u brain-watch-local -f"
  echo "   Stop : systemctl --user stop brain-watch-local"
}

install_vps() {
  echo "=== Installation SUPERVISOR VPS ==="

  SSH="ssh $VPS_USER@$VPS_IP"

  # Créer le dossier
  $SSH "mkdir -p $VPS_WATCH_ROOT"

  # Copier les scripts
  scp "$BRAIN_ROOT/scripts/brain-notify.sh" "$VPS_USER@$VPS_IP:$VPS_WATCH_ROOT/"
  scp "$BRAIN_ROOT/scripts/brain-watch-vps.sh" "$VPS_USER@$VPS_IP:$VPS_WATCH_ROOT/"
  $SSH "chmod +x $VPS_WATCH_ROOT/brain-notify.sh $VPS_WATCH_ROOT/brain-watch-vps.sh"

  # Copier MYSECRETS (section brain-supervisor uniquement)
  # On écrit un MYSECRETS minimal sur le VPS avec uniquement les clés Telegram
  TOKEN=$(grep '^BRAIN_TELEGRAM_TOKEN=' "$BRAIN_ROOT/MYSECRETS" | cut -d= -f2-)
  CHAT_ID=$(grep '^BRAIN_TELEGRAM_CHAT_ID=' "$BRAIN_ROOT/MYSECRETS" | cut -d= -f2-)
  $SSH "cat > $VPS_WATCH_ROOT/MYSECRETS" << EOF
## brain-supervisor
BRAIN_TELEGRAM_TOKEN=$TOKEN
BRAIN_TELEGRAM_CHAT_ID=$CHAT_ID
EOF
  $SSH "chmod 600 $VPS_WATCH_ROOT/MYSECRETS"

  # Cloner le brain si pas déjà fait
  $SSH "
    if [[ ! -d $VPS_WATCH_ROOT/brain ]]; then
      git clone $GITEA_BRAIN_URL $VPS_WATCH_ROOT/brain
      echo 'Brain cloné'
    else
      echo 'Brain déjà cloné'
    fi
  "

  # Installer le service systemd
  $SSH "cat > /etc/systemd/system/brain-watch.service" << 'SYSTEMD'
[Unit]
Description=Brain SUPERVISOR — surveillance BRAIN-INDEX.md
After=network.target

[Service]
Type=simple
User=root
ExecStart=/home/tetardtek/brain-watch/brain-watch-vps.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SYSTEMD

  $SSH "systemctl daemon-reload && systemctl enable brain-watch && systemctl start brain-watch"
  $SSH "systemctl status brain-watch --no-pager | head -10"

  echo "✅ SUPERVISOR VPS installé (service brain-watch)"
}

case "$TARGET" in
  local) install_local ;;
  vps)   install_vps ;;
  both)  install_local ; install_vps ;;
  *)     echo "Usage: $0 [local|vps|both]" ; exit 1 ;;
esac

echo ""
echo "=== Setup Telegram (si pas encore fait) ==="
echo "1. Ouvrir Telegram → chercher @BotFather → /newbot"
echo "2. Copier le token dans MYSECRETS : BRAIN_TELEGRAM_TOKEN=<token>"
echo "3. Envoyer /start au bot sur Telegram, puis :"
echo "   bash brain/scripts/get-telegram-chatid.sh"
echo "   → écrit BRAIN_TELEGRAM_CHAT_ID dans MYSECRETS directement — valeur jamais affichée"
echo "4. Tester : BRAIN_ROOT=~/Dev/Brain brain/scripts/brain-notify.sh 'Test SUPERVISOR' urgent"
