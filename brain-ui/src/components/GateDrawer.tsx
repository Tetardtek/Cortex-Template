import { useState, useEffect } from 'react'

const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

interface GateDrawerProps {
  open:       boolean
  onClose:    () => void
  workflowId: string | null
  stepId:     string | null
}

export default function GateDrawer({ open, onClose, workflowId, stepId }: GateDrawerProps) {
  const [busy,     setBusy]     = useState(false)
  const [approved, setApproved] = useState(false)

  // Reset state when drawer opens for a new gate
  useEffect(() => {
    if (open) {
      setBusy(false)
      setApproved(false)
    }
  }, [open, workflowId, stepId])

  const handleApprove = async () => {
    if (!workflowId || !stepId || busy) return
    setBusy(true)
    try {
      await fetch(
        `${API_BASE}/gate/${encodeURIComponent(workflowId)}/${encodeURIComponent(stepId)}/approve`,
        {
          method:      'POST',
          credentials: 'include',
          headers:     { 'Content-Type': 'application/json' },
        }
      )
      setApproved(true)
      setTimeout(() => {
        setApproved(false)
        onClose()
      }, 1500)
    } finally {
      setBusy(false)
    }
  }

  const handleReject = async () => {
    if (!workflowId || !stepId || busy) return
    setBusy(true)
    try {
      const res = await fetch(
        `${API_BASE}/gate/${encodeURIComponent(workflowId)}/${encodeURIComponent(stepId)}/reject`,
        {
          method:      'POST',
          credentials: 'include',
          headers:     { 'Content-Type': 'application/json' },
        }
      )
      // 404 = endpoint optionnel — gérer silencieusement
      if (res.ok || res.status === 404) {
        onClose()
      }
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      {/* Overlay — cliquable pour fermer */}
      <div
        onClick={onClose}
        style={{
          position:      'fixed',
          inset:         0,
          zIndex:        49,
          background:    open ? 'rgba(0,0,0,0.4)' : 'transparent',
          pointerEvents: open ? 'auto' : 'none',
          transition:    'background 0.2s',
        }}
      />

      {/* Panel slide-in depuis la droite */}
      <div
        style={{
          position:      'fixed',
          top:           0,
          right:         0,
          bottom:        0,
          zIndex:        50,
          width:         380,
          background:    '#0a0a0a',
          borderLeft:    '1px solid #2a2a2a',
          display:       'flex',
          flexDirection: 'column',
          transform:     open ? 'translateX(0)' : 'translateX(100%)',
          transition:    'transform 0.25s cubic-bezier(0.4, 0, 0.2, 1)',
        }}
      >
        {/* Header */}
        <div
          style={{
            display:      'flex',
            alignItems:   'center',
            gap:          10,
            padding:      '12px 16px',
            borderBottom: '1px solid #2a2a2a',
            flexShrink:   0,
          }}
        >
          {/* Titre */}
          <span
            style={{
              color:        '#9ca3af',
              fontFamily:   'monospace',
              fontSize:     12,
              flex:         1,
              overflow:     'hidden',
              textOverflow: 'ellipsis',
              whiteSpace:   'nowrap',
            }}
          >
            Gate — {stepId ?? '—'}
          </span>

          {/* Badge "En attente d'approbation" */}
          <span
            style={{
              fontSize:     10,
              fontFamily:   'monospace',
              color:        '#f59e0b',
              background:   'rgba(245,158,11,0.12)',
              border:       '1px solid rgba(245,158,11,0.35)',
              borderRadius: 4,
              padding:      '2px 7px',
              flexShrink:   0,
            }}
          >
            En attente d'approbation
          </span>

          {/* Bouton fermer */}
          <button
            onClick={onClose}
            title="Fermer"
            style={{
              background: 'transparent',
              border:     'none',
              color:      '#6b7280',
              cursor:     'pointer',
              fontSize:   16,
              lineHeight: 1,
              padding:    '0 2px',
              flexShrink: 0,
            }}
          >
            ✕
          </button>
        </div>

        {/* Corps */}
        <div
          style={{
            flex:    1,
            padding: '24px 20px',
            display: 'flex',
            flexDirection: 'column',
            gap:     20,
          }}
        >
          {/* Description */}
          <p
            style={{
              color:      '#9ca3af',
              fontSize:   13,
              lineHeight: 1.6,
              margin:     0,
            }}
          >
            Cette étape est un point de contrôle. Approuver pour continuer le workflow.
          </p>

          {/* Métadonnées */}
          {workflowId && stepId && (
            <div
              style={{
                background:   '#111',
                border:       '1px solid #1f1f1f',
                borderRadius: 6,
                padding:      '10px 14px',
                fontFamily:   'monospace',
                fontSize:     11,
                color:        '#4b5563',
                lineHeight:   1.7,
              }}
            >
              <div><span style={{ color: '#374151' }}>workflow</span> {workflowId}</div>
              <div><span style={{ color: '#374151' }}>step    </span> {stepId}</div>
            </div>
          )}

          {/* État "Approuvé" */}
          {approved && (
            <div
              style={{
                display:      'flex',
                alignItems:   'center',
                gap:          8,
                color:        '#22c55e',
                fontSize:     14,
                fontWeight:   600,
                background:   'rgba(34,197,94,0.08)',
                border:       '1px solid rgba(34,197,94,0.25)',
                borderRadius: 6,
                padding:      '10px 14px',
              }}
            >
              Approuvé ✓
            </div>
          )}

          {/* Boutons */}
          {!approved && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {/* Bouton Approuver */}
              <button
                disabled={busy}
                onClick={handleApprove}
                style={{
                  background:   'rgba(34,197,94,0.15)',
                  border:       '1px solid #22c55e',
                  color:        '#22c55e',
                  borderRadius: 6,
                  padding:      '10px 0',
                  fontSize:     13,
                  fontWeight:   600,
                  cursor:       busy ? 'not-allowed' : 'pointer',
                  opacity:      busy ? 0.6 : 1,
                  transition:   'opacity 0.15s',
                  width:        '100%',
                }}
              >
                {busy ? 'En cours…' : 'Approuver'}
              </button>

              {/* Bouton Rejeter */}
              <button
                disabled={busy}
                onClick={handleReject}
                style={{
                  background:   'rgba(239,68,68,0.1)',
                  border:       '1px solid #ef4444',
                  color:        '#ef4444',
                  borderRadius: 6,
                  padding:      '10px 0',
                  fontSize:     13,
                  fontWeight:   600,
                  cursor:       busy ? 'not-allowed' : 'pointer',
                  opacity:      busy ? 0.6 : 1,
                  transition:   'opacity 0.15s',
                  width:        '100%',
                }}
              >
                Rejeter
              </button>
            </div>
          )}
        </div>
      </div>
    </>
  )
}
