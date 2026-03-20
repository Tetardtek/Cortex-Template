import { useMemo } from 'react'
import type { CosmosPoint, ZoneKey } from '../../types'

const ZONE_TEXT_COLORS: Record<ZoneKey, string> = {
  kernel:    '#ef4444',
  instance:  '#f59e0b',
  satellite: '#6366f1',
  public:    '#e5e7eb',
  work:      '#6366f1',
  unknown:   '#6b7280',
}

interface CosmosMetricsProps {
  points: CosmosPoint[]
  generatedAt: string | null
  onReload: () => void
  loading: boolean
}

export function CosmosMetrics({ points, generatedAt, onReload, loading }: CosmosMetricsProps) {
  const { total, byZone, lastSync } = useMemo(() => {
    const total = points.length
    const byZone = points.reduce((acc, p) => {
      acc[p.zone] = (acc[p.zone] ?? 0) + 1
      return acc
    }, {} as Partial<Record<ZoneKey, number>>)

    const lastSync = generatedAt
      ? new Intl.DateTimeFormat('fr-FR', {
          day: 'numeric',
          month: 'short',
          hour: '2-digit',
          minute: '2-digit',
        }).format(new Date(generatedAt))
      : '—'

    return { total, byZone, lastSync }
  }, [points, generatedAt])

  const zones: ZoneKey[] = ['kernel', 'instance', 'satellite', 'public']

  return (
    <div
      className="flex items-center gap-3 flex-shrink-0 px-3"
      style={{
        height: 40,
        background: '#0d0d0d',
        borderTop: '1px solid #2a2a2a',
        fontSize: 11,
        fontFamily: 'monospace',
        color: '#6b7280',
      }}
    >
      <span>Total : {total}</span>

      <span style={{ color: '#2a2a2a' }}>|</span>

      {zones.map((zone) => (
        byZone[zone] != null ? (
          <span key={zone}>
            <span style={{ color: ZONE_TEXT_COLORS[zone] }}>{zone}</span>
            {' : '}
            <span style={{ color: '#9ca3af' }}>{byZone[zone]}</span>
          </span>
        ) : null
      ))}

      <span style={{ color: '#2a2a2a' }}>|</span>

      <span>sync : {lastSync}</span>

      <div className="flex-1" />

      <button
        onClick={onReload}
        disabled={loading}
        className="text-xs px-2 py-1 rounded"
        style={{
          background: 'transparent',
          border: '1px solid #2a2a2a',
          color: loading ? '#4b5563' : '#9ca3af',
          cursor: loading ? 'not-allowed' : 'pointer',
          fontFamily: 'monospace',
          fontSize: 11,
        }}
      >
        {loading ? '...' : '⟳ Recharger'}
      </button>
    </div>
  )
}
