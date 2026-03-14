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
BRAIN_ROOT="${BRAIN_ROOT:-$HOME/Dev/Docs}"
VPS_USER="root"
VPS_IP=$(grep '^VPS_IP=' "$BRAIN_ROOT/MYSECRETS" | cut -d= -f2-)
VPS_WATCH_ROOT="/home/tetardtek/brain-watch"
GITEA_BRAIN_URL="git@git.tetardtek.com:Tetardtek/brain.git"

install_local() {
  echo "=== Installation SUPERVISOR local ==="

  chmod +x "$BRAIN_ROOT/scripts/brain-notify.sh"
  chmod +x "$BRAIN_ROOT/scripts/brain-watch-local.sh"

  # Lancer en background
  LOGFILE="$HOME/brain-watch.log"
  nohup "$BRAIN_ROOT/scripts/brain-watch-local.sh" >> "$LOGFILE" 2>&1 &
  echo "PID $! — logs : $LOGFILE"

  # Ajouter au .bashrc pour redémarrage automatique (si pas déjà présent)
  MARKER="# brain-watch-local"
  if ! grep -q "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" << EOF

$MARKER
if ! pgrep -f "brain-watch-local.sh" > /dev/null; then
  nohup $BRAIN_ROOT/scripts/brain-watch-local.sh >> $HOME/brain-watch.log 2>&1 &
fi
EOF
    echo "Ajouté au .bashrc — démarrage automatique à l'ouverture du terminal"
  fi

  echo "✅ SUPERVISOR local installé"
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
echo "4. Tester : BRAIN_ROOT=~/Dev/Docs brain/scripts/brain-notify.sh 'Test SUPERVISOR' urgent"
