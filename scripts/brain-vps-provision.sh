#!/bin/bash
# brain-vps-provision.sh — Provisionne un user brain dédié sur un VPS
# Usage : ssh root@<VPS_IP> 'bash -s' < brain-vps-provision.sh [OPTIONS]
#   ou depuis le VPS : bash brain-vps-provision.sh [OPTIONS]
#
# Options :
#   --owner <name>       Nom du owner système (défaut: tetardtek)
#   --brain-user <name>  Nom du user brain (défaut: <owner>-brain)
#   --pubkey <key>       Clé publique SSH à autoriser (sinon: lit stdin ou skip)
#   --dry-run            Affiche les actions sans les exécuter
#
# Ce script est idempotent — safe à relancer.
# Doit être exécuté en root sur le VPS cible.

set -euo pipefail

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
skip() { echo -e "${YELLOW}[SKIP]${NC} $1"; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; exit 1; }
info() { echo -e "     $1"; }

# ── Parse args ────────────────────────────────────────────────────────────────
OWNER="tetardtek"
BRAIN_USER=""
PUBKEY=""
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --owner)      OWNER="$2"; shift 2 ;;
    --brain-user) BRAIN_USER="$2"; shift 2 ;;
    --pubkey)     PUBKEY="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    *)            fail "Option inconnue: $1" ;;
  esac
done

# Convention : <owner>-brain
[[ -z "$BRAIN_USER" ]] && BRAIN_USER="${OWNER}-brain"

# ── Vérifications ─────────────────────────────────────────────────────────────
[[ "$(id -u)" -ne 0 ]] && fail "Ce script doit être exécuté en root."

OWNER_HOME="/home/${OWNER}"
[[ ! -d "$OWNER_HOME" ]] && fail "Home du owner introuvable: $OWNER_HOME"

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  brain-vps-provision                                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
info "Owner:      $OWNER"
info "Brain user: $BRAIN_USER"
info "Owner home: $OWNER_HOME"
info "Dry run:    $DRY_RUN"
echo ""

# ── Helper ────────────────────────────────────────────────────────────────────
run() {
  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY]${NC} $*"
  else
    "$@"
  fi
}

# ── 1. Créer le user ─────────────────────────────────────────────────────────
if id "$BRAIN_USER" &>/dev/null; then
  skip "User $BRAIN_USER existe déjà"
else
  run useradd \
    --create-home \
    --shell /bin/bash \
    --comment "Brain automation user for $OWNER" \
    "$BRAIN_USER"
  ok "User $BRAIN_USER créé"
fi

# ── 2. Ajouter au groupe owner (accès répertoires projets) ───────────────────
if id -nG "$BRAIN_USER" 2>/dev/null | grep -qw "$OWNER"; then
  skip "$BRAIN_USER déjà dans le groupe $OWNER"
else
  run usermod -aG "$OWNER" "$BRAIN_USER"
  ok "$BRAIN_USER ajouté au groupe $OWNER"
fi

# Groupe docker (accès containers sans sudo)
if getent group docker &>/dev/null; then
  if id -nG "$BRAIN_USER" 2>/dev/null | grep -qw "docker"; then
    skip "$BRAIN_USER déjà dans le groupe docker"
  else
    run usermod -aG docker "$BRAIN_USER"
    ok "$BRAIN_USER ajouté au groupe docker"
  fi
else
  skip "Groupe docker inexistant — skip"
fi

# ── 3. Clé SSH ───────────────────────────────────────────────────────────────
BRAIN_SSH_DIR="/home/${BRAIN_USER}/.ssh"
BRAIN_AUTH_KEYS="${BRAIN_SSH_DIR}/authorized_keys"

if [[ ! -d "$BRAIN_SSH_DIR" ]]; then
  run mkdir -p "$BRAIN_SSH_DIR"
  run chmod 700 "$BRAIN_SSH_DIR"
  run chown "$BRAIN_USER:$BRAIN_USER" "$BRAIN_SSH_DIR"
  ok "Répertoire .ssh créé"
else
  skip ".ssh existe déjà"
fi

if [[ -n "$PUBKEY" ]]; then
  if [[ -f "$BRAIN_AUTH_KEYS" ]] && grep -qF "$PUBKEY" "$BRAIN_AUTH_KEYS" 2>/dev/null; then
    skip "Clé publique déjà présente"
  else
    if ! $DRY_RUN; then
      echo "$PUBKEY" >> "$BRAIN_AUTH_KEYS"
      chmod 600 "$BRAIN_AUTH_KEYS"
      chown "$BRAIN_USER:$BRAIN_USER" "$BRAIN_AUTH_KEYS"
    fi
    ok "Clé publique ajoutée"
  fi
