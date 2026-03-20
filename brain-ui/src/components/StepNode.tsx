import { memo } from 'react'
import { Handle, Position, NodeProps } from 'reactflow'
import type { StepStatus } from '../types'

export interface StepNodeData {
  label: string
  status: StepStatus
  isGate?: boolean
  workflowId: string
  stepId: string
  onGateApprove?: (workflowId: string, stepId: string) => void
}

const STATUS_COLORS: Record<StepStatus, string> = {
  done: '#22c55e',
  gate: '#f59e0b',
  fail: '#ef4444',
  'in-progress': '#6366f1',
  pending: '#2a2a2a',
  partial: '#f97316',
  blocked: '#6b7280',
}

const STATUS_BORDER: Record<StepStatus, string> = {
  done: '#16a34a',
  gate: '#d97706',
  fail: '#dc2626',
  'in-progress': '#4f46e5',
  pending: '#3f3f3f',
  partial: '#ea580c',
  blocked: '#4b5563',
}

const STATUS_LABELS: Record<StepStatus, string> = {
  done: 'DONE',
  gate: 'GATE',
  fail: 'FAIL',
  'in-progress': 'IN PROGRESS',
  pending: 'PENDING',
  partial: 'PARTIAL',
  blocked: 'BLOCKED',
}

function StepNode({ data }: NodeProps<StepNodeData>) {
  const { label, status, isGate, workflowId, stepId, onGateApprove } = data
  const bg = STATUS_COLORS[status]
  const border = STATUS_BORDER[status]
  const isClickable = isGate && (status === 'gate' || status === 'pending') && onGateApprove

  const handleClick = () => {
    if (isClickable) {
      onGateApprove!(workflowId, stepId)
    }
  }

  if (isGate) {
    // Diamond shape via CSS transform on a square
    const size = 64
    return (
      <>
        <Handle type="target" position={Position.Top} style={{ background: border, border: 'none' }} />
        <div
          onClick={handleClick}
          title={isClickable ? `Approve gate: ${label}` : undefined}
          style={{
            width: size,
            height: size,
            background: bg,
            border: `2px solid ${border}`,
            transform: 'rotate(45deg)',
            cursor: isClickable ? 'pointer' : 'default',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: isClickable ? `0 0 12px ${bg}88` : undefined,
            transition: 'box-shadow 0.15s ease',
          }}
        >
          <span
            style={{
              transform: 'rotate(-45deg)',
              fontSize: 10,
              fontWeight: 700,
              color: '#fff',
              textAlign: 'center',
              lineHeight: 1.2,
              userSelect: 'none',
              maxWidth: 52,
              wordBreak: 'break-word',
            }}
          >
            {label}
          </span>
        </div>
        <Handle type="source" position={Position.Bottom} style={{ background: border, border: 'none' }} />
      </>
    )
  }

  return (
    <>
      <Handle type="target" position={Position.Top} style={{ background: border, border: 'none' }} />
      <div
        style={{
          background: bg,
          border: `2px solid ${border}`,
          borderRadius: 8,
          padding: '8px 16px',
          minWidth: 120,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 2,
          cursor: 'default',
          boxShadow: status === 'in-progress' ? `0 0 10px ${bg}66` : undefined,
        }}
      >
        <span style={{ fontSize: 12, fontWeight: 700, color: '#fff', userSelect: 'none' }}>{label}</span>
        <span style={{ fontSize: 9, fontWeight: 500, color: '#ffffff99', letterSpacing: 1, userSelect: 'none' }}>
          {STATUS_LABELS[status]}
        </span>
      </div>
      <Handle type="source" position={Position.Bottom} style={{ background: border, border: 'none' }} />
    </>
  )
}

export default memo(StepNode)
