#!/bin/bash
# brain-watch-local.sh — Daemon SUPERVISOR local (desktop)
# Surveille BRAIN-INDEX.md via inotifywait (instant, sans polling)
# Lance en arrière-plan : nohup brain-watch-local.sh >> ~/brain-watch.log 2>&1 &
#
# Détecte :
#   - Nouveau Claim ouvert  → notify update
#   - Claim fermé           → notify info
#   - Nouveau Signal        → notify selon criticité
#   - Condition d'escalade  → notify urgent

set -euo pipefail

BRAIN_ROOT="${BRAIN_ROOT:-$HOME/Dev/Docs}"
BRAIN_INDEX="$BRAIN_ROOT/BRAIN-INDEX.md"
NOTIFY="$BRAIN_ROOT/scripts/brain-notify.sh"
LOG_PREFIX="[brain-watch-local]"

if [[ ! -f "$BRAIN_INDEX" ]]; then
  echo "$LOG_PREFIX ERREUR : BRAIN-INDEX.md introuvable à $BRAIN_INDEX" >&2
  exit 1
fi

if [[ ! -x "$NOTIFY" ]]; then
  chmod +x "$NOTIFY"
fi

echo "$LOG_PREFIX Démarré — surveillance de $BRAIN_INDEX"

# Snapshot initial pour détecter les diffs
snapshot_claims() {
  grep -c '^\|' "$BRAIN_INDEX" 2>/dev/null || echo 0
}

PREV_HASH=$(md5sum "$BRAIN_INDEX" | cut -d' ' -f1)
PREV_CLAIMS=$(grep -v '^\*Aucun claim' "$BRAIN_INDEX" | grep -c '^\| sess-' 2>/dev/null || echo 0)

inotifywait -m -e close_write,moved_to "$BRAIN_INDEX" 2>/dev/null | while read -r _dir _event _file; do

  NEW_HASH=$(md5sum "$BRAIN_INDEX" | cut -d' ' -f1)
  [[ "$NEW_HASH" == "$PREV_HASH" ]] && continue
  PREV_HASH="$NEW_HASH"

  NEW_CLAIMS=$(grep -v '^\*Aucun claim' "$BRAIN_INDEX" | grep -c '^\| sess-' 2>/dev/null || echo 0)

  # Nouveau claim détecté
  if [[ "$NEW_CLAIMS" -gt "$PREV_CLAIMS" ]]; then
    SESS=$(grep '^\| sess-' "$BRAIN_INDEX" | tail -1 | awk -F'|' '{print $2}' | xargs)
    "$NOTIFY" "Nouvelle session détectée\n*Session :* \`$SESS\`\nVérifier les claims actifs dans BRAIN-INDEX.md" "update"
    echo "$LOG_PREFIX Nouveau claim : $SESS"
  fi

  # Claim fermé
  if [[ "$NEW_CLAIMS" -lt "$PREV_CLAIMS" ]]; then
    "$NOTIFY" "Session fermée — claim libéré\nClaims actifs restants : $NEW_CLAIMS" "info"
    echo "$LOG_PREFIX Claim fermé — claims restants : $NEW_CLAIMS"
  fi

  PREV_CLAIMS="$NEW_CLAIMS"

  # Détecter signaux BLOCKED_ON (escalade potentielle)
  if grep -q 'BLOCKED_ON' "$BRAIN_INDEX" 2>/dev/null; then
    BLOCKED=$(grep 'BLOCKED_ON' "$BRAIN_INDEX" | head -1)
    "$NOTIFY" "Conflit détecté entre sessions\n$BLOCKED\nIntervention requise." "urgent"
    echo "$LOG_PREFIX ESCALADE : BLOCKED_ON détecté"
  fi

done