else
  skip "Pas de clé publique fournie (--pubkey). À ajouter manuellement."
fi

# ── 4. Sudoers restreint ─────────────────────────────────────────────────────
SUDOERS_FILE="/etc/sudoers.d/${BRAIN_USER}"

# Auto-détection des chemins binaires
PM2_PATH=$(which pm2 2>/dev/null || echo "/usr/local/bin/pm2")
GIT_PATH=$(which git 2>/dev/null || echo "/usr/bin/git")
DOCKER_PATH=$(which docker 2>/dev/null || echo "/usr/bin/docker")
SYSTEMCTL_PATH=$(which systemctl 2>/dev/null || echo "/usr/bin/systemctl")
APACHE2CTL_PATH=$(which apache2ctl 2>/dev/null || echo "/usr/sbin/apache2ctl")
CERTBOT_PATH=$(which certbot 2>/dev/null || echo "/usr/bin/certbot")

info "pm2: $PM2_PATH | docker: $DOCKER_PATH"

# Commandes autorisées — le minimum pour opérer les services
SUDOERS_CONTENT="# Sudoers pour ${BRAIN_USER} — généré par brain-vps-provision.sh
# Idempotent — safe à regénérer.

# pm2 — gestion des process applicatifs
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${PM2_PATH} list
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${PM2_PATH} reload *
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${PM2_PATH} restart *
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${PM2_PATH} logs *
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${PM2_PATH} status

# git pull — mise à jour des projets déployés
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${GIT_PATH} -C ${OWNER_HOME}/github/* pull
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${GIT_PATH} -C ${OWNER_HOME}/gitea/* pull

# systemctl — services spécifiques uniquement
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${SYSTEMCTL_PATH} status *
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${SYSTEMCTL_PATH} restart apache2
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${SYSTEMCTL_PATH} reload apache2
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${SYSTEMCTL_PATH} restart uptime-kuma
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${SYSTEMCTL_PATH} restart brain-bot

# apache — test config avant reload
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${APACHE2CTL_PATH} configtest

# certbot — renouvellement SSL
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${CERTBOT_PATH} renew
${BRAIN_USER} ALL=(ALL) NOPASSWD: ${CERTBOT_PATH} --apache *
"

if [[ -f "$SUDOERS_FILE" ]]; then
  skip "Sudoers $SUDOERS_FILE existe déjà — regénération"
fi

if ! $DRY_RUN; then
  echo "$SUDOERS_CONTENT" > "$SUDOERS_FILE"
  chmod 440 "$SUDOERS_FILE"
  # Validation syntaxe sudoers
  if visudo -cf "$SUDOERS_FILE" &>/dev/null; then
    ok "Sudoers configuré et validé"
  else
    rm -f "$SUDOERS_FILE"
    fail "Erreur syntaxe sudoers — fichier supprimé par sécurité"
  fi
else
  echo -e "${YELLOW}[DRY]${NC} Écriture sudoers dans $SUDOERS_FILE"
fi

# ── 5. Permissions répertoires projets ────────────────────────────────────────
# Le owner doit avoir le group bit pour que brain-user puisse écrire
for dir in "${OWNER_HOME}/github" "${OWNER_HOME}/gitea"; do
  if [[ -d "$dir" ]]; then
    # g+rwx sur les répertoires, g+rw sur les fichiers
    run chmod -R g+rwX "$dir"
    # setgid pour que les nouveaux fichiers héritent du groupe
    run find "$dir" -type d -exec chmod g+s {} +
    ok "Permissions groupe ajustées: $dir"
  else
    skip "Répertoire introuvable: $dir"
  fi
done

# ── 6. Désactiver le login par mot de passe ──────────────────────────────────
if ! $DRY_RUN; then
  passwd -l "$BRAIN_USER" &>/dev/null
  ok "Login par mot de passe désactivé pour $BRAIN_USER"
fi

# ── Résumé ────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Provision terminée                                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
info "User:     $BRAIN_USER"
info "Home:     /home/$BRAIN_USER"
info "Groupe:   $OWNER (accès projets)"
info "Sudoers:  $SUDOERS_FILE"
info "Shell:    /bin/bash"
info "Password: désactivé (clé SSH uniquement)"
echo ""
info "Prochaines étapes :"
info "  1. Ajouter la clé publique si pas fait : --pubkey"
info "  2. Tester : ssh ${BRAIN_USER}@<VPS_IP> 'echo ok'"
info "  3. Mettre à jour ~/.ssh/config local"
echo ""
