import { useState } from 'react'
import type { WorkspaceStep, WorkspaceWorkflow } from '../../types'

const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

const STATUS_COLORS: Record<string, string> = {
  done:          '#22c55e',
  'in-progress': '#6366f1',
  pending:       '#4b5563',
  gate:          '#f59e0b',
  fail:          '#ef4444',
  blocked:       '#6b7280',
}

interface Props {
  selection: { step: WorkspaceStep; wf: WorkspaceWorkflow } | null
  onClose: () => void
}

export function WorkspaceInfoPanel({ selection, onClose }: Props) {
  const [busy, setBusy] = useState(false)

  if (!selection) return null
  const { step, wf } = selection

  const gateAction = async (action: 'approve' | 'abort') => {
    setBusy(true)
    try {
      await fetch(
        `${API_BASE}/gate/${encodeURIComponent(wf.id)}/${encodeURIComponent(step.id)}/approve`,
        {
          method: 'POST',
          credentials: 'include',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ action }),
        }
      )
      onClose()
    } finally {
      setBusy(false)
    }
  }

  return (
    <div
      style={{
        position: 'absolute',
        top: 0,
        right: 0,
        bottom: 0,
        width: 320,
        background: '#0d0d0d',
        borderLeft: '1px solid #2a2a2a',
        display: 'flex',
        flexDirection: 'column',
        zIndex: 10,
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          padding: '12px 16px',
          borderBottom: '1px solid #2a2a2a',
          gap: 8,
        }}
      >
        <span
          style={{ color: '#6b7280', fontFamily: 'monospace', fontSize: 11, flex: 1 }}
        >
          {wf.name}
        </span>
        <button
          onClick={onClose}
          style={{
            background: 'transparent',
            border: 'none',
            color: '#6b7280',
            cursor: 'pointer',
            fontSize: 16,
          }}
        >
          ✕
        </button>
      </div>

      <div
        style={{
          padding: '16px',
          flex: 1,
          display: 'flex',
          flexDirection: 'column',
          gap: 12,
        }}
      >
        <div style={{ color: '#e5e7eb', fontWeight: 600, fontSize: 16 }}>{step.label}</div>
        <span
          style={{
            display: 'inline-block',
            padding: '2px 8px',
            borderRadius: 4,
            fontSize: 11,
            background: `${STATUS_COLORS[step.status] ?? '#4b5563'}22`,
            color: STATUS_COLORS[step.status] ?? '#4b5563',
          }}
        >
          {step.status}
        </span>

        {step.isGate && (
          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            <button
              disabled={busy}
              onClick={() => gateAction('approve')}
              style={{
                background: '#16a34a',
                color: '#fff',
                border: 'none',
                borderRadius: 6,
                padding: '6px 16px',
                fontWeight: 600,
                cursor: busy ? 'not-allowed' : 'pointer',
                opacity: busy ? 0.6 : 1,
              }}
            >
              Approuver
            </button>
            <button
              disabled={busy}
              onClick={() => gateAction('abort')}
              style={{
                background: '#dc2626',
                color: '#fff',
                border: 'none',
                borderRadius: 6,
                padding: '6px 16px',
                fontWeight: 600,
                cursor: busy ? 'not-allowed' : 'pointer',
                opacity: busy ? 0.6 : 1,
              }}
            >
              Rejeter
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
