#!/usr/bin/env bash
# bsi-peer-poll.sh — Poll les peers et écrit l'état dans workspace/live-states.md
# Cron : */5 * * * * bash ~/Dev/Brain/scripts/bsi-peer-poll.sh
#
# Écrit un snapshot lisible par time-anchor (session-navigate L1).
# Si rien n'a changé depuis le dernier poll → pas de réécriture (idempotent).
# Si un peer est injoignable → marqué offline, pas d'erreur.

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_LOCAL="$BRAIN_ROOT/brain-compose.local.yml"
LIVE_STATES="$BRAIN_ROOT/workspace/live-states.md"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

mkdir -p "$BRAIN_ROOT/workspace"

# Collecter l'état local + peers
OUTPUT=$(python3 - "$BRAIN_ROOT" "$COMPOSE_LOCAL" "$TIMESTAMP" <<'PYEOF'
import yaml, subprocess, sys, os

brain_root = sys.argv[1]
compose_path = sys.argv[2]
timestamp = sys.argv[3]

# Machine locale
with open(compose_path) as f:
    compose = yaml.safe_load(f)
machine = compose.get("machine", "unknown")

lines = []
lines.append(f"# live-states.md — snapshot {timestamp}")
lines.append(f"# Généré par bsi-peer-poll.sh — ne pas éditer manuellement")
lines.append("")

# Claims locaux
result = subprocess.run(
    ["bash", f"{brain_root}/scripts/bsi-query.sh", "open"],
    capture_output=True, text=True, timeout=5
)
local_claims = result.stdout.strip()

lines.append(f"## {machine} (local)")
if local_claims:
    for line in local_claims.split("\n"):
        parts = line.split(" | ")
        if len(parts) >= 4:
            lines.append(f"- `{parts[0].strip()}` — {parts[1].strip()} — {parts[3].strip()}")
else:
    lines.append("- (idle)")
lines.append("")

# Peers
peers = compose.get("peers", {})
for name, info in peers.items():
    if not info.get("active", False):
        continue
    url = info.get("url", "")
    host = url.replace("http://", "").replace("https://", "").split(":")[0]

    try:
        result = subprocess.run(
            ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=3",
             f"{os.environ.get('SSH_USER', 'tetardtek')}@{host}",
             f"cd {info.get('path', '~/Dev/Brain')} && bash scripts/bsi-query.sh open 2>/dev/null"],
            capture_output=True, text=True, timeout=10
        )
        peer_claims = result.stdout.strip()

        lines.append(f"## {name} ({host})")
        if peer_claims:
            for line in peer_claims.split("\n"):
                parts = line.split(" | ")
                if len(parts) >= 4:
                    lines.append(f"- `{parts[0].strip()}` — {parts[1].strip()} — {parts[3].strip()}")
        else:
            lines.append("- (idle)")
    except (subprocess.TimeoutExpired, Exception):
        lines.append(f"## {name} ({host})")
        lines.append("- (offline)")
    lines.append("")

# Résumé
total_active = 0
if local_claims:
    total_active += len(local_claims.strip().split("\n"))
lines.append(f"---")
lines.append(f"Dernière mise à jour : {timestamp}")
lines.append(f"Sessions actives : {total_active} local + peers")

print("\n".join(lines))
PYEOF
)

# Écrire uniquement si changement (éviter les écritures inutiles)
if [ -f "$LIVE_STATES" ]; then
    # Comparer sans les timestamps (lignes 1-2)
    OLD=$(tail -n +3 "$LIVE_STATES" | grep -v "Dernière mise à jour")
    NEW=$(echo "$OUTPUT" | tail -n +3 | grep -v "Dernière mise à jour")
    if [ "$OLD" = "$NEW" ]; then
        exit 0
    fi
fi

echo "$OUTPUT" > "$LIVE_STATES"
