#!/usr/bin/env bash
# brain-conciergerie.sh — Chirurgie de la donnée cognitive
#
# Usage :
#   brain-conciergerie.sh status     → diagnostic complet par tier
#   brain-conciergerie.sh clean      → tier 3 (locks, circuit_breaker)
#   brain-conciergerie.sh archive    → tier 2 (claims, sessions, signals, handoffs)
#   brain-conciergerie.sh audit      → cohérence embeddings (orphelins, stale, cold)
#
# Chaque opération write = un commit Dolt avec message explicite.
# Archive ≠ supprime. Dolt = filet de sécurité (diff + rollback).

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOLT_DIR="$BRAIN_ROOT/brain-dolt"
CMD="${1:-status}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

dolt_q() {
  dolt sql -q "$1" -r csv 2>/dev/null
}

dolt_val() {
  dolt sql -q "$1" -r csv 2>/dev/null | tail -1
}

dolt_exec() {
  dolt sql -q "$1" 2>/dev/null
}

dolt_commit_if_dirty() {
  local msg="$1"
  dolt add . 2>/dev/null
  if dolt commit -m "$msg" 2>/dev/null; then
    echo -e "${GREEN}✅ Dolt commit : $msg${NC}"
  fi
}

# ── STATUS ──────────────────────────────────────────────────────────────────

cmd_status() {
  echo -e "${CYAN}🏥 Conciergerie Brain — Diagnostic${NC}"
  echo ""

  # Tier 1 — Intouchable
  echo -e "${CYAN}━━━ Tier 1 — Intouchable (kernel) ━━━${NC}"
  local kernel_emb=$(dolt_val "SELECT COUNT(*) FROM embeddings WHERE scope = 'kernel'")
  local permanent=$(dolt_val "SELECT COUNT(*) FROM embeddings WHERE permanent = 1")
  echo "  Embeddings kernel  : $kernel_emb chunks (protégés)"
  echo "  Embeddings permanent: $permanent chunks (protégés)"
  echo ""

  # Tier 2 — Archive candidates
  echo -e "${YELLOW}━━━ Tier 2 — Candidats archive ━━━${NC}"

  local claims_old=$(dolt_val "SELECT COUNT(*) FROM claims WHERE status = 'closed' AND opened_at < DATE_SUB(NOW(), INTERVAL 30 DAY)")
  local claims_recent=$(dolt_val "SELECT COUNT(*) FROM claims WHERE status = 'closed' AND opened_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)")
  local claims_open=$(dolt_val "SELECT COUNT(*) FROM claims WHERE status = 'open'")
  echo "  Claims    : ${claims_old} archivables (>30j) | ${claims_recent} récents | ${claims_open} open"

  local sessions_old=$(dolt_val "SELECT COUNT(*) FROM sessions WHERE date < DATE_SUB(NOW(), INTERVAL 30 DAY)")
  local sessions_recent=$(dolt_val "SELECT COUNT(*) FROM sessions WHERE date >= DATE_SUB(NOW(), INTERVAL 30 DAY)")
  echo "  Sessions  : ${sessions_old} archivables (>30j) | ${sessions_recent} récentes"

  local signals_old=$(dolt_val "SELECT COUNT(*) FROM signals WHERE state = 'delivered' AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)")
  local signals_pending=$(dolt_val "SELECT COUNT(*) FROM signals WHERE state = 'pending'")
  echo "  Signals   : ${signals_old} archivables (delivered >7j) | ${signals_pending} pending"

  local handoffs_old=$(dolt_val "SELECT COUNT(*) FROM handoffs WHERE status = 'consumed' AND consumed_at < DATE_SUB(NOW(), INTERVAL 7 DAY)")
  local handoffs_active=$(dolt_val "SELECT COUNT(*) FROM handoffs WHERE status = 'active'")
  echo "  Handoffs  : ${handoffs_old} archivables (consumed >7j) | ${handoffs_active} actifs"
  echo ""

  # Tier 3 — Nettoyage immédiat
  echo -e "${RED}━━━ Tier 3 — Nettoyage immédiat ━━━${NC}"
  local locks_expired=$(dolt_val "SELECT COUNT(*) FROM locks WHERE NOW() > expires_at")
  local locks_active=$(dolt_val "SELECT COUNT(*) FROM locks WHERE NOW() <= expires_at")
  echo "  Locks     : ${locks_expired} expirés (à supprimer) | ${locks_active} actifs"

  local cb_empty=$(dolt_val "SELECT COUNT(*) FROM circuit_breaker WHERE fail_count = 0")
  echo "  Circuit B.: ${cb_empty} vides (à supprimer)"
  echo ""

  # Tier 4 — Embeddings santé
  echo -e "${CYAN}━━━ Tier 4 — Santé embeddings ━━━${NC}"
  local total_emb=$(dolt_val "SELECT COUNT(*) FROM embeddings")
  local indexed=$(dolt_val "SELECT COUNT(*) FROM embeddings WHERE \`indexed\` = 1")
  local no_vec=$(dolt_val "SELECT COUNT(*) FROM embeddings WHERE \`vector\` IS NULL")
  local historical=$(dolt_val "SELECT COUNT(*) FROM embeddings WHERE scope = 'historical'")
  echo "  Total       : $total_emb chunks ($indexed indexés)"
  echo "  Sans vecteur: $no_vec"
  echo "  Historical  : $historical (shadow indexed)"
  echo ""

  # Archives existantes
  echo -e "${CYAN}━━━ Archives ━━━${NC}"
  local arc_claims=$(dolt_val "SELECT COUNT(*) FROM claims_archive")
  local arc_sessions=$(dolt_val "SELECT COUNT(*) FROM sessions_archive")
  local arc_signals=$(dolt_val "SELECT COUNT(*) FROM signals_archive")
  local arc_handoffs=$(dolt_val "SELECT COUNT(*) FROM handoffs_archive")
  echo "  claims_archive   : $arc_claims"
  echo "  sessions_archive : $arc_sessions"
  echo "  signals_archive  : $arc_signals"
  echo "  handoffs_archive : $arc_handoffs"
}

