import { useInfra } from '../hooks/useInfra'

const STATUS_DOT: Record<string, string> = {
  online:  '#22c55e',
  stopped: '#6b7280',
  errored: '#ef4444',
  unknown: '#f59e0b',
}

const TYPE_BADGE: Record<string, { bg: string, color: string, label: string }> = {
  pm2:    { bg: 'rgba(99,102,241,0.15)',  color: '#6366f1', label: 'pm2'    },
  system: { bg: 'rgba(34,197,94,0.15)',   color: '#22c55e', label: 'system' },
  info:   { bg: 'rgba(107,114,128,0.15)', color: '#6b7280', label: 'info'   },
}

export default function InfraRegistry() {
  const { services, loading, error, reload, formatUptime, formatMemory } = useInfra()

  return (
    <div style={{ padding: '24px', maxWidth: 900 }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 24 }}>
        <div>
          <h2 style={{ color: '#e5e7eb', fontSize: 18, fontWeight: 600, margin: 0 }}>InfraRegistry</h2>
          <p style={{ color: '#6b7280', fontSize: 12, margin: '4px 0 0', fontFamily: 'monospace' }}>
            {loading ? 'Chargement...' : `${services.length} services`}
            {error && <span style={{ color: '#ef4444', marginLeft: 8 }}>— {error}</span>}
          </p>
        </div>
        <button
          onClick={reload}
          disabled={loading}
          style={{
            marginLeft: 'auto', background: '#1a1a1a', border: '1px solid #2a2a2a',
            color: '#9ca3af', borderRadius: 6, padding: '6px 12px', fontSize: 12,
            cursor: loading ? 'not-allowed' : 'pointer', fontFamily: 'monospace',
          }}
        >
          ⟳ Actualiser
        </button>
      </div>

      {/* Table */}
      <div style={{ border: '1px solid #2a2a2a', borderRadius: 8, overflow: 'hidden' }}>
        {/* Header row */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: '1fr 80px 80px 70px 70px 60px 60px',
          padding: '8px 16px',
          background: '#1a1a1a',
          borderBottom: '1px solid #2a2a2a',
          fontSize: 10, fontFamily: 'monospace', color: '#4b5563', textTransform: 'uppercase', letterSpacing: 1,
        }}>
          <span>Service</span>
          <span>Type</span>
          <span>Statut</span>
          <span>Port</span>
          <span>Uptime</span>
          <span>Mem</span>
          <span>Restarts</span>
        </div>

        {/* Rows */}
        {services.map((svc) => {
          const dot   = STATUS_DOT[svc.status] ?? '#6b7280'
          const badge = TYPE_BADGE[svc.type] ?? TYPE_BADGE.info
          return (
            <div
              key={svc.id}
              style={{
                display: 'grid',
                gridTemplateColumns: '1fr 80px 80px 70px 70px 60px 60px',
                padding: '10px 16px',
                borderBottom: '1px solid #1a1a1a',
                alignItems: 'center',
                fontSize: 13,
              }}
            >
              <span style={{ color: '#e5e7eb', fontWeight: 500 }}>{svc.name}</span>

              <span style={{
                display: 'inline-block', padding: '2px 6px', borderRadius: 4,
                fontSize: 10, fontFamily: 'monospace',
                background: badge.bg, color: badge.color,
              }}>
                {badge.label}
              </span>

              <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ width: 7, height: 7, borderRadius: '50%', background: dot, flexShrink: 0 }} />
                <span style={{ color: dot, fontSize: 11, fontFamily: 'monospace' }}>{svc.status}</span>
              </span>

              <span style={{ color: '#6b7280', fontFamily: 'monospace', fontSize: 12 }}>
                {svc.port ?? '—'}
              </span>

              <span style={{ color: '#6b7280', fontFamily: 'monospace', fontSize: 12 }}>
                {formatUptime(svc.uptime)}
              </span>

              <span style={{ color: '#6b7280', fontFamily: 'monospace', fontSize: 12 }}>
                {formatMemory(svc.memory)}
              </span>

              <span style={{ color: svc.restarts && svc.restarts > 10 ? '#f59e0b' : '#6b7280', fontFamily: 'monospace', fontSize: 12 }}>
                {svc.restarts ?? '—'}
              </span>
            </div>
          )
        })}

        {!loading && services.length === 0 && (
          <div style={{ padding: '32px 16px', textAlign: 'center', color: '#4b5563', fontFamily: 'monospace', fontSize: 12 }}>
            Aucun service détecté
          </div>
        )}
      </div>
    </div>
  )
}
