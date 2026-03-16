#!/bin/bash
# brain-watch-local.sh — Daemon crash handler + supervisor local
# Extension système HORS brain — zéro token, zéro Claude.
#
# Responsabilités :
#   1. Crash detection : process Claude mort → auto-close claim BSI
#   2. Stale TTL check : claim expiré → alerte desktop + Telegram
#   3. Réaction aux changements BRAIN-INDEX.md via inotify (ou poll fallback)
#   4. Notify : notify-send (desktop) + brain-notify.sh (Telegram)
#
# PID tracking — convention helloWorld :
#   Ouverture claim : echo $PPID > ~/.claude/sessions/<sess-id>.pid
#   Fermeture claim : rm -f ~/.claude/sessions/<sess-id>.pid
#
# Install :
#   scripts/install-brain-watch.sh local
#   systemctl --user enable --now brain-watch-local

set -euo pipefail

BRAIN_ROOT="${BRAIN_ROOT:-$HOME/Dev/Brain}"
BRAIN_INDEX="$BRAIN_ROOT/BRAIN-INDEX.md"
BRAIN_NOTIFY="$BRAIN_ROOT/scripts/brain-notify.sh"
BSI_QUERY="$BRAIN_ROOT/scripts/bsi-query.sh"
SESSIONS_DIR="${HOME}/.claude/sessions"
STALE_NOTIFIED_FILE="/tmp/brain-watch-local-stale.txt"
POLL_INTERVAL=30
LOG_PREFIX="[brain-watch-local]"

mkdir -p "$SESSIONS_DIR"
touch "$STALE_NOTIFIED_FILE"

# ── Helpers ───────────────────────────────────────────────────────────────────

log() { echo "$LOG_PREFIX $*"; }

notify_desktop() {
    local msg="$1"
    command -v notify-send &>/dev/null \
        && notify-send "🧠 Brain SUPERVISOR" "$msg" -u normal -t 8000 \
        || true
}

notify_telegram() {
    local msg="$1" level="${2:-info}"
    [[ -x "$BRAIN_NOTIFY" ]] && "$BRAIN_NOTIFY" "$msg" "$level" || true
}

notify_all() {
    notify_desktop "$1"
    notify_telegram "$1" "${2:-info}"
}

# ── Crash detection ───────────────────────────────────────────────────────────

