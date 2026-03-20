import type { WorkspaceWorkflow } from '../../types'

interface Props {
  workflows: WorkspaceWorkflow[]
}

export function WorkspaceMetrics({ workflows }: Props) {
  const total = workflows.reduce((n, wf) => n + wf.steps.length, 0)
  const active = workflows.reduce(
    (n, wf) => n + wf.steps.filter((s) => s.status === 'in-progress').length,
    0
  )
  const gates = workflows.reduce(
    (n, wf) => n + wf.steps.filter((s) => s.isGate && s.status === 'gate').length,
    0
  )

  return (
    <div
      style={{
        position: 'absolute',
        bottom: 0,
        left: 0,
        right: 0,
        height: 40,
        background: '#0d0d0d',
        borderTop: '1px solid #2a2a2a',
        display: 'flex',
        alignItems: 'center',
        padding: '0 16px',
        gap: 16,
        fontFamily: 'monospace',
        fontSize: 11,
        color: '#6b7280',
        zIndex: 5,
      }}
    >
      <span>
        Workflows : <span style={{ color: '#e5e7eb' }}>{workflows.length}</span>
      </span>
      <span style={{ color: '#2a2a2a' }}>|</span>
      <span>
        Steps : <span style={{ color: '#e5e7eb' }}>{total}</span>
      </span>
      <span style={{ color: '#2a2a2a' }}>|</span>
      <span>
        Actifs : <span style={{ color: '#6366f1' }}>{active}</span>
      </span>
      {gates > 0 && (
        <>
          <span style={{ color: '#2a2a2a' }}>|</span>
          <span>
            Gates en attente : <span style={{ color: '#f59e0b' }}>{gates}</span>
          </span>
        </>
      )}
    </div>
  )
}
