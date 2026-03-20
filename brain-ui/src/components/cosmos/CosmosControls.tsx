import type { ZoneKey } from '../../types'

type ZoneFilter = 'all' | ZoneKey

interface ZoneOption {
  id: ZoneFilter
  label: string
  color: string
}

const ZONE_OPTIONS: ZoneOption[] = [
  { id: 'all',       label: 'Tout',      color: '#9ca3af' },
  { id: 'kernel',    label: 'kernel',    color: '#ef4444' },
  { id: 'instance',  label: 'instance',  color: '#f59e0b' },
  { id: 'satellite', label: 'satellite', color: '#6366f1' },
  { id: 'public',    label: 'public',    color: '#e5e7eb' },
]

interface CosmosControlsProps {
  activeZone: ZoneFilter
  searchQuery: string
  onZoneChange: (zone: ZoneFilter) => void
  onSearchChange: (query: string) => void
  isFullscreen: boolean
  onToggleFullscreen: () => void
  isHeatmap: boolean
  onToggleHeatmap: () => void
}

export function CosmosControls({ activeZone, searchQuery, onZoneChange, onSearchChange, isFullscreen, onToggleFullscreen, isHeatmap, onToggleHeatmap }: CosmosControlsProps) {
  return (
    <div
      className="flex items-center gap-2 flex-shrink-0"
      style={{
        padding: '8px 12px',
        borderBottom: '1px solid #2a2a2a',
        background: '#0d0d0d',
      }}
    >
      <div className="flex items-center gap-1">
        {ZONE_OPTIONS.map((opt) => {
          const isActive = activeZone === opt.id
          return (
            <button
              key={opt.id}
              onClick={() => onZoneChange(opt.id)}
              className="text-xs px-2.5 py-1 rounded font-mono transition-colors"
              style={{
                background: isActive ? 'rgba(99,102,241,0.15)' : 'transparent',
                color: isActive ? opt.color : '#6b7280',
                border: `1px solid ${isActive ? opt.color : '#2a2a2a'}`,
              }}
            >
              {opt.label}
            </button>
          )
        })}
      </div>

      <div className="flex-1" />

      <input
        type="text"
        value={searchQuery}
        onChange={(e) => onSearchChange(e.target.value)}
        placeholder="Rechercher..."
        className="text-xs font-mono rounded px-2.5 py-1 outline-none"
        style={{
          background: '#1a1a1a',
          border: '1px solid #2a2a2a',
          color: '#e5e7eb',
          width: 200,
        }}
      />

      <button
        onClick={onToggleHeatmap}
        title={isHeatmap ? 'Mode points' : 'Mode nébuleuse'}
        className="text-xs font-mono rounded px-2 py-1 transition-colors"
        style={{
          background: isHeatmap ? 'rgba(99,102,241,0.15)' : 'transparent',
          border: `1px solid ${isHeatmap ? '#6366f1' : '#2a2a2a'}`,
          color: isHeatmap ? '#818cf8' : '#6b7280',
          lineHeight: 1,
          flexShrink: 0,
        }}
      >
        ⬡
      </button>

      <button
        onClick={onToggleFullscreen}
        title={isFullscreen ? 'Quitter le plein écran' : 'Plein écran'}
        className="text-xs font-mono rounded px-2 py-1 transition-colors"
        style={{
          background: 'transparent',
          border: '1px solid #2a2a2a',
          color: '#6b7280',
          lineHeight: 1,
          flexShrink: 0,
        }}
      >
        {isFullscreen ? '⊠' : '⊡'}
      </button>
    </div>
  )
}
