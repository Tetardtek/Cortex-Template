import { useState, useRef, useEffect } from 'react'
import type { TeamPreset } from '../types'

interface TeamSelectorProps {
  presets: TeamPreset[]
  selected: string | null
  onChange: (teamId: string) => void
  isLoading?: boolean
}

export default function TeamSelector({ presets, selected, onChange, isLoading }: TeamSelectorProps) {
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  const selectedPreset = presets.find((p) => p.id === selected) ?? null

  // Fermer le dropdown si clic en dehors
  useEffect(() => {
    const handler = (e: MouseEvent) => {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false)
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [])

  return (
    <div ref={ref} className="relative">
      {/* Trigger */}
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        disabled={isLoading}
        className="flex items-center gap-2 w-full px-3 py-2 rounded text-sm text-left"
        style={{
          background: '#1a1a1a',
          border: '1px solid #2a2a2a',
          color: selectedPreset ? '#e5e7eb' : '#6b7280',
        }}
      >
        {isLoading ? (
          <span style={{ color: '#6b7280' }}>Chargement…</span>
        ) : selectedPreset ? (
          <>
            <span>{selectedPreset.icon}</span>
            <span className="flex-1">{selectedPreset.label}</span>
            <span style={{ color: '#6b7280' }}>▾</span>
          </>
        ) : (
          <>
            <span className="flex-1">Sélectionner une équipe…</span>
            <span style={{ color: '#6b7280' }}>▾</span>
          </>
        )}
      </button>

      {/* Dropdown */}
      {open && (
        <div
          className="absolute z-50 w-full mt-1 rounded overflow-hidden"
          style={{ background: '#1a1a1a', border: '1px solid #2a2a2a', top: '100%' }}
        >
          {presets.map((preset) => (
            <button
              key={preset.id}
              type="button"
              onClick={() => { onChange(preset.id); setOpen(false) }}
              className="flex flex-col w-full px-3 py-2 text-left"
              style={{
                background: preset.id === selected ? 'rgba(99,102,241,0.15)' : 'transparent',
                borderLeft: preset.id === selected ? '2px solid #6366f1' : '2px solid transparent',
                color: '#e5e7eb',
              }}
            >
              {/* Header */}
              <div className="flex items-center gap-2 text-sm font-medium">
                <span>{preset.icon}</span>
                <span>{preset.label}</span>
                {preset.gate_required && (
                  <span
                    className="text-xs px-1 rounded font-mono"
                    style={{ background: '#292524', color: '#f59e0b' }}
                  >
                    gate
                  </span>
                )}
              </div>

              {/* Preview agents */}
              <div className="flex flex-wrap gap-1 mt-1">
                {preset.agents.slice(0, 4).map((agent) => (
                  <span
                    key={agent}
                    className="text-xs px-1 rounded font-mono"
                    style={{ background: '#0d0d0d', color: '#9ca3af' }}
                  >
                    {agent}
                  </span>
                ))}
                {preset.agents.length > 4 && (
                  <span className="text-xs" style={{ color: '#4b5563' }}>
                    +{preset.agents.length - 4}
                  </span>
                )}
              </div>

              {/* Capabilities */}
              <div className="flex gap-1 mt-1">
                {preset.capabilities.slice(0, 5).map((cap) => (
                  <span key={cap} className="text-xs" style={{ color: '#4b5563' }}>
                    {cap}
                  </span>
                ))}
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
