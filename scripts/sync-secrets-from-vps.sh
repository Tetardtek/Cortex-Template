#!/bin/bash
# sync-secrets-from-vps.sh — Migration one-shot : VPS .env → BrainSecrets/MYSECRETS
# Usage : bash scripts/sync-secrets-from-vps.sh
# Lancer depuis le terminal directement (jamais via Claude)
# Les valeurs ne sont jamais affichées — injection silencieuse

set -e

MYSECRETS="$HOME/Dev/BrainSecrets/MYSECRETS"
VPS_USER=$(grep '^VPS_USER=' "$MYSECRETS" | cut -d= -f2-)
VPS_IP=$(grep '^VPS_IP=' "$MYSECRETS" | cut -d= -f2-)

if [[ -z "$VPS_USER" || -z "$VPS_IP" ]]; then
  echo "❌ VPS_USER ou VPS_IP manquant dans MYSECRETS"
  exit 1
fi

echo "✅ VPS détecté : $VPS_USER@$VPS_IP"
echo ""

inject() {
  local prefix="$1"
  local key="$2"
  local val="$3"
  local full_key="${prefix}${key}"
  [[ -z "$val" ]] && return
  if grep -q "^${full_key}=" "$MYSECRETS"; then
    sed -i "s|^${full_key}=.*|${full_key}=${val}|" "$MYSECRETS"
  else
    echo "${full_key}=${val}" >> "$MYSECRETS"
  fi
}

# ── TetaRdPG ──────────────────────────────────────────────────────────────────
echo "→ TetaRdPG .env..."
while IFS='=' read -r key val; do
  [[ -z "$key" || "$key" =~ ^# || -z "$val" ]] && continue
  inject "TETARDPG_" "$key" "$val"
done < <(ssh "${VPS_USER}@${VPS_IP}" "cat /home/tetardtek/gitea/TetaRdPG/.env 2>/dev/null")
echo "   ✅ TETARDPG_* injectées"

# ── OriginsDigital ────────────────────────────────────────────────────────────
echo "→ OriginsDigital .env..."
while IFS='=' read -r key val; do
  [[ -z "$key" || "$key" =~ ^# || -z "$val" ]] && continue
  inject "ORIGINSDIGITAL_" "$key" "$val"
done < <(ssh "${VPS_USER}@${VPS_IP}" "cat /var/www/originsdigital/backend/.env 2>/dev/null")
echo "   ✅ ORIGINSDIGITAL_* injectées"

# ── MySQL root ────────────────────────────────────────────────────────────────
echo "→ MySQL root password..."
mysql_root=$(ssh "${VPS_USER}@${VPS_IP}" "docker inspect mysql-prod --format '{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep MYSQL_ROOT_PASSWORD | cut -d= -f2-")
inject "" "MYSQL_ROOT_PASSWORD" "$mysql_root"
echo "   ✅ MYSQL_ROOT_PASSWORD injectée"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Consolidation terminée — vérifie BrainSecrets/MYSECRETS"
echo "   cd ~/Dev/BrainSecrets && git add MYSECRETS && git commit -m 'feat(secrets): consolidation VPS .env' && git push"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