check_crashed_sessions() {
    for pid_file in "$SESSIONS_DIR"/*.pid; do
        [[ -f "$pid_file" ]] || continue

        local sess_id pid claim_line claim_state
        sess_id=$(basename "$pid_file" .pid)
        pid=$(cat "$pid_file" 2>/dev/null | tr -d '[:space:]' || echo "")
        [[ -z "$pid" ]] && continue

        # Process encore vivant → skip
        kill -0 "$pid" 2>/dev/null && continue

        # Process mort — claim encore open ?
        claim_line=$(grep "^| ${sess_id} " "$BRAIN_INDEX" 2>/dev/null | head -1 || true)
        [[ -z "$claim_line" ]] && { rm -f "$pid_file"; continue; }

        claim_state=$(echo "$claim_line" | awk -F'|' '{print $8}' | xargs 2>/dev/null || echo "")

        if [[ "$claim_state" == "open" ]]; then
            log "CRASH : $sess_id (PID $pid mort, claim open) → auto-close"
            notify_all "💥 Session crashée : $sess_id\nClaim auto-fermé par le crash handler." "urgent"
            _auto_close_claim "$sess_id"
        fi

        rm -f "$pid_file"
    done
}

_auto_close_claim() {
    local sess_id="$1"
    # Remplacer | open | par | closed | sur la ligne du claim
    sed -i "s/^| ${sess_id} \(.*\)| open |/| ${sess_id} \1| closed |/" "$BRAIN_INDEX" || {
        log "WARNING : sed failed sur $sess_id"
        return 1
    }
    cd "$BRAIN_ROOT"
    git add BRAIN-INDEX.md \
        && git commit -m "bsi: auto-close crashed claim ${sess_id}" \
        && git push \
        && log "✅ $sess_id fermé + pushé" \
        || log "WARNING : commit/push échoué après auto-close $sess_id"
}

# ── Stale TTL ─────────────────────────────────────────────────────────────────

check_stale_claims() {
    # Source : brain.db via bsi-query.sh — fallback grep BRAIN-INDEX si brain.db absent
    local stale_lines
    if [[ -x "$BSI_QUERY" ]] && bash "$BSI_QUERY" count-stale &>/dev/null; then
        stale_lines=$(bash "$BSI_QUERY" stale 2>/dev/null || true)
    else
        # Fallback : parse BRAIN-INDEX.md (brain.db absent ou bsi-query.sh indisponible)
        stale_lines=$(grep '^| sess-' "$BRAIN_INDEX" 2>/dev/null | grep '| open |' || true)
        [[ -z "$stale_lines" ]] && return
        # Format fallback : convertir ligne markdown en format bsi-query (sess_id | scope | opened_at | age_h)
        stale_lines=$(echo "$stale_lines" | awk -F'|' '{
            gsub(/^ +| +$/,"",$2); gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$6);
            print $2 " | " $4 " | " $6 " | fallback"
        }')
    fi

    [[ -z "$stale_lines" ]] && return

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local sess_id
        sess_id=$(echo "$line" | cut -d'|' -f1 | xargs)
        [[ -z "$sess_id" ]] && continue
        grep -qF "$sess_id" "$STALE_NOTIFIED_FILE" 2>/dev/null && continue

        local age_h
        age_h=$(echo "$line" | cut -d'|' -f4 | xargs)
        log "STALE : $sess_id (${age_h})"
        notify_all "⚠️ Claim stale : $sess_id\n${age_h}\nRecovery requis." "update"
        echo "$sess_id" >> "$STALE_NOTIFIED_FILE"

    done <<< "$stale_lines"
}

# ── BSI events (nouveau claim / fermé / signals) ──────────────────────────────

PREV_HASH=""
PREV_CLAIMS=0

bsi_events() {
    local new_hash new_claims
    new_hash=$(md5sum "$BRAIN_INDEX" | cut -d' ' -f1)
    [[ "$new_hash" == "$PREV_HASH" ]] && return
    PREV_HASH="$new_hash"

    # Source : brain.db via bsi-query.sh — fallback grep BRAIN-INDEX si brain.db absent
    if [[ -x "$BSI_QUERY" ]] && bash "$BSI_QUERY" count-open &>/dev/null; then
        new_claims=$(bash "$BSI_QUERY" count-open 2>/dev/null || echo 0)
    else
        new_claims=$(grep '^| sess-' "$BRAIN_INDEX" 2>/dev/null | grep -c '| open |' || echo 0)
    fi

    if [[ "$new_claims" -gt "$PREV_CLAIMS" ]]; then
        local sess
        if [[ -x "$BSI_QUERY" ]] && bash "$BSI_QUERY" count-open &>/dev/null; then
            sess=$(bash "$BSI_QUERY" open 2>/dev/null | head -1 | cut -d'|' -f1 | xargs)
        else
            sess=$(grep '^| sess-' "$BRAIN_INDEX" | grep '| open |' | tail -1 | awk -F'|' '{print $2}' | xargs)
        fi
        log "Nouveau claim : $sess"
        notify_all "🟢 Nouvelle session : $sess" "update"
    fi

    if [[ "$new_claims" -lt "$PREV_CLAIMS" ]]; then
        log "Claim fermé — restants : $new_claims"
        notify_all "✅ Session fermée — claims actifs : $new_claims" "info"
    fi

    PREV_CLAIMS="$new_claims"

    # BLOCKED_ON — uniquement sur lignes sig-
    local blocked
    blocked=$(grep '^| sig-' "$BRAIN_INDEX" 2>/dev/null | grep 'BLOCKED_ON' | head -1 || true)
    if [[ -n "$blocked" ]]; then
        log "ESCALADE : BLOCKED_ON"
        notify_all "🚨 Conflit inter-sessions\n$blocked\nIntervention requise." "urgent"
    fi

    # CHECKPOINT / HANDOFF pending
    local signal
    signal=$(grep '^| sig-' "$BRAIN_INDEX" 2>/dev/null | grep -E 'CHECKPOINT|HANDOFF' | grep 'pending' | head -1 || true)
    if [[ -n "$signal" ]]; then
        local sig_type sig_to
        sig_type=$(echo "$signal" | awk -F'|' '{print $5}' | xargs)
        sig_to=$(echo "$signal"   | awk -F'|' '{print $4}' | xargs)
        log "SIGNAL : $sig_type → $sig_to"
        notify_all "📋 $sig_type → $sig_to\nHandoff disponible." "update"
    fi
}

# ── Boucle principale ─────────────────────────────────────────────────────────

log "Démarré — BRAIN_INDEX: $BRAIN_INDEX"

PREV_HASH=$(md5sum "$BRAIN_INDEX" 2>/dev/null | cut -d' ' -f1 || echo "")
PREV_CLAIMS=$(grep '^| sess-' "$BRAIN_INDEX" 2>/dev/null | grep -c '| open |' || echo 0)

if command -v inotifywait &>/dev/null; then
    log "Mode inotify — réactif"
    while true; do
        inotifywait -q -t "$POLL_INTERVAL" -e close_write "$BRAIN_INDEX" 2>/dev/null || true
        check_crashed_sessions
        check_stale_claims
        bsi_events
    done
else
    log "Mode poll ${POLL_INTERVAL}s (apt install inotify-tools pour le mode réactif)"
    while true; do
        sleep "$POLL_INTERVAL"
        check_crashed_sessions
        check_stale_claims
        bsi_events
    done
fi
