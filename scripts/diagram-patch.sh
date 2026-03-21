#!/usr/bin/env bash
# diagram-patch.sh — Patche un nœud dans un .excalidraw après signal BSI
# Usage : bash scripts/diagram-patch.sh <workflow-name> <step> <status>
# Status : done | gate | blocked | locked | circuit-break | abort
# Exemple : bash scripts/diagram-patch.sh superoauth-tier3 1 done

BRAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_NAME="${1:-}"
STEP="${2:-}"
STATUS="${3:-}"

if [[ -z "$WORKFLOW_NAME" || -z "$STEP" || -z "$STATUS" ]]; then
  echo "Usage : bash scripts/diagram-patch.sh <workflow-name> <step> <status>"
  echo ""
  echo "Status disponibles :"
  echo "  done          → ✅ vert  — step terminé"
  echo "  gate          → ⚡ orange — gate:human en attente"
  echo "  blocked       → ❌ rouge  — BLOCKED_ON"
  echo "  locked        → ⬜ gris   — pas encore atteint"
  echo "  circuit-break → 🔴 rouge vif + bordure épaisse"
  echo "  abort         → grisé — workflow aborted"
  exit 1
fi

EXCALIDRAW="$BRAIN_ROOT/draw/diagrams/${WORKFLOW_NAME}.excalidraw"

if [[ ! -f "$EXCALIDRAW" ]]; then
  echo "❌ Fichier introuvable : $EXCALIDRAW"
  echo "   → bash scripts/diagram-init.sh $WORKFLOW_NAME"
  exit 1
fi

python3 - "$EXCALIDRAW" "$WORKFLOW_NAME" "$STEP" "$STATUS" << 'PYEOF'
import sys
import json
import time

excalidraw_path = sys.argv[1]
workflow_name   = sys.argv[2]
step            = sys.argv[3]
status          = sys.argv[4]

# Color + label mapping
STATUS_MAP = {
    "done":          {"color": "#2ecc71", "label": "✅ done",         "stroke": "#1a9e57", "width": 2},
    "gate":          {"color": "#f39c12", "label": "⚡ gate:human",   "stroke": "#c87f0a", "width": 2},
    "blocked":       {"color": "#e74c3c", "label": "❌ blocked",      "stroke": "#c0392b", "width": 2},
    "locked":        {"color": "#868e96", "label": "⬜ pending",      "stroke": "#343a40", "width": 2},
    "circuit-break": {"color": "#c0392b", "label": "🔴 circuit break","stroke": "#922b21", "width": 4},
    "abort":         {"color": "#adb5bd", "label": "aborted",         "stroke": "#6c757d", "width": 1},
}

if status not in STATUS_MAP:
    print(f"❌ Status inconnu : {status}")
    print(f"   Valeurs valides : {', '.join(STATUS_MAP.keys())}")
    sys.exit(1)

cfg      = STATUS_MAP[status]
node_id  = f"{workflow_name}-step-{step}"

with open(excalidraw_path) as f:
    data = json.load(f)

patched  = False
elements = data.get("elements", [])

for el in elements:
    if el.get("id") == node_id and el.get("type") == "rectangle":
        el["backgroundColor"] = cfg["color"]
        el["strokeColor"]     = cfg["stroke"]
        el["strokeWidth"]     = cfg["width"]
        el["updated"]         = int(time.time())
        patched = True
        break

if not patched:
    print(f"⚠️  Nœud introuvable : {node_id}")
    print(f"   → Vérifier que diagram-init.sh a bien été lancé pour ce workflow")
    sys.exit(1)

# Update label text for the matching text element (right after the rectangle)
target_x = None
target_y = None
for el in elements:
    if el.get("id") == node_id:
        target_x = el["x"]
        target_y = el["y"]
        break

if target_x is not None:
    for el in elements:
        if (el.get("type") == "text"
                and abs(el.get("x", 0) - target_x - 10) < 5
                and abs(el.get("y", 0) - target_y - 8) < 5):
            # Replace last line (status line) in the text
            lines = el.get("text", "").split("\n")
            if len(lines) >= 3:
                lines[-1] = cfg["label"]
            elif len(lines) > 0:
                lines.append(cfg["label"])
            el["text"]    = "\n".join(lines)
            el["updated"] = int(time.time())
            break

data["elements"] = elements

with open(excalidraw_path, "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"✅ {workflow_name} step {step} → {cfg['label']}")
PYEOF

PATCH_STATUS=$?
if [[ $PATCH_STATUS -eq 0 ]]; then
  echo "→ Commiter le patch :"
  echo "  git -C $BRAIN_ROOT/draw add diagrams/${WORKFLOW_NAME}.excalidraw"
  echo "  git -C $BRAIN_ROOT/draw commit -m \"diagram: ${WORKFLOW_NAME} step ${STEP} → ${STATUS}\""
fi
exit $PATCH_STATUS
