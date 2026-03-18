---
name: key-guardian
type: protocol
context_tier: boot
status: active
brain:
  version:   1
  type:      protocol
  scope:     kernel
  owner:     human
  writer:    human
  lifecycle: permanent
  read:      header
  triggers:  [boot-L0]
  export:    true
  ipc:
    receives_from: [human]
    sends_to:      [human]
    zone_access:   [kernel]
    signals:       [ESCALATE, ERROR]
---

# Agent : key-guardian

> Dernière validation : 2026-03-17
> Domaine : Validation Brain API Key — boot silencieux, grace period 72h

---

## Rôle

Valide la `brain_api_key` (brain-compose.local.yml > instances.<name>) au boot et écrit le `feature_set` dans
`brain-compose.local.yml`. N'émet jamais d'erreur visible. N'interrompt jamais le boot.
Tier free = défaut absolu silencieux.

---

## Protocole au boot (invoqué automatiquement après L0)

```
1. Lire brain_api_key dans brain-compose.local.yml → instances.<name>.brain_api_key
   (brain-compose.yml garde toujours null — jamais la vraie clé dans le versionné)
   → null ou absent : tier: free implicite. Stop. Rien à écrire.

2. Clé présente → POST https://keys.<OWNER_DOMAIN>/validate
   Body    : { "key": "<brain_api_key>" }
   Header  : X-Server-Secret: $BRAIN_SERVEUR_SECRET
   Timeout : 3s max — le boot ne doit jamais attendre

3a. Réponse { valid: true } :
    → Écrire dans brain-compose.local.yml > instances.<name>.feature_set :
        tier: <tier>
        agents: <liste selon tier, voir ci-dessous>
        contexts: "*"
        distillation: <true si full, false sinon>
        last_validated_at: <now ISO 8601>
        expires_at: <expires_at du serveur ou null>
        grace_until: null
    → Aucun output visible au boot

3b. Réponse { valid: false } :
    → Écrire feature_set avec tier: free
    → 1 ligne discrète : "[key-guardian] Clé invalide — tier: free"

4. VPS unreachable (timeout, connexion refusée, erreur réseau) :
    → Lire last_validated_at + grace_until depuis brain-compose.local.yml
    → Si last_validated_at absent : aucune grace, tier: free silencieux
    → Si grace_until null : écrire grace_until = last_validated_at + 72h
    → Si now < grace_until : conserver le tier existant (silent)
    → Si now > grace_until : tier: free silencieux
    → Aucune erreur. Aucun blocage.
```

---

## feature_set par tier

```yaml
free:
  tier: free
  agents:
    - coach, scribe, debug, mentor, helloWorld, brainstorm, orchestrator
    - todo-scribe, interprete, aside, recruiter, agent-review
  contexts: "*"
  distillation: false

pro:
  tier: pro
  agents: "*"    # tous les agents fondamentaux + agents calibrés métier
  contexts: "*"
  distillation: false

full:
  tier: full
  agents: "*"
  contexts: "*"
  distillation: true   # brain-engine local autorisé
```

---

## Implémentation bash

Fonctions intégrables dans `brain-setup.sh` ou invocables depuis `helloWorld` :

```bash
_key_guardian() {
  local brain_root
  brain_root=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
  # La clé est dans brain-compose.local.yml (gitignored) — jamais dans brain-compose.yml
  local local_file="$brain_root/brain-compose.local.yml"

  local api_key
  api_key=$(python3 -c "
import yaml, sys
d = yaml.safe_load(open(sys.argv[1]))
instances = d.get('instances', {})
name = next(iter(instances), None)
print((instances.get(name) or {}).get('brain_api_key') or '')
" "$local_file" 2>/dev/null)

  [[ -z "$api_key" ]] && return 0   # pas de clé → free implicite, rien à faire

  local url="https://keys.<OWNER_DOMAIN>/validate"
  local secret="${BRAIN_SERVEUR_SECRET:-}"
  local response

  response=$(curl -sf --max-time 3 -X POST "$url" \
    -H "Content-Type: application/json" \
    -H "X-Server-Secret: $secret" \
    -d "{\"key\":\"$api_key\"}" 2>/dev/null) || {
    _key_guardian_grace "$local_file"
    return 0
  }

  local valid tier expires
  valid=$(echo "$response"  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('valid',''))")
  tier=$(echo "$response"   | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tier','free'))")
  expires=$(echo "$response"| python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('expires_at') or '')")

  if [[ "$valid" == "True" ]]; then
    _key_guardian_write "$local_file" "$tier" "$expires"
  else
    echo "[key-guardian] Clé invalide — tier: free" >&2
    _key_guardian_write "$local_file" "free" ""
  fi
}

_key_guardian_grace() {
  local local_file="$1"
  python3 - "$local_file" <<'PY'
import sys, yaml
from datetime import datetime, timedelta, timezone

path = sys.argv[1]
with open(path) as f:
    data = yaml.safe_load(f) or {}

inst = list((data.get("instances") or {}).values())[0]
fs   = inst.get("feature_set", {})
last = fs.get("last_validated_at")

if not last:
    pass   # jamais validé → pas de grace, reste free
elif not fs.get("grace_until"):
    fs["grace_until"] = (datetime.fromisoformat(str(last)) + timedelta(hours=72)).isoformat()
    with open(path, "w") as f:
        yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
PY
}

_key_guardian_write() {
  local local_file="$1" tier="$2" expires="$3"
  python3 - "$local_file" "$tier" "$expires" <<'PY'
import sys, yaml
from datetime import datetime, timezone

path, tier, expires = sys.argv[1], sys.argv[2], sys.argv[3]

agents_map = {
    "free": ["coach","scribe","debug","mentor","helloWorld","brainstorm",
             "orchestrator","todo-scribe","interprete","aside","recruiter","agent-review"],
    "pro":  "*",
    "full": "*",
}

with open(path) as f:
    data = yaml.safe_load(f) or {}

inst = list((data.get("instances") or {}).values())[0]
inst["feature_set"] = {
    "tier":             tier,
    "agents":           agents_map.get(tier, []),
    "contexts":         "*",
    "distillation":     tier == "full",
    "last_validated_at": datetime.now(timezone.utc).isoformat(),
    "expires_at":       expires or None,
    "grace_until":      None,
}

with open(path, "w") as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
PY
}
```

---

## Règles non-négociables

- Jamais de blocage — le boot continue même si la validation échoue
- Jamais d'exposition de la clé dans les logs (ni `api_key` ni `secret` ne sont loggués)
- Tier free = défaut absolu si aucune clé ou erreur non récupérable
- Grace period : 72h max depuis `last_validated_at` — au-delà → free silencieux
- Output visible au boot : **zéro** (sauf clé invalide → 1 ligne discrète sur stderr)

---

## Composition

| Avec | Pour quoi |
|------|-----------|
| `helloWorld` | Invoqué step 1.5 — résultat (tier actif) transmis au BHP |
| `pre-flight` | Pre-flight utilise le tier validé par key-guardian |
| `feature-gate` | Key-guardian valide la clé → feature-gate applique les restrictions |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-17 | Création — validation Brain API Key au boot, grace period 72h, tier silencieux |
| 2026-03-18 | Composition + Changelog ajoutés — review Batch C |
