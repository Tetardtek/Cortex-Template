#!/usr/bin/env bash
# diagram-init.sh — Génère le fichier .excalidraw initial depuis un workflow.yml
# Usage : bash scripts/diagram-init.sh <workflow-name>
# Exemple : bash scripts/diagram-init.sh superoauth-tier3
# Output  : draw/diagrams/<name>.excalidraw

BRAIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_NAME="${1:-}"

if [[ -z "$WORKFLOW_NAME" ]]; then
  echo "Usage : bash scripts/diagram-init.sh <workflow-name>"
  echo "Exemple : bash scripts/diagram-init.sh superoauth-tier3"
  exit 1
fi

WORKFLOW_FILE="$BRAIN_ROOT/workflows/${WORKFLOW_NAME}.yml"
OUTPUT_DIR="$BRAIN_ROOT/draw/diagrams"
OUTPUT_FILE="$OUTPUT_DIR/${WORKFLOW_NAME}.excalidraw"

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "❌ Workflow introuvable : $WORKFLOW_FILE"
  exit 1
fi

mkdir -p "$OUTPUT_DIR"

python3 - "$WORKFLOW_FILE" "$OUTPUT_FILE" << 'PYEOF'
import sys
import json
import yaml
import uuid
import time

workflow_path = sys.argv[1]
output_path   = sys.argv[2]

with open(workflow_path) as f:
    wf = yaml.safe_load(f)

name  = wf.get("name", "workflow")
chain = wf.get("chain", [])

# Layout constants
NODE_W    = 220
NODE_H    = 90
NODE_GAP  = 60
START_X   = 40
START_Y   = 120
ARROW_Y   = START_Y + NODE_H // 2

# Colors
COLOR_PENDING = "#868e96"   # gris — pending
COLOR_BORDER  = "#343a40"
COLOR_BG_PAGE = "#f8f9fa"

elements = []

def make_id():
    return str(uuid.uuid4())[:8]

# Title
elements.append({
    "id": make_id(),
    "type": "text",
    "x": START_X,
    "y": 40,
    "width": len(name) * 12 + 40,
    "height": 36,
    "text": name,
    "fontSize": 24,
    "fontFamily": 1,
    "textAlign": "left",
    "verticalAlign": "top",
    "strokeColor": COLOR_BORDER,
    "backgroundColor": "transparent",
    "fillStyle": "solid",
    "strokeWidth": 1,
    "roughness": 0,
    "opacity": 100,
    "angle": 0,
    "seed": 1,
    "version": 1,
    "isDeleted": False,
    "groupIds": [],
    "boundElements": [],
    "updated": int(time.time()),
    "link": None,
    "locked": False,
})

node_ids = {}

for i, step in enumerate(chain):
    n     = step.get("step", i + 1)
    stype = step.get("type", "")
    angle = step.get("story_angle", "")
    agents = step.get("agents", [])
    gate  = step.get("gate", None)

    x = START_X + i * (NODE_W + NODE_GAP)
    y = START_Y

    node_id = f"{name}-step-{n}"
    node_ids[n] = {"id": node_id, "x": x, "y": y}

    # Gate badge (above node)
    if gate:
        gate_label = "⚡ gate:human" if gate == "human" else f"⚡ gate:{gate}"
        elements.append({
            "id": make_id(),
            "type": "text",
            "x": x,
            "y": y - 28,
            "width": NODE_W,
            "height": 20,
            "text": gate_label,
            "fontSize": 13,
            "fontFamily": 1,
            "textAlign": "center",
            "verticalAlign": "top",
            "strokeColor": "#f39c12",
            "backgroundColor": "transparent",
            "fillStyle": "solid",
            "strokeWidth": 1,
            "roughness": 0,
            "opacity": 100,
            "angle": 0,
            "seed": i + 100,
            "version": 1,
            "isDeleted": False,
            "groupIds": [],
            "boundElements": [],
            "updated": int(time.time()),
            "link": None,
            "locked": False,
        })

    # Truncate story_angle
    label_angle = (angle[:38] + "…") if len(angle) > 40 else angle
    agents_str  = " · ".join(agents[:3]) if agents else ""
    label_text  = f"step {n} [{stype}]\n{label_angle}\n⬜ pending"

    elements.append({
        "id": node_id,
        "type": "rectangle",
        "x": x,
        "y": y,
        "width": NODE_W,
        "height": NODE_H,
        "backgroundColor": COLOR_PENDING,
        "strokeColor": COLOR_BORDER,
        "fillStyle": "solid",
        "strokeWidth": 2,
        "roughness": 0,
        "opacity": 80,
        "angle": 0,
        "seed": i + 10,
        "version": 1,
        "isDeleted": False,
        "groupIds": [],
        "boundElements": [],
        "updated": int(time.time()),
        "link": None,
        "locked": False,
    })

    # Label inside node
    elements.append({
        "id": make_id(),
        "type": "text",
        "x": x + 10,
        "y": y + 8,
        "width": NODE_W - 20,
        "height": NODE_H - 16,
        "text": label_text,
        "fontSize": 12,
        "fontFamily": 1,
        "textAlign": "left",
        "verticalAlign": "top",
        "strokeColor": "#ffffff",
        "backgroundColor": "transparent",
        "fillStyle": "solid",
        "strokeWidth": 1,
        "roughness": 0,
        "opacity": 100,
        "angle": 0,
        "seed": i + 200,
        "version": 1,
        "isDeleted": False,
        "groupIds": [],
        "boundElements": [],
        "updated": int(time.time()),
        "link": None,
        "locked": False,
    })

    # Agents badge (below node)
    if agents_str:
        elements.append({
            "id": make_id(),
            "type": "text",
            "x": x,
            "y": y + NODE_H + 6,
            "width": NODE_W,
            "height": 18,
            "text": agents_str,
            "fontSize": 11,
            "fontFamily": 1,
            "textAlign": "center",
            "verticalAlign": "top",
            "strokeColor": "#868e96",
            "backgroundColor": "transparent",
            "fillStyle": "solid",
            "strokeWidth": 1,
            "roughness": 0,
            "opacity": 100,
            "angle": 0,
            "seed": i + 300,
            "version": 1,
            "isDeleted": False,
            "groupIds": [],
            "boundElements": [],
            "updated": int(time.time()),
            "link": None,
            "locked": False,
        })

