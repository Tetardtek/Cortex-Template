#!/bin/bash
# kernel-isolation-check.sh — Firewall toolkit/private
# Vérifie qu'aucun agent kernel ne contient de dépendances dures vers des fichiers privés.
#
# WARN  : référence documentaire (normal — l'agent décrit l'architecture)
# ERROR : dépendance dure (problème — l'agent ne peut pas fonctionner sans le fichier privé)
#
# Usage : bash scripts/kernel-isolation-check.sh [--strict]
#   --strict : traite les WARN comme des ERROR

set -euo pipefail

BRAIN_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
AGENTS_DIR="$BRAIN_ROOT/agents"
STRICT=${1:-""}

ERRORS=()
WARNS=()

# --- Patterns ERROR : dépendances dures — jamais dans un agent distributable ---
# Chemin absolu machine, requires:, load:, source: vers privé
ERROR_PATTERNS=(
  "toolkit/private/"
  "require.*toolkit/private"
  "load.*MYSECRETS"
  "source.*MYSECRETS"
)

# Patterns de chemin absolu — exclusions pour les placeholders templates
ABSOLUTE_PATH_PATTERN="/home/[a-z]"   # /home/tetardtek — chemin réel, pas /home/<user>
ABSOLUTE_PATH_EXCLUDE="<"             # Exclure les lignes avec placeholder (<user>, <PATHS...)

# --- Patterns WARN : références documentaires — OK si contexte architecture ---
# L'agent mentionne le concept mais n'en dépend pas fonctionnellement
WARN_PATTERNS=(
  "MYSECRETS"
  "brain-compose.local"
  "profil/capital"
  "profil/objectifs"
  "progression/"
)

echo "🔍 Kernel isolation check — agents/ → dépendances privées"
echo ""

# --- Scan ERROR — patterns interdits ---
for pattern in "${ERROR_PATTERNS[@]}"; do
  matches=$(grep -rl "$pattern" "$AGENTS_DIR" \
    --include="*.md" \
    --exclude-dir=reviews \
    2>/dev/null || true)

  if [ -n "$matches" ]; then
    while IFS= read -r file; do
      rel="${file#$BRAIN_ROOT/}"
      line=$(grep -n "$pattern" "$file" | head -1 | cut -d: -f1)
      ERRORS+=("  🚨 ERROR $rel:$line → dépendance dure \"$pattern\"")
    done <<< "$matches"
  fi
done

# --- Scan ERROR — chemins absolus réels (ex: /home/tetardtek/, pas /home/<user>/) ---
while IFS= read -r -d '' file; do
  # Cherche /home/[a-z] et exclut les lignes avec placeholder <
  matches=$(grep -n "$ABSOLUTE_PATH_PATTERN" "$file" 2>/dev/null \
    | grep -v "$ABSOLUTE_PATH_EXCLUDE" || true)
  if [ -n "$matches" ]; then
    rel="${file#$BRAIN_ROOT/}"
    line=$(echo "$matches" | head -1 | cut -d: -f1)
    ERRORS+=("  🚨 ERROR $rel:$line → chemin machine absolu hardcodé")
  fi
done < <(find "$AGENTS_DIR" -name "*.md" \
  -not -path "*/reviews/*" \
  -not -path "*/_template*" \
  | tr '\n' '\0')

# --- Scan WARN ---
for pattern in "${WARN_PATTERNS[@]}"; do
  matches=$(grep -rl "$pattern" "$AGENTS_DIR" \
    --include="*.md" \
    --exclude-dir=reviews \
    2>/dev/null || true)

  if [ -n "$matches" ]; then
    while IFS= read -r file; do
      rel="${file#$BRAIN_ROOT/}"
      line=$(grep -n "$pattern" "$file" | head -1 | cut -d: -f1)
      WARNS+=("  ⚠️  WARN  $rel:$line → référence doc \"$pattern\"")
    done <<< "$matches"
  fi
done

# --- Rapport ---
if [ ${#ERRORS[@]} -gt 0 ]; then
  echo "🚨 ERREURS — dépendances dures détectées (kernel NON distribuable) :"
  echo ""
  for e in "${ERRORS[@]}"; do echo "$e"; done
  echo ""
fi

if [ ${#WARNS[@]} -gt 0 ]; then
  echo "⚠️  AVERTISSEMENTS — références documentaires (attendu, pas bloquant) :"
  echo ""
  for w in "${WARNS[@]}"; do echo "$w"; done
  echo ""
  echo "   ℹ️  Ces références décrivent l'architecture brain — elles n'empêchent pas la distribution."
  echo "   Un utilisateur qui forke aura ses propres fichiers à ces chemins."
  echo ""
fi

# --- Résultat ---
if [ ${#ERRORS[@]} -eq 0 ] && [ "$STRICT" != "--strict" ]; then
  echo "✅ Kernel isolation OK — aucune dépendance dure privée détectée"
  echo "   ${#WARNS[@]} références documentaires (normales)"
  exit 0
elif [ ${#ERRORS[@]} -eq 0 ] && [ "$STRICT" = "--strict" ] && [ ${#WARNS[@]} -eq 0 ]; then
  echo "✅ Kernel isolation OK (strict) — zéro violation"
  exit 0
elif [ "$STRICT" = "--strict" ] && [ ${#WARNS[@]} -gt 0 ]; then
  echo "🚨 Mode strict — ${#WARNS[@]} WARN traités comme ERROR"
  exit 1
else
  echo "🚨 ${#ERRORS[@]} erreur(s) bloquante(s) — corriger avant distribution"
  exit 1
fi
