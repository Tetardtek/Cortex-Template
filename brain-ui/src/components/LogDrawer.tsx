import { useEffect, useRef } from 'react'
import { useBrainStore } from '../store/brain.store'

interface LogDrawerProps {
  open:     boolean
  onClose:  () => void
  project:  string | null
}

const LEVEL_COLOR: Record<string, string> = {
  error: '#ef4444',
  warn:  '#f59e0b',
  info:  '#9ca3af',
  debug: '#4b5563',
}

const EMPTY_LOGS: never[] = []

export default function LogDrawer({ open, onClose, project }: LogDrawerProps) {
  const logs      = useBrainStore((s) => s.logs[project ?? ''] ?? EMPTY_LOGS)
  const wsStatus  = useBrainStore((s) => s.wsStatus)
  const clearLogs = useBrainStore((s) => s.clearLogs)
  const bottomRef = useRef<HTMLDivElement>(null)

  // Auto-scroll quand nouveaux logs
  useEffect(() => {
    if (open) {
      bottomRef.current?.scrollIntoView({ behavior: 'smooth' })
    }
  }, [logs, open])

  // Badge wsStatus
  const wsBadgeColor =
    wsStatus === 'connected'    ? '#22c55e' :
    wsStatus === 'error'        ? '#ef4444' : '#6b7280'
  const wsLabel =
    wsStatus === 'connected'    ? 'ws live' :
    wsStatus === 'error'        ? 'ws erreur' : 'ws off'

  return (
    <>
      {/* Overlay — cliquable pour fermer */}
      <div
        onClick={onClose}
        style={{
          position:   'fixed',
          inset:      0,
          zIndex:     49,
          background: open ? 'rgba(0,0,0,0.4)' : 'transparent',
          pointerEvents: open ? 'auto' : 'none',
          transition: 'background 0.2s',
        }}
      />

      {/* Panel slide-in */}
      <div
        style={{
          position:   'fixed',
          top:        0,
          right:      0,
          bottom:     0,
          zIndex:     50,
          width:      420,
          background: '#0a0a0a',
          borderLeft: '1px solid #1a1a1a',
          display:    'flex',
          flexDirection: 'column',
          transform:  open ? 'translateX(0)' : 'translateX(100%)',
          transition: 'transform 0.25s cubic-bezier(0.4, 0, 0.2, 1)',
        }}
      >
        {/* Header */}
        <div
          style={{
            display:      'flex',
            alignItems:   'center',
            gap:          8,
            padding:      '12px 16px',
            borderBottom: '1px solid #1a1a1a',
            flexShrink:   0,
          }}
        >
          {/* Titre */}
          <span
            style={{
              color:      '#9ca3af',
              fontFamily: 'monospace',
              fontSize:   12,
              flex:       1,
              overflow:   'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
            }}
          >
            Logs — {project ?? '—'}
          </span>

          {/* Badge wsStatus */}
          <span
            style={{
              display:      'flex',
              alignItems:   'center',
              gap:          4,
              fontSize:     10,
              fontFamily:   'monospace',
              color:        wsBadgeColor,
              background:   `${wsBadgeColor}1a`,
              border:       `1px solid ${wsBadgeColor}33`,
              borderRadius: 4,
              padding:      '2px 6px',
              flexShrink:   0,
            }}
          >
            <span
              style={{
                width:        6,
                height:       6,
                borderRadius: '50%',
                background:   wsBadgeColor,
                flexShrink:   0,
              }}
            />
            {wsLabel}
          </span>

          {/* Bouton Effacer */}
          <button
            onClick={() => project && clearLogs(project)}
            title="Effacer les logs"
            style={{
              background:   'transparent',
              border:       '1px solid #2a2a2a',
              borderRadius: 4,
              color:        '#6b7280',
              cursor:       'pointer',
              fontSize:     10,
              fontFamily:   'monospace',
              padding:      '2px 8px',
              lineHeight:   '16px',
              flexShrink:   0,
            }}
          >
            Effacer
          </button>

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

        {/* Corps — log lines */}
        <div
          style={{
            flex:       1,
            overflowY:  'auto',
            padding:    '8px 12px',
            fontFamily: 'monospace',
            fontSize:   11,
          }}
        >
          {logs.length === 0 ? (
            <div style={{ color: '#4b5563', marginTop: 8, lineHeight: 1.6 }}>
              Aucun log — démarrer un workflow pour voir les événements.
            </div>
          ) : (
            logs.map((line, i) => (
              <div key={i} style={{ marginBottom: 2, lineHeight: 1.5 }}>
                <span style={{ color: '#4b5563' }}>
                  {line.ts.slice(11, 19)}{' '}
                </span>
                <span
                  style={{
                    color:       LEVEL_COLOR[line.level] ?? '#9ca3af',
                    marginRight: 6,
                  }}
                >
                  {line.level.toUpperCase().padEnd(5)}
                </span>
                <span style={{ color: '#d1d5db' }}>{line.msg}</span>
              </div>
            ))
          )}
          <div ref={bottomRef} />
        </div>
      </div>
    </>
  )
}
