---
name: brain-ui-scribe
type: agent
context_tier: warm
status: active
brain:
  version:   1
  type:      scribe
  scope:     project
  owner:     human
  writer:    coach
  lifecycle: permanent
  read:      trigger
  triggers:  [brain-ui, dashboard, react-flow, workflow-board, secrets-zone, infra-view, sprint-ui]
  export:    false
  ipc:
    receives_from: [orchestrator, human]
    sends_to:      [orchestrator]
    zone_access:   [project]
    signals:       [SPAWN, RETURN, ESCALATE]
---

# Agent : brain-ui-scribe

> Dernière validation : 2026-03-17
> Domaine : Contexte technique + produit brain-ui — injecté dans tout agent travaillant sur l'interface
> **Type :** Scribe — chargé avant tout agent qui touche brain-ui

---

## boot-summary

Donne le contexte précis de brain-ui à tout agent qui doit travailler dessus.
Sans ce scribe, les agents re-découvrent l'architecture à chaque session.

---

## État actuel (2026-03-18)

### Déploiement
- **URL** : https://brain.tetardtek.com/ui/ (Basic Auth actif)
- **Repo** : git.tetardtek.com:Tetardtek/brain-ui.git
- **VPS** : `$VPS_GITEA_PATH/brain-ui/` → dist/ servi par Apache (voir PATHS.md)
- **Local** : `npm run dev` → localhost:5173

### Stack
- React 18 + Vite + TypeScript + Tailwind
- React Flow (reactflow ^11) — WorkflowBoard
- **Three.js + @react-three/fiber + @react-three/drei** — Cosmos 3D live
- **Zustand ^5** — state management installé
- lucide-react — icônes
- base Vite : `/ui/` (obligatoire — path VPS)

### Composants existants
| Composant | Statut | Notes |
|-----------|--------|-------|
| `WorkflowBoard` | ⚠️ partiel | ReactFlow, gates visuelles, `onGateApprove` = console.log |
| `WorkflowBuilder` | ✅ présent | Builder de workflows |
| `StepNode` | ✅ complet | Losange gate + rect step, couleurs statuts |
| `SecretsZone` | ✅ complet | Eye/EyeOff, génération auto, feedback post-save |
| `GatesDrawer` + `GateDrawer` | ✅ présent | Overlay gate approve/reject |
| `CommandPalette` | ✅ présent | Accès rapide actions |
| `LogDrawer` | ✅ présent | Logs pm2 |
| `InfraRegistry` | ✅ présent | Vue Infra — plus vide |
| `ToastProvider` | ✅ présent | Alertes et notifications |
| `TeamSelector` | ✅ présent | Sélection équipe |
| `TierGate` | ✅ présent | Enforcement tier feature |
| `cosmos/` | ✅ live | CosmosView, CosmosScene, CosmosBackground, CosmosControls, CosmosInfoPanel, CosmosMetrics, CosmosPoints, GateOctahedron, StepSphere, WorkflowConstellation — nébuleuse 3D avec autoRotate |
| `workspace/` | ✅ présent | WorkspaceView, WorkspaceInfoPanel, WorkspaceMetrics |

### Hooks existants
| Hook | Rôle |
|------|------|
| `useWebSocket` | Real-time events workflow — WebSocket natif ✅ |
| `useWorkflows` | Liste workflows + statuts |
| `useCosmosData` | Data pour la vue Cosmos |
| `useInfra` | Statut services infra |
| `useLogs` | Streaming logs pm2 |
| `useTeams` | Sélection équipe |
| `useTier` | Enforcement tier |
| `useWorkspaceData` | Data workspace |

### Ce qui reste à faire
- `onGateApprove` → toujours console.log — pas branché sur API
- Kernel heartbeat → à vérifier si live ou encore statique
- `StatusDot` — indicateur pulsant live → non créé

---

## Architecture cible (Sprint 3+)

### API locale (backend brain)
```
GET  /workflows              → liste workflows + statuts
POST /gate/:wfId/:stepId/approve|reject
GET  /logs/:project          → logs pm2 (polling 2s)
GET  /health                 → statut services (pm2, MySQL, Apache)
```

### Prochaines priorités
1. Brancher `onGateApprove` sur l'API gate réelle
2. `StatusDot` — indicateur pulsant live kernel/services
3. Cosmos heatmap mode nébuleuse → déjà livré ✅

---

## Références design
- Netdata — status indicators pulsants + densité info
- Vercel Dashboard — workflow steps + log viewer inline
- Grafana — command palette + alert banners

---

## Règles pour les agents qui travaillent sur brain-ui

```
- base Vite = '/ui/' — ne jamais changer
- Tailwind uniquement — pas de CSS inline sauf React Flow overrides
- Tokens brain-* dans tailwind.config.js — utiliser ces tokens, pas des hex orphelins
- nodeTypes React Flow défini HORS du composant (référence stable)
- WorkflowBoard doit toujours accepter workflows: Workflow[] en prop
- Jamais de logique métier dans les composants UI — dans les hooks
- VITE_USE_MOCK=true en dev, false en prod
```

---

## Sources à lire pour contexte complet
- `content/brain-ui/product-audit.md` — leviers + monitoring
- `content/brain-ui/design-system.md` — tokens + composants inventaire
- `content/brain-ui/sprint2-specs.md` — API + state + plan migration

---

## Invocation

```
brain-ui-scribe, donne le contexte complet avant de travailler sur brain-ui
brain-ui-scribe, qu'est-ce qui est branché vs mock dans l'UI actuelle ?
brain-ui-scribe, quelles dépendances sont déjà installées ?
```

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-17 | Création — contexte brain-ui injecté avant tout agent UI |
| 2026-03-18 | État mis à jour — Sprint 2 livré (cosmos 3D, WebSocket, GatesDrawer, CommandPalette, InfraRegistry, 8 hooks, zustand) — review audit guidé Batch B |
