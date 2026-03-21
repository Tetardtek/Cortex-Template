#!/usr/bin/env bash
# brain-secrets-sync.sh — Registre secrets + sync SSH (ADR-040)
#
# Usage :
#   brain-secrets-sync.sh status           → compare registre vs MYSECRETS local
#   brain-secrets-sync.sh audit            → secrets expirés, rotation due, manquants
#   brain-secrets-sync.sh sync <peer>      → récupère les secrets manquants via SSH
#   brain-secrets-sync.sh diff <peer>      → compare clés locales vs peer (sans valeurs)
#
# Sécurité :
#   - Jamais de valeur affichée — noms de clés uniquement
#   - Transport via SSH (chiffré par construction)
#   - Gate humain obligatoire avant toute sync
#
# Tier free : python3 + pyyaml (pip install pyyaml si absent)

set -euo pipefail

BRAIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECRETS_DIR="$HOME/Dev/BrainSecrets"
REGISTRY="$SECRETS_DIR/secrets.yml"
MYSECRETS="$SECRETS_DIR/MYSECRETS"
COMPOSE_LOCAL="$BRAIN_ROOT/brain-compose.local.yml"
CMD="${1:-help}"
PEER="${2:-}"

# ── Vérifications ────────────────────────────────────────────
if [[ ! -f "$REGISTRY" ]]; then
    echo "❌ Registre absent : $REGISTRY"
    echo "   → Créer avec le format ADR-040 (voir profil/decisions/040-*)"
    exit 1
fi

if [[ ! -f "$MYSECRETS" ]]; then
    echo "❌ MYSECRETS absent : $MYSECRETS"
    exit 1
fi

# ── Commandes ────────────────────────────────────────────────

case "$CMD" in
    status|audit|diff)
        python3 - "$REGISTRY" "$MYSECRETS" "$COMPOSE_LOCAL" "$CMD" "$PEER" <<'PYEOF'
import sys, os
from datetime import datetime, date

registry_path = sys.argv[1]
mysecrets_path = sys.argv[2]
compose_path = sys.argv[3]
cmd = sys.argv[4]
peer = sys.argv[5] if len(sys.argv) > 5 else ""

# Parse YAML sans dépendance lourde (fallback si pyyaml absent)
try:
    import yaml
    with open(registry_path) as f:
        registry = yaml.safe_load(f)
except ImportError:
    # Fallback basique — parse les clés du registre
    print("⚠️  pyyaml absent — install: pip install pyyaml")
    print("   Fallback : comparaison clés MYSECRETS uniquement")
    registry = None

# Parse MYSECRETS (KEY=VALUE)
local_keys = set()
with open(mysecrets_path) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '=' in line:
            key = line.split('=', 1)[0].strip()
            if key:
                local_keys.add(key)

# Détecter la machine courante
machine = "unknown"
if os.path.exists(compose_path):
    try:
        with open(compose_path) as f:
            compose = yaml.safe_load(f) if registry else {}
            machine = compose.get("machine", "unknown")
    except Exception:
        pass

if registry is None:
    sys.exit(0)

secrets = registry.get("secrets", {})

if cmd == "status":
    print(f"📋 Registre : {len(secrets)} secrets | Machine : {machine}")
    print(f"   MYSECRETS : {len(local_keys)} clés locales\n")

    missing = []
    present = []
    other_machine = []
    registry_keys = set(secrets.keys())
    extra = local_keys - registry_keys  # clés locales absentes du registre

    for key, meta in secrets.items():
        machines = meta.get("machines", [])
        required = meta.get("required", False)
        scope = meta.get("scope", "—")

        if machine in machines or machine == "unknown":
            if key in local_keys:
                present.append(key)
            else:
                tag = "🔴 REQUIRED" if required else "⚪ optional"
                missing.append(f"  {tag} {key} (scope: {scope})")
        elif key in local_keys:
            other_machine.append(f"  {key} → déclaré pour {machines}")

    if missing:
        print(f"❌ Manquants ({len(missing)}) :")
        for m in missing:
            print(m)
    else:
        print(f"✅ Tous les secrets requis pour {machine} sont présents")

    if other_machine:
        print(f"\nℹ️  Clés présentes localement mais assignées à d'autres machines ({len(other_machine)}) :")
        for o in other_machine:
            print(o)

    if extra:
        print(f"\n⚠️  Clés dans MYSECRETS absentes du registre ({len(extra)}) :")
        for k in sorted(extra):
            print(f"  ? {k} → ajouter dans secrets.yml")

    print(f"\n✅ {len(present)} clés présentes et déclarées")

elif cmd == "audit":
    today = date.today()
    issues = []

    for key, meta in secrets.items():
        expires = meta.get("expires_at")
        rotated = meta.get("rotated_at")
        required = meta.get("required", False)

        if expires:
            try:
                exp_date = date.fromisoformat(str(expires))
                days_left = (exp_date - today).days
                if days_left < 0:
                    issues.append(f"  🔴 EXPIRÉ : {key} — expiré depuis {-days_left}j")
                elif days_left < 30:
                    issues.append(f"  🟡 EXPIRE BIENTÔT : {key} — {days_left}j restants")
            except ValueError:
                pass

        if rotated:
            try:
                rot_date = date.fromisoformat(str(rotated))
                age = (today - rot_date).days
                if age > 180 and required:
                    issues.append(f"  🟡 ROTATION DUE : {key} — dernière rotation il y a {age}j")
            except ValueError:
                pass

    if issues:
        print(f"🔍 Audit — {len(issues)} problème(s) :\n")
        for i in issues:
            print(i)
    else:
        print("✅ Audit clean — aucun secret expiré ou en attente de rotation")

    # Stats par scope
    scopes = {}
    for key, meta in secrets.items():
        s = meta.get("scope", "unknown")
        scopes[s] = scopes.get(s, 0) + 1
    print(f"\n📊 {len(secrets)} secrets répartis :")
    for s, n in sorted(scopes.items()):
        print(f"  {s}: {n}")

