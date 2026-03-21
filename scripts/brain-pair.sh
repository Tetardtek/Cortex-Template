#!/usr/bin/env bash
# brain-pair.sh — Pairing multi-machine type Bluetooth (ADR-041)
#
# Usage :
#   brain-pair.sh start              → génère code, écoute sur le LAN
#   brain-pair.sh join <code>        → scan LAN, envoie code, reçoit config
#   brain-pair.sh list               → machines pairées (peers dans brain-compose.local.yml)
#   brain-pair.sh revoke <machine>   → supprime une machine
#
# Sécurité : code 6 chiffres valide 60s, LAN only, MYSECRETS jamais échangé
# Tier free : python3 stdlib uniquement

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CMD="${1:-help}"
shift || true

case "$CMD" in
    start)
        python3 "$BRAIN_ROOT/scripts/brain-pair-server.py" "$BRAIN_ROOT"
        ;;
    join)
        CODE="${1:-}"
        if [[ -z "$CODE" ]]; then
            echo "❌ Usage: brain-pair.sh join <code>"
            exit 1
        fi
        python3 "$BRAIN_ROOT/scripts/brain-pair-client.py" "$BRAIN_ROOT" "$CODE"
        ;;
    list)
        python3 -c "
import yaml, sys
compose_path = '$BRAIN_ROOT/brain-compose.local.yml'
try:
    with open(compose_path) as f:
        c = yaml.safe_load(f)
    peers = c.get('peers', {})
    machine = c.get('machine', 'unknown')
    print(f'Machine locale : {machine}')
    print(f'Peers configurés : {len(peers)}\n')
    for name, info in peers.items():
        status = '✅ active' if info.get('active') else '⬜ inactive'
        url = info.get('url', '—')
        print(f'  {name} — {url} — {status}')
    if not peers:
        print('  (aucun peer)')
except FileNotFoundError:
    print('❌ brain-compose.local.yml absent')
"
        ;;
    revoke)
        MACHINE="${1:-}"
        if [[ -z "$MACHINE" ]]; then
            echo "❌ Usage: brain-pair.sh revoke <machine>"
            exit 1
        fi
        python3 - "$BRAIN_ROOT" "$MACHINE" <<'PYEOF'
import yaml, sys, os, subprocess

brain_root = sys.argv[1]
machine = sys.argv[2]
compose_path = os.path.join(brain_root, "brain-compose.local.yml")

with open(compose_path) as f:
    compose = yaml.safe_load(f)

peers = compose.get("peers", {})
if machine not in peers:
    print(f"⚠️  Peer '{machine}' non trouvé")
    sys.exit(1)

peer_url = peers[machine].get("url", "")
host = peer_url.replace("http://", "").replace("https://", "").split(":")[0]

# Retirer du compose
del peers[machine]
compose["peers"] = peers
with open(compose_path, "w") as f:
    yaml.dump(compose, f, default_flow_style=False, allow_unicode=True)

# Retirer de authorized_keys (lignes contenant le nom de machine)
ak_path = os.path.expanduser("~/.ssh/authorized_keys")
if os.path.exists(ak_path):
    with open(ak_path) as f:
        lines = f.readlines()
    filtered = [l for l in lines if machine not in l]
    if len(filtered) < len(lines):
        with open(ak_path, "w") as f:
            f.writelines(filtered)
        print(f"✅ Clé SSH de {machine} retirée de authorized_keys")

print(f"✅ Peer '{machine}' révoqué de brain-compose.local.yml")
PYEOF
        ;;
    help|*)
        echo "brain-pair.sh — Pairing multi-machine (ADR-041)"
        echo ""
        echo "Usage :"
        echo "  start              → génère code 6 chiffres, écoute sur le LAN (60s)"
        echo "  join <code>        → scan LAN, envoie code, reçoit config"
        echo "  list               → machines pairées"
        echo "  revoke <machine>   → supprime un peer"
        ;;
esac
