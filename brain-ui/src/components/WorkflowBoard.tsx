import 'reactflow/dist/style.css'
import ReactFlow, {
  ReactFlowProvider,
  Node,
  Edge,
  Background,
  BackgroundVariant,
  Controls,
  MiniMap,
  useNodesState,
  useEdgesState,
} from 'reactflow'
import { useMemo } from 'react'
import type { Workflow } from '../types'
import StepNode, { StepNodeData } from './StepNode'

// ─── Mock data ───────────────────────────────────────────────────────────────

export const MOCK_WORKFLOWS: Workflow[] = [
  {
    id: 'clk',
    name: 'Clickerz Sprint 2',
    project: 'clickerz',
    steps: [
      { id: 'init', label: 'INIT', status: 'done' },
      { id: 's1', label: 'UI Components', status: 'in-progress' },
      { id: 's2', label: 'Tests', status: 'pending' },
      { id: 'deploy', label: 'Deploy', status: 'pending', isGate: true },
    ],
  },
  {
    id: 'od',
    name: 'OriginsDigital Sprint 4',
    project: 'originsdigital',
    steps: [
      { id: 'init', label: 'INIT', status: 'done' },
      { id: 's1', label: 'SuperOAuth SDK', status: 'gate', isGate: true },
      { id: 's2', label: 'Auth Flow', status: 'blocked' },
      { id: 'deploy', label: 'Deploy', status: 'blocked', isGate: true },
    ],
  },
]

// ─── Layout constants ─────────────────────────────────────────────────────────

const COL_WIDTH = 220       // horizontal spacing between workflow columns
const ROW_HEIGHT = 110      // vertical spacing between steps
const COL_OFFSET_X = 80     // left margin
const ROW_OFFSET_Y = 60     // top margin
const GATE_NODE_SIZE = 68   // diamond bounding box — must match StepNode size

// ─── Node type registry ───────────────────────────────────────────────────────

const nodeTypes = { stepNode: StepNode }

// ─── Builder helpers ──────────────────────────────────────────────────────────

function buildNodesAndEdges(
  workflows: Workflow[],
  onGateApprove: (wfId: string, stepId: string) => void
): { nodes: Node[]; edges: Edge[] } {
  const nodes: Node[] = []
  const edges: Edge[] = []

  workflows.forEach((wf, colIdx) => {
    if (!wf.steps?.length) return
    const x = COL_OFFSET_X + colIdx * COL_WIDTH

    wf.steps.forEach((step, rowIdx) => {
      const y = ROW_OFFSET_Y + rowIdx * ROW_HEIGHT
      const nodeId = `${wf.id}__${step.id}`

      const data: StepNodeData = {
        label: step.label,
        status: step.status,
        isGate: step.isGate,
        workflowId: wf.id,
        stepId: step.id,
        onGateApprove,
      }

      nodes.push({
        id: nodeId,
        type: 'stepNode',
        position: { x, y },
        data,
        // Gate nodes are diamond — center them the same as rect nodes
        style: step.isGate
          ? { width: GATE_NODE_SIZE, height: GATE_NODE_SIZE }
          : undefined,
      })

      // Edge from previous step to this one
      if (rowIdx > 0) {
        const prevNodeId = `${wf.id}__${wf.steps[rowIdx - 1].id}`
        edges.push({
          id: `e_${prevNodeId}_${nodeId}`,
          source: prevNodeId,
          target: nodeId,
          animated: wf.steps[rowIdx - 1].status === 'in-progress',
          style: { stroke: '#555', strokeWidth: 1.5 },
        })
      }
    })
  })

  return { nodes, edges }
}

// ─── Inner board (needs ReactFlow context) ────────────────────────────────────

interface BoardInnerProps {
  workflows: Workflow[]
  onGateApprove: (wfId: string, stepId: string) => void
  onWorkflowClick?: (wfId: string) => void
}

function BoardInner({ workflows, onGateApprove, onWorkflowClick }: BoardInnerProps) {
  const { nodes: initialNodes, edges: initialEdges } = useMemo(
    () => buildNodesAndEdges(workflows, onGateApprove),
    [workflows, onGateApprove]
  )

  const [nodes, , onNodesChange] = useNodesState(initialNodes)
  const [edges, , onEdgesChange] = useEdgesState(initialEdges)

  // Column headers — rendered as workflow name labels above the first node
  const headerNodes: Node[] = useMemo(
    () =>
      workflows.map((wf, colIdx) => ({
        id: `header__${wf.id}`,
        type: 'default',
        position: { x: COL_OFFSET_X + colIdx * COL_WIDTH - 10, y: 10 },
        data: { label: wf.name },
        style: {
          background: 'transparent',
          border: 'none',
          fontSize: 11,
          fontWeight: 700,
          color: '#aaa',
          letterSpacing: 0.5,
          pointerEvents: 'all',
          cursor: 'pointer',
          width: 180,
        },
        selectable: false,
        draggable: false,
      })),
    [workflows]
  )

  const allNodes = useMemo(() => [...headerNodes, ...nodes], [headerNodes, nodes])

  return (
    <div style={{ width: '100%', height: '100%', background: '#111' }}>
      <ReactFlow
        nodes={allNodes}
        edges={edges}
        onNodesChange={onNodesChange}
        onEdgesChange={onEdgesChange}
        nodeTypes={nodeTypes}
        onNodeClick={(_e, node) => {
          if (onWorkflowClick && node.id.startsWith('header__')) {
            onWorkflowClick(node.id.replace('header__', ''))
          }
        }}
        fitView
        fitViewOptions={{ padding: 0.3 }}
        minZoom={0.3}
        maxZoom={2}
        proOptions={{ hideAttribution: true }}
      >
        <Background color="#222" variant={BackgroundVariant.Dots} gap={24} size={1} />
        <Controls style={{ background: '#1a1a1a', border: '1px solid #333', color: '#aaa' }} />
        <MiniMap
          style={{ background: '#1a1a1a', border: '1px solid #333' }}
          nodeColor={(n) => {
            const d = n.data as StepNodeData | undefined
            if (!d?.status) return '#333'
            const map: Record<string, string> = {
              done: '#22c55e', gate: '#f59e0b', fail: '#ef4444',
              'in-progress': '#6366f1', pending: '#2a2a2a',
              partial: '#f97316', blocked: '#6b7280',
            }
            return map[d.status] ?? '#333'
          }}
          maskColor="#11111188"
        />
      </ReactFlow>
    </div>
  )
}

// ─── Public component ─────────────────────────────────────────────────────────

export interface WorkflowBoardProps {
  workflows: Workflow[]
  onGateApprove: (wfId: string, stepId: string) => void
  onWorkflowClick?: (wfId: string) => void
}

export default function WorkflowBoard({ workflows, onGateApprove, onWorkflowClick }: WorkflowBoardProps) {
  return (
    <ReactFlowProvider>
      <BoardInner workflows={workflows} onGateApprove={onGateApprove} onWorkflowClick={onWorkflowClick} />
    </ReactFlowProvider>
  )
}