elif cmd == "diff":
    if not peer:
        print("❌ Usage: brain-secrets-sync.sh diff <peer>")
        print("   Ex: brain-secrets-sync.sh diff laptop")
        sys.exit(1)

    print(f"📋 Diff registre : {machine} vs {peer}\n")

    local_expected = set()
    peer_expected = set()

    for key, meta in secrets.items():
        machines = meta.get("machines", [])
        if machine in machines:
            local_expected.add(key)
        if peer in machines:
            peer_expected.add(key)

    both = local_expected & peer_expected
    only_local = local_expected - peer_expected
    only_peer = peer_expected - local_expected

    print(f"  Communs         : {len(both)}")
    print(f"  {machine} only  : {len(only_local)}")
    print(f"  {peer} only     : {len(only_peer)}")

    if only_local:
        print(f"\n  Sur {machine} uniquement :")
        for k in sorted(only_local):
            print(f"    {k}")
    if only_peer:
        print(f"\n  Sur {peer} uniquement :")
        for k in sorted(only_peer):
            print(f"    {k}")

PYEOF
        ;;

    sync)
        if [[ -z "$PEER" ]]; then
            echo "❌ Usage: brain-secrets-sync.sh sync <peer>"
            echo "   Ex: brain-secrets-sync.sh sync desktop"
            echo ""
            echo "   Peers connus (brain-compose.local.yml) :"
            grep -A2 "peers:" "$COMPOSE_LOCAL" 2>/dev/null | grep -E "^\s+\w+:" | sed 's/://;s/^  /     /' || echo "     (aucun peer configuré)"
            exit 1
        fi

        # Résoudre l'IP du peer
        PEER_URL=$(python3 -c "
import yaml, sys
with open('$COMPOSE_LOCAL') as f:
    c = yaml.safe_load(f)
peers = c.get('peers', {})
p = peers.get('$PEER', {})
url = p.get('url', '')
if url:
    # Extraire host de http://ip:port
    host = url.replace('http://','').replace('https://','').split(':')[0]
    print(host)
" 2>/dev/null || echo "")

        if [[ -z "$PEER_URL" ]]; then
            echo "❌ Peer '$PEER' non trouvé dans brain-compose.local.yml"
            echo "   Ajouter sous peers: dans brain-compose.local.yml"
            exit 1
        fi

        echo "🔄 Sync depuis $PEER ($PEER_URL)"
        echo ""
        echo "⚠️  CONFIRMATION REQUISE — cette commande va :"
        echo "   1. Lire les noms de clés sur $PEER via SSH (pas les valeurs)"
        echo "   2. Identifier les clés manquantes localement"
        echo "   3. Copier UNIQUEMENT les clés manquantes via SSH"
        echo ""
        read -p "Continuer ? (oui/non) " confirm
        if [[ "$confirm" != "oui" ]]; then
            echo "Annulé."
            exit 0
        fi

        # Étape 1 : lister les clés sur le peer
        echo ""
        echo "→ Lecture des clés sur $PEER..."
        PEER_KEYS=$(ssh "$PEER_URL" "grep '^[^#].*=' ~/Dev/BrainSecrets/MYSECRETS 2>/dev/null | cut -d= -f1 | sort" 2>/dev/null || echo "")

        if [[ -z "$PEER_KEYS" ]]; then
            echo "❌ Impossible de lire MYSECRETS sur $PEER"
            echo "   Vérifier : ssh $PEER_URL 'test -f ~/Dev/BrainSecrets/MYSECRETS'"
            exit 1
        fi

        # Étape 2 : identifier les manquantes
        LOCAL_KEYS=$(grep "^[^#].*=" "$MYSECRETS" | cut -d= -f1 | sort)
        MISSING=$(comm -23 <(echo "$PEER_KEYS") <(echo "$LOCAL_KEYS"))

        if [[ -z "$MISSING" ]]; then
            echo "✅ Aucune clé manquante — MYSECRETS déjà complet"
            exit 0
        fi

        echo "Clés manquantes localement :"
        echo "$MISSING" | sed 's/^/  /'
        echo ""
        read -p "Copier ces clés depuis $PEER ? (oui/non) " confirm2
        if [[ "$confirm2" != "oui" ]]; then
            echo "Annulé."
            exit 0
        fi

        # Étape 3 : copier les valeurs manquantes via SSH (jamais affichées)
        for key in $MISSING; do
            ssh "$PEER_URL" "grep '^${key}=' ~/Dev/BrainSecrets/MYSECRETS" >> "$MYSECRETS" 2>/dev/null
            echo "  ✅ $key"
        done

        echo ""
        echo "✅ Sync terminée — $(echo "$MISSING" | wc -l) clé(s) ajoutée(s) à MYSECRETS"
        echo "   Les valeurs n'ont jamais été affichées."
        ;;

    help|*)
        echo "brain-secrets-sync.sh — Registre secrets + sync SSH (ADR-040)"
        echo ""
        echo "Usage :"
        echo "  status           → compare registre vs MYSECRETS local"
        echo "  audit            → secrets expirés, rotation due"
        echo "  sync <peer>      → récupère les secrets manquants via SSH"
        echo "  diff <peer>      → compare clés par machine (sans valeurs)"
        echo ""
        echo "Registre : ~/Dev/BrainSecrets/secrets.yml"
        echo "Valeurs  : ~/Dev/BrainSecrets/MYSECRETS"
        ;;
esac
