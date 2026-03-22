#!/usr/bin/env bash
# brain-engine.sh — CLI unifiée pour le lifecycle brain-engine
#
# Usage :
#   brain-engine start [--fg]     Démarrer (background par défaut, --fg = foreground)
#   brain-engine stop             Arrêter proprement
#   brain-engine status           PID, port, mode, uptime
#   brain-engine embed            Lancer un embedding one-shot
#   brain-engine logs             Tail des logs (journald ou fichier)
#   brain-engine install pm2      Installer via pm2 (restart on crash)
#   brain-engine install systemd  Installer via systemd (survit au reboot)
#
# Le mode (dev/prod/demo) est lu depuis BRAIN_MODE env var
# ou détecté depuis brain-compose.local.yml.
#
# Graduation :
#   Manuel  → brain-engine start        (je lance quand j'en ai besoin)
#   pm2     → brain-engine install pm2   (restart on crash, pas au reboot)
#   systemd → brain-engine install systemd (survit au reboot, logs journald)

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGINE_DIR="$BRAIN_ROOT/brain-engine"
SERVER="$ENGINE_DIR/server.py"
PID_FILE="$BRAIN_ROOT/.brain-engine.pid"
LOG_FILE="$BRAIN_ROOT/brain-engine.log"

# ── Couleurs ─────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}" >&2; }
info() { echo -e "   $1"; }

# ── Détection mode ───────────────────────────────────────────────────────────
detect_mode() {
  # 1. Env var explicite
  if [[ -n "${BRAIN_MODE:-}" ]]; then
    echo "$BRAIN_MODE"
    return
  fi

  # 2. brain-compose.local.yml
  local local_yml="$BRAIN_ROOT/brain-compose.local.yml"
  if [[ -f "$local_yml" ]]; then
    local mode
    mode=$(grep '^  *mode:' "$local_yml" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' || true)
    if [[ -n "$mode" ]]; then
      echo "$mode"
      return
    fi
  fi

  # 3. Défaut
  echo "dev"
}

# ── Détection port ───────────────────────────────────────────────────────────
detect_port() {
  echo "${BRAIN_PORT:-7700}"
}

# ── Prérequis ────────────────────────────────────────────────────────────────
check_prereqs() {
  if [[ ! -f "$SERVER" ]]; then
    err "brain-engine/server.py introuvable ($SERVER)"
    exit 1
  fi
  if ! command -v python3 &>/dev/null; then
    err "python3 non trouvé"
    exit 1
  fi
  if ! python3 -c "import fastapi, uvicorn" 2>/dev/null; then
    err "Dépendances manquantes — pip3 install -r $ENGINE_DIR/requirements.txt"
    exit 1
  fi
}

# ── PID helpers ──────────────────────────────────────────────────────────────
get_pid() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
      echo "$pid"
      return
    fi
    rm -f "$PID_FILE"
  fi
  # Fallback : chercher le process
  pgrep -f "python3.*brain-engine/server.py" 2>/dev/null | head -1 || true
}

is_running() {
  [[ -n "$(get_pid)" ]]
}

# ── Commandes ────────────────────────────────────────────────────────────────

cmd_start() {
  local fg=false
  [[ "${1:-}" == "--fg" ]] && fg=true

  check_prereqs

  if is_running; then
    warn "brain-engine déjà en cours (PID $(get_pid))"
    return 0
  fi

  local mode port
  mode=$(detect_mode)
  port=$(detect_port)

  echo "▶ brain-engine start"
  info "mode : $mode"
  info "port : $port"
  info "root : $BRAIN_ROOT"

  # Charger MYSECRETS si disponible et mode != demo
  local env_prefix=""
  local secrets_path="${BRAIN_ROOT}/../BrainSecrets/MYSECRETS"
  if [[ "$mode" != "demo" && -f "$secrets_path" ]]; then
    env_prefix="set -a && source '$secrets_path' && set +a && "
    info "secrets : chargés"
  elif [[ "$mode" == "demo" ]]; then
    info "secrets : non requis (demo)"
  else
    info "secrets : absents (fonctionnement dégradé)"
  fi

  if $fg; then
    info "mode foreground — Ctrl+C pour arrêter"
    echo ""
    eval "${env_prefix}BRAIN_MODE=$mode BRAIN_PORT=$port python3 '$SERVER'"
  else
    eval "${env_prefix}BRAIN_MODE=$mode BRAIN_PORT=$port python3 '$SERVER'" \
      >> "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"
    sleep 1

    if kill -0 "$pid" 2>/dev/null; then
      ok "brain-engine démarré (PID $pid, port $port)"
      info "logs : tail -f $LOG_FILE"
    else
      err "brain-engine a crashé au démarrage — voir $LOG_FILE"
      rm -f "$PID_FILE"
      exit 1
    fi
  fi
}

