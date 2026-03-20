import { useState } from 'react'

const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

interface GatesDrawerProps {
  workflowId: string
  stepId:     string
  stepLabel:  string
  onApprove:  () => Promise<void>
  onReject:   (action: 'abort' | 'skip') => Promise<void>
  onClose:    () => void
}

export default function GatesDrawer({
  workflowId,
  stepId,
  stepLabel,
  onApprove,
  onReject,
  onClose,
}: GatesDrawerProps) {
  const [busy, setBusy] = useState(false)

  const gateUrl = `${API_BASE}/gate/${encodeURIComponent(workflowId)}/${encodeURIComponent(stepId)}/approve`

  const approve = async () => {
    setBusy(true)
    try {
      await fetch(gateUrl, {
        method:      'POST',
        credentials: 'include',
        headers:     { 'Content-Type': 'application/json' },
        body:        JSON.stringify({ action: 'approve' }),
      })
      await onApprove()
    } finally {
      setBusy(false)
    }
  }

  const reject = async (action: 'abort' | 'skip') => {
    setBusy(true)
    try {
      await fetch(gateUrl, {
        method:      'POST',
        credentials: 'include',
        headers:     { 'Content-Type': 'application/json' },
        body:        JSON.stringify({ action }),
      })
      await onReject(action)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div
      style={{
        position:        'fixed',
        bottom:          0,
        left:            0,
        right:           0,
        zIndex:          50,
        background:      'rgba(245,158,11,0.15)',
        borderTop:       '1px solid rgba(245,158,11,0.5)',
        backdropFilter:  'blur(4px)',
        padding:         '12px 24px',
        display:         'flex',
        alignItems:      'center',
        gap:             12,
      }}
    >
      <span style={{ color: '#fbbf24', fontWeight: 600, flex: 1 }}>
        Gate en attente — <span style={{ color: '#fff' }}>{stepLabel}</span>
      </span>

      <button
        disabled={busy}
        onClick={approve}
        style={{
          background:    '#16a34a',
          color:         '#fff',
          border:        'none',
          borderRadius:  6,
          padding:       '6px 16px',
          fontWeight:    600,
          cursor:        busy ? 'not-allowed' : 'pointer',
          opacity:       busy ? 0.6 : 1,
        }}
      >
        Approuver
      </button>

      <button
        disabled={busy}
        onClick={() => reject('abort')}
        style={{
          background:    '#dc2626',
          color:         '#fff',
          border:        'none',
          borderRadius:  6,
          padding:       '6px 16px',
          fontWeight:    600,
          cursor:        busy ? 'not-allowed' : 'pointer',
          opacity:       busy ? 0.6 : 1,
        }}
      >
        Rejeter
      </button>

      <button
        disabled={busy}
        onClick={onClose}
        style={{
          background:    'transparent',
          color:         '#9ca3af',
          border:        '1px solid #374151',
          borderRadius:  6,
          padding:       '6px 16px',
          cursor:        busy ? 'not-allowed' : 'pointer',
          opacity:       busy ? 0.6 : 1,
        }}
      >
        Ignorer
      </button>
    </div>
  )
}
