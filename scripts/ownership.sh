#!/bin/bash
# ownership.sh — Declaration d'ownership
# Transforme le template en brain personnel.
# Les satellites deviennent des repos independants, gitignores du kernel.
#
# Usage : bash scripts/ownership.sh
# Appele automatiquement lors de la premiere session brain boot,
# ou manuellement si prefere.

set -e

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BRAIN_ROOT"

echo ""
echo "========================================="
echo "  Declaration d'ownership"
echo "========================================="
echo ""
echo "  Ce brain va devenir le tien."
echo "  Les satellites et dossiers locaux seront"
echo "  gitignores — ils vivent dans leurs propres repos."
echo ""

# Verification : est-ce qu'on est bien dans un repo git ?
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "❌ Pas dans un repo git. Abandonne."
    exit 1
fi

# Verification : ownership pas deja fait ?
if grep -q "^toolkit/$" "$BRAIN_ROOT/.gitignore" 2>/dev/null; then
    echo "⚠️  Ownership deja declare (.gitignore contient les satellites actifs)."
    echo "   Rien a faire."
    exit 0
fi

# Liste des dossiers a gitignorer
DIRS=(toolkit progression reviews profil todo claims workspace)

# Etape 1 — Activer les lignes dans .gitignore
echo "→ Mise a jour .gitignore..."
sed -i 's|^# toolkit/$|toolkit/|' .gitignore
sed -i 's|^# progression/$|progression/|' .gitignore
sed -i 's|^# reviews/$|reviews/|' .gitignore
sed -i 's|^# profil/$|profil/|' .gitignore
sed -i 's|^# todo/$|todo/|' .gitignore
sed -i 's|^# claims/$|claims/|' .gitignore
sed -i 's|^# workspace/$|workspace/|' .gitignore

# Mettre a jour le commentaire
sed -i 's|^# Satellites — visibles dans le template.*|# Satellites (repos independants — ownership declare)|' .gitignore

echo "✅ .gitignore mis a jour"

# Etape 2 — Retirer du tracking git (sans supprimer les fichiers)
echo "→ Retrait du tracking git..."
for dir in "${DIRS[@]}"; do
    if git ls-files --cached "$dir/" | grep -q .; then
        git rm -r --cached "$dir/" --quiet 2>/dev/null || true
        echo "  ✅ $dir/ retire du tracking"
    else
        echo "  - $dir/ pas tracke (ok)"
    fi
done

# Etape 3 — Commit
echo ""
echo "→ Commit d'ownership..."
git add .gitignore
git commit -m "kernel: ownership declared — satellites gitignored

Les satellites (profil/, toolkit/, todo/, progression/, reviews/)
et les dossiers locaux (claims/, workspace/) sont desormais
gitignores. Ils vivent dans leurs propres repos ou restent locaux.

Ce commit marque la transition template → brain personnel."

echo ""
echo "========================================="
echo "  ✅ Ce brain est le tien."
echo "========================================="
echo ""
echo "  Satellites gitignores : ${DIRS[*]}"
echo "  Premier commit d'ownership pose."
echo ""
echo "  Prochaine etape : brain boot"
echo ""