cmd_stop() {
  local pid
  pid=$(get_pid)

  if [[ -z "$pid" ]]; then
    info "brain-engine n'est pas en cours"
    return 0
  fi

  echo "▶ brain-engine stop (PID $pid)"
  kill "$pid" 2>/dev/null
  local i=0
  while kill -0 "$pid" 2>/dev/null && [[ $i -lt 10 ]]; do
    sleep 0.5
    ((i++))
  done

  if kill -0 "$pid" 2>/dev/null; then
    warn "kill -9 (arrêt forcé)"
    kill -9 "$pid" 2>/dev/null || true
  fi

  rm -f "$PID_FILE"
  ok "brain-engine arrêté"
}

cmd_status() {
  local pid mode port
  pid=$(get_pid)
  mode=$(detect_mode)
  port=$(detect_port)

  echo "▶ brain-engine status"
  info "mode : $mode"
  info "port : $port"
  info "root : $BRAIN_ROOT"

  if [[ -z "$pid" ]]; then
    # Vérifier systemd
    if systemctl is-active --quiet brain-engine 2>/dev/null; then
      info "pid  : $(systemctl show brain-engine --property=MainPID --value)"
      info "via  : systemd"
      ok "en cours (systemd)"
      return 0
    fi
    # Vérifier pm2
    if command -v pm2 &>/dev/null && pm2 describe brain-engine &>/dev/null 2>&1; then
      local pm2_status
      pm2_status=$(pm2 describe brain-engine 2>/dev/null | grep status | awk '{print $4}')
      info "via  : pm2 ($pm2_status)"
      if [[ "$pm2_status" == "online" ]]; then
        ok "en cours (pm2)"
      else
        warn "pm2 status: $pm2_status"
      fi
      return 0
    fi
    warn "arrêté"
    return 1
  fi

  # Uptime
  local uptime_s
  uptime_s=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ' || echo "?")
  if [[ "$uptime_s" =~ ^[0-9]+$ ]]; then
    local h=$((uptime_s / 3600))
    local m=$(((uptime_s % 3600) / 60))
    info "pid  : $pid"
    info "up   : ${h}h ${m}m"
  else
    info "pid  : $pid"
  fi

  # Health check
  if curl -sf "http://localhost:$port/health" &>/dev/null; then
    ok "en cours — /health OK"
  else
    warn "process actif mais /health ne répond pas"
  fi
}

cmd_embed() {
  local mode
  mode=$(detect_mode)

  if [[ "$mode" == "demo" ]]; then
    warn "embed désactivé en mode demo"
    return 0
  fi

  check_prereqs

  echo "▶ brain-engine embed (one-shot)"

  if ! command -v ollama &>/dev/null; then
    err "ollama non trouvé — requis pour l'embedding"
    exit 1
  fi

  local embed_script="$ENGINE_DIR/embed.py"
  if [[ ! -f "$embed_script" ]]; then
    err "brain-engine/embed.py introuvable"
    exit 1
  fi

  cd "$BRAIN_ROOT"
  BRAIN_MODE="$mode" python3 "$embed_script"
  ok "embedding terminé"
}

cmd_logs() {
  # systemd ?
  if systemctl is-active --quiet brain-engine 2>/dev/null; then
    info "source: journald"
    sudo journalctl -u brain-engine -f --no-hostname
    return
  fi

  # pm2 ?
  if command -v pm2 &>/dev/null && pm2 describe brain-engine &>/dev/null 2>&1; then
    info "source: pm2"
    pm2 logs brain-engine
    return
  fi

  # fichier
  if [[ -f "$LOG_FILE" ]]; then
    info "source: $LOG_FILE"
    tail -f "$LOG_FILE"
  else
    warn "aucun log trouvé"
  fi
}

cmd_install() {
  local target="${1:-}"

  case "$target" in
    pm2)
      cmd_install_pm2
      ;;
    systemd)
      cmd_install_systemd
      ;;
    *)
      echo "Usage : brain-engine install <pm2|systemd>"
      echo ""
      echo "  pm2     — restart on crash (pas au reboot)"
      echo "  systemd — survit au reboot, logs journald"
      exit 1
      ;;
  esac
}