# Arrows between nodes
for i in range(len(chain) - 1):
    n_from = chain[i].get("step", i + 1)
    n_to   = chain[i + 1].get("step", i + 2)

    if n_from not in node_ids or n_to not in node_ids:
        continue

    from_x = node_ids[n_from]["x"] + NODE_W
    to_x   = node_ids[n_to]["x"]
    arr_y  = START_Y + NODE_H // 2

    # Detect type drift (code→deploy or deploy→code)
    type_from = chain[i].get("type", "")
    type_to   = chain[i + 1].get("type", "")
    is_drift  = (type_from != type_to)
    arrow_color = "#e74c3c" if is_drift else "#495057"

    arr_id = make_id()
    elements.append({
        "id": arr_id,
        "type": "arrow",
        "x": from_x,
        "y": arr_y,
        "width": to_x - from_x,
        "height": 0,
        "points": [[0, 0], [to_x - from_x, 0]],
        "strokeColor": arrow_color,
        "backgroundColor": "transparent",
        "fillStyle": "solid",
        "strokeWidth": is_drift and 3 or 2,
        "roughness": 0,
        "opacity": 100,
        "angle": 0,
        "seed": i + 400,
        "version": 1,
        "isDeleted": False,
        "groupIds": [],
        "boundElements": [],
        "updated": int(time.time()),
        "link": None,
        "locked": False,
        "startBinding": None,
        "endBinding": None,
        "lastCommittedPoint": None,
        "startArrowhead": None,
        "endArrowhead": "arrow",
    })

    # Drift label
    if is_drift:
        mid_x = from_x + (to_x - from_x) // 2 - 40
        elements.append({
            "id": make_id(),
            "type": "text",
            "x": mid_x,
            "y": arr_y - 22,
            "width": 100,
            "height": 18,
            "text": f"⚠️ {type_from}→{type_to}",
            "fontSize": 11,
            "fontFamily": 1,
            "textAlign": "center",
            "verticalAlign": "top",
            "strokeColor": "#e74c3c",
            "backgroundColor": "transparent",
            "fillStyle": "solid",
            "strokeWidth": 1,
            "roughness": 0,
            "opacity": 100,
            "angle": 0,
            "seed": i + 500,
            "version": 1,
            "isDeleted": False,
            "groupIds": [],
            "boundElements": [],
            "updated": int(time.time()),
            "link": None,
            "locked": False,
        })

excalidraw = {
    "type": "excalidraw",
    "version": 2,
    "source": "brain/diagram-init.sh",
    "elements": elements,
    "appState": {
        "gridSize": None,
        "viewBackgroundColor": COLOR_BG_PAGE,
    },
    "files": {}
}

with open(output_path, "w") as f:
    json.dump(excalidraw, f, indent=2, ensure_ascii=False)

print(f"✅ {output_path}")
print(f"   {len(chain)} steps — {len(elements)} éléments générés")
PYEOF

STATUS=$?
if [[ $STATUS -eq 0 ]]; then
  echo ""
  echo "→ Ouvrir dans draw.tetardtek.com ou commiter :"
  echo "  git -C $BRAIN_ROOT/draw add diagrams/${WORKFLOW_NAME}.excalidraw"
  echo "  git -C $BRAIN_ROOT/draw commit -m \"diagram: init ${WORKFLOW_NAME}\""
fi
exit $STATUS