# ── CLEAN (tier 3) ──────────────────────────────────────────────────────────

cmd_clean() {
  echo -e "${RED}🧹 Tier 3 — Nettoyage immédiat${NC}"
  echo ""

  local locks_n=$(dolt_val "SELECT COUNT(*) FROM locks WHERE NOW() > expires_at")
  local cb_n=$(dolt_val "SELECT COUNT(*) FROM circuit_breaker WHERE fail_count = 0")

  if [ "$locks_n" = "0" ] && [ "$cb_n" = "0" ]; then
    echo -e "${GREEN}✅ Rien à nettoyer${NC}"
    return
  fi

  if [ "$locks_n" != "0" ]; then
    echo "  Locks expirés à supprimer : $locks_n"
    dolt_exec "SELECT filepath, holder, expires_at FROM locks WHERE NOW() > expires_at"
  fi

  if [ "$cb_n" != "0" ]; then
    echo "  Circuit breakers vides à supprimer : $cb_n"
  fi

  echo ""
  read -p "Confirmer le nettoyage ? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    return
  fi

  [ "$locks_n" != "0" ] && dolt_exec "DELETE FROM locks WHERE NOW() > expires_at"
  [ "$cb_n" != "0" ] && dolt_exec "DELETE FROM circuit_breaker WHERE fail_count = 0"

  dolt_commit_if_dirty "conciergerie: clean tier 3 — ${locks_n} locks, ${cb_n} circuit_breakers"
  echo -e "${GREEN}✅ Nettoyage terminé${NC}"
}

# ── ARCHIVE (tier 2) ────────────────────────────────────────────────────────

cmd_archive() {
  echo -e "${YELLOW}📦 Tier 2 — Archivage${NC}"
  echo ""

  # Claims
  local claims_n=$(dolt_val "SELECT COUNT(*) FROM claims WHERE status = 'closed' AND opened_at < DATE_SUB(NOW(), INTERVAL 30 DAY)")
  echo "  Claims à archiver : $claims_n"

  # Sessions
  local sessions_n=$(dolt_val "SELECT COUNT(*) FROM sessions WHERE date < DATE_SUB(NOW(), INTERVAL 30 DAY)")
  echo "  Sessions à archiver : $sessions_n"

  # Signals
  local signals_n=$(dolt_val "SELECT COUNT(*) FROM signals WHERE state = 'delivered' AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)")
  echo "  Signals à archiver : $signals_n"

  # Handoffs
  local handoffs_n=$(dolt_val "SELECT COUNT(*) FROM handoffs WHERE status = 'consumed' AND consumed_at < DATE_SUB(NOW(), INTERVAL 7 DAY)")
  echo "  Handoffs à archiver : $handoffs_n"

  local total=$((claims_n + sessions_n + signals_n + handoffs_n))
  if [ "$total" = "0" ]; then
    echo ""
    echo -e "${GREEN}✅ Rien à archiver${NC}"
    return
  fi

  echo ""
  read -p "Archiver $total entrées ? (y/N) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Annulé."
    return
  fi

  if [ "$claims_n" != "0" ]; then
    dolt_exec "INSERT INTO claims_archive SELECT *, NOW() as archived_at FROM claims WHERE status = 'closed' AND opened_at < DATE_SUB(NOW(), INTERVAL 30 DAY)"
    dolt_exec "DELETE FROM claims WHERE status = 'closed' AND opened_at < DATE_SUB(NOW(), INTERVAL 30 DAY)"
    echo "  ✅ $claims_n claims archivés"
  fi

  if [ "$sessions_n" != "0" ]; then
    dolt_exec "INSERT INTO sessions_archive SELECT *, NOW() as archived_at FROM sessions WHERE date < DATE_SUB(NOW(), INTERVAL 30 DAY)"
    dolt_exec "DELETE FROM sessions WHERE date < DATE_SUB(NOW(), INTERVAL 30 DAY)"
    echo "  ✅ $sessions_n sessions archivées"
  fi

  if [ "$signals_n" != "0" ]; then
    dolt_exec "INSERT INTO signals_archive SELECT *, NOW() as archived_at FROM signals WHERE state = 'delivered' AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)"
    dolt_exec "DELETE FROM signals WHERE state = 'delivered' AND created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)"
    echo "  ✅ $signals_n signals archivés"
  fi

  if [ "$handoffs_n" != "0" ]; then
    dolt_exec "INSERT INTO handoffs_archive SELECT *, NOW() as archived_at FROM handoffs WHERE status = 'consumed' AND consumed_at < DATE_SUB(NOW(), INTERVAL 7 DAY)"
    dolt_exec "DELETE FROM handoffs WHERE status = 'consumed' AND consumed_at < DATE_SUB(NOW(), INTERVAL 7 DAY)"
    echo "  ✅ $handoffs_n handoffs archivés"
  fi

  dolt_commit_if_dirty "conciergerie: archive tier 2 — ${claims_n}c ${sessions_n}s ${signals_n}sig ${handoffs_n}h"
  echo ""
  echo -e "${GREEN}✅ Archivage terminé — $total entrées déplacées${NC}"
}