cmd_install_pm2() {
  if ! command -v pm2 &>/dev/null; then
    err "pm2 non trouvé — npm install -g pm2"
    exit 1
  fi

  check_prereqs

  local mode port
  mode=$(detect_mode)
  port=$(detect_port)

  # Générer ecosystem.config.js template-ready
  local eco="$BRAIN_ROOT/ecosystem.config.js"
  cat > "$eco" << JSEOF
// ecosystem.config.js — généré par brain-engine.sh
// Usage : pm2 start ecosystem.config.js

const fs   = require('fs')
const path = require('path')

function loadSecrets() {
  const p = path.join(__dirname, '..', 'BrainSecrets', 'MYSECRETS')
  if (!fs.existsSync(p)) return {}
  return Object.fromEntries(
    fs.readFileSync(p, 'utf8')
      .split('\\n')
      .filter(l => l && !l.startsWith('#') && l.includes('='))
      .map(l => {
        const idx = l.indexOf('=')
        return [l.slice(0, idx).trim(), l.slice(idx + 1).trim()]
      })
  )
}

const secrets = loadSecrets()

module.exports = {
  apps: [
    {
      name: 'brain-engine',
      script: 'brain-engine/server.py',
      interpreter: 'python3',
      cwd: __dirname,
      env: {
        ...secrets,
        BRAIN_MODE: '${mode}',
        BRAIN_PORT: '${port}',
      },
      watch: false,
      autorestart: true,
    },
  ],
}
JSEOF

  # Arrêter l'instance manuelle si elle tourne
  if is_running; then
    info "Arrêt de l'instance manuelle..."
    cmd_stop
  fi

  pm2 start "$eco"
  pm2 save
  ok "brain-engine installé via pm2 (mode: $mode, port: $port)"
  info "pm2 logs brain-engine — pour voir les logs"
  info "pm2 stop brain-engine — pour arrêter"
  info "Prochaine étape : brain-engine install systemd (quand tu es prêt)"
}

cmd_install_systemd() {
  check_prereqs

  local mode port user brain_root
  mode=$(detect_mode)
  port=$(detect_port)
  user=$(whoami)
  brain_root="$BRAIN_ROOT"

  local secrets_path="$brain_root/../BrainSecrets/MYSECRETS"
  local env_file_line=""
  if [[ -f "$secrets_path" ]]; then
    env_file_line="EnvironmentFile=$(realpath "$secrets_path")"
  else
    env_file_line="# EnvironmentFile= (MYSECRETS absent — ajouter le chemin quand disponible)"
  fi

  local service_content
  service_content=$(cat << SVCEOF
# brain-engine.service — généré par brain-engine.sh
# Mode: $mode | Port: $port | User: $user
#
# Commandes :
#   sudo systemctl status brain-engine
#   sudo journalctl -u brain-engine -f
#   brain-engine status

[Unit]
Description=Brain-as-a-Service — brain-engine ($mode)
After=network.target

[Service]
Type=simple
User=$user
WorkingDirectory=$brain_root

$env_file_line

Environment=BRAIN_PORT=$port
Environment=BRAIN_MODE=$mode
Environment=BRAIN_ROOT=$brain_root

ExecStartPre=/bin/sh -c 'fuser -k $port/tcp 2>/dev/null || true'
ExecStart=/usr/bin/python3 $brain_root/brain-engine/server.py

Restart=on-failure
RestartSec=5

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVCEOF
)

  echo "▶ brain-engine install systemd"
  info "mode : $mode"
  info "port : $port"
  info "user : $user"
  echo ""

  # Écrire le service
  local service_file="/etc/systemd/system/brain-engine.service"
  echo "$service_content" | sudo tee "$service_file" > /dev/null

  # Arrêter pm2 ou instance manuelle si en cours
  if is_running; then
    info "Arrêt de l'instance manuelle..."
    cmd_stop
  fi
  if command -v pm2 &>/dev/null && pm2 describe brain-engine &>/dev/null 2>&1; then
    info "Arrêt de l'instance pm2..."
    pm2 stop brain-engine 2>/dev/null || true
    pm2 delete brain-engine 2>/dev/null || true
  fi

  sudo systemctl daemon-reload
  sudo systemctl enable brain-engine
  sudo systemctl restart brain-engine

  sleep 2
  if curl -sf "http://localhost:$port/health" &>/dev/null; then
    ok "brain-engine systemd opérationnel (port $port)"
  else
    warn "/health ne répond pas — vérifier : sudo journalctl -u brain-engine -n 30"
  fi

  # Proposer le cron embed si mode prod
  if [[ "$mode" == "prod" ]]; then
    echo ""
    info "Mode prod détecté — activer le cron embed (toutes les 6h) ?"
    info "  (crontab -l; echo '0 */6 * * * cd $brain_root && python3 brain-engine/embed.py >> brain-engine/embed-cron.log 2>&1') | crontab -"
    info "Copie-colle la commande ci-dessus si tu veux l'activer."
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

cmd="${1:-}"
shift || true

case "$cmd" in
  start)   cmd_start "$@" ;;
  stop)    cmd_stop ;;
  status)  cmd_status ;;
  embed)   cmd_embed ;;
  logs)    cmd_logs ;;
  install) cmd_install "$@" ;;
  *)
    echo "brain-engine — CLI lifecycle"
    echo ""
    echo "Usage : bash scripts/brain-engine.sh <commande>"
    echo ""
    echo "Commandes :"
    echo "  start [--fg]       Démarrer (background par défaut)"
    echo "  stop               Arrêter proprement"
    echo "  status             PID, port, mode, uptime"
    echo "  embed              Embedding one-shot"
    echo "  logs               Tail des logs"
    echo "  install pm2        Installer via pm2"
    echo "  install systemd    Installer via systemd"
    echo ""
    echo "Mode détecté : $(detect_mode)"
    echo "Port détecté : $(detect_port)"
    exit 1
    ;;
esac