# ── AUDIT (tier 4 — embeddings) ────────────────────────────────────────────

cmd_audit() {
  echo -e "${CYAN}🔬 Tier 4 — Audit embeddings${NC}"
  echo ""

  # Orphelins (fichier source supprimé)
  python3 - "$DOLT_DIR" "$BRAIN_ROOT" <<'PYEOF'
import subprocess, csv, io, os, sys

dolt_dir = sys.argv[1]
brain_root = sys.argv[2]

result = subprocess.run(
    ["dolt", "sql", "-q", "SELECT DISTINCT filepath FROM embeddings", "-r", "csv"],
    cwd=dolt_dir, capture_output=True, text=True
)
reader = csv.DictReader(io.StringIO(result.stdout))
orphans = []
for row in reader:
    fp = os.path.join(brain_root, row['filepath'])
    if not os.path.exists(fp):
        orphans.append(row['filepath'])

if orphans:
    print(f"  ☠️  Fichiers orphelins : {len(orphans)}")
    for o in sorted(orphans)[:10]:
        print(f"      {o}")
    if len(orphans) > 10:
        print(f"      ... et {len(orphans) - 10} autres")
else:
    print("  ✅ Zéro fichier orphelin")

# Cold chunks (hit_count=0, >60j, non permanent)
result2 = subprocess.run(
    ["dolt", "sql", "-q",
     "SELECT COUNT(*) as n FROM embeddings WHERE hit_count = 0 AND permanent = 0 "
     "AND created_at < DATE_SUB(NOW(), INTERVAL 60 DAY)",
     "-r", "csv"],
    cwd=dolt_dir, capture_output=True, text=True
)
rows = list(csv.DictReader(io.StringIO(result2.stdout)))
cold_n = int(rows[0]['n']) if rows else 0
if cold_n > 0:
    print(f"  🥶 Chunks cold (0 hits, >60j, non permanent) : {cold_n} — candidats revue")
else:
    print("  ✅ Zéro chunk cold")

# Sans vecteur
result3 = subprocess.run(
    ["dolt", "sql", "-q",
     "SELECT COUNT(*) as n FROM embeddings WHERE `vector` IS NULL",
     "-r", "csv"],
    cwd=dolt_dir, capture_output=True, text=True
)
rows3 = list(csv.DictReader(io.StringIO(result3.stdout)))
no_vec = int(rows3[0]['n']) if rows3 else 0
if no_vec > 0:
    print(f"  ⚠️  Chunks sans vecteur : {no_vec} — relancer embed.py")
else:
    print("  ✅ Tous les chunks ont un vecteur")
PYEOF
}

# ── DISPATCH ────────────────────────────────────────────────────────────────

case "$CMD" in
  status)  cmd_status ;;
  clean)   cmd_clean ;;
  archive) cmd_archive ;;
  audit)   cmd_audit ;;
  *)
    echo "Usage: brain-conciergerie.sh <status|clean|archive|audit>"
    echo "  status  — diagnostic complet par tier"
    echo "  clean   — tier 3 (locks, circuit_breaker)"
    echo "  archive — tier 2 (claims, sessions, signals, handoffs)"
    echo "  audit   — tier 4 (santé embeddings)"
    exit 1
    ;;
esac
