import { useState } from 'react'
import type { CosmosPoint, ZoneKey } from '../../types'

const ZONE_BADGE_COLORS: Record<ZoneKey, { bg: string; text: string }> = {
  public:    { bg: 'rgba(229,231,235,0.1)', text: '#e5e7eb' },
  work:      { bg: 'rgba(99,102,241,0.15)', text: '#6366f1' },
  kernel:    { bg: 'rgba(239,68,68,0.15)',  text: '#ef4444' },
  instance:  { bg: 'rgba(168,85,247,0.15)', text: '#a855f7' },
  satellite: { bg: 'rgba(34,197,94,0.15)',  text: '#22c55e' },
  unknown:   { bg: 'rgba(75,85,99,0.2)',    text: '#6b7280' },
}

function getNearestNeighbors(target: CosmosPoint, all: CosmosPoint[], n = 10): CosmosPoint[] {
  return all
    .filter((p) => p.id !== target.id)
    .map((p) => ({
      point: p,
      dist: Math.sqrt(
        (p.x - target.x) ** 2 +
        (p.y - target.y) ** 2 +
        (p.z - target.z) ** 2
      ),
    }))
    .sort((a, b) => a.dist - b.dist)
    .slice(0, n)
    .map((e) => e.point)
}

interface CosmosInfoPanelProps {
  point: CosmosPoint | null
  allPoints: CosmosPoint[]
  onClose: () => void
  onHighlightNeighbors: (ids: Set<string>) => void
  highlightedIds: Set<string>
  kernelAccess?: boolean
}

export function CosmosInfoPanel({ point, allPoints, onClose, onHighlightNeighbors, highlightedIds, kernelAccess }: CosmosInfoPanelProps) {
  const [neighborsActive, setNeighborsActive] = useState(false)
  const [editing, setEditing] = useState(false)
  const [draftContent, setDraftContent] = useState('')
  const [saving, setSaving] = useState(false)

  const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

  const isOpen = point !== null

  const handleToggleNeighbors = () => {
    if (!point) return
    if (neighborsActive) {
      onHighlightNeighbors(new Set())
      setNeighborsActive(false)
    } else {
      const neighbors = getNearestNeighbors(point, allPoints, 10)
      onHighlightNeighbors(new Set(neighbors.map((p) => p.id)))
      setNeighborsActive(true)
    }
  }

  // Reset neighbors active state when point changes
  const handleClose = () => {
    setNeighborsActive(false)
    setEditing(false)
    onHighlightNeighbors(new Set())
    onClose()
  }

  const handleSave = async () => {
    if (!point) return
    setSaving(true)
    try {
      await fetch(`${API_BASE}/brain/${encodeURIComponent(point.path)}`, {
        method: 'PUT',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ content: draftContent }),
      })
      setEditing(false)
    } catch {
      // silencieux — pas de connexion
    } finally {
      setSaving(false)
    }
  }

  const badgeColors = point ? ZONE_BADGE_COLORS[point.zone] : ZONE_BADGE_COLORS.unknown

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
        transform: isOpen ? 'translateX(0)' : 'translateX(100%)',
        transition: 'transform 200ms ease',
        zIndex: 20,
        display: 'flex',
        flexDirection: 'column',
        padding: '16px',
        overflowY: 'auto',
      }}
    >
      {point && (
        <>
          {/* Close button */}
          <div className="flex justify-end mb-4">
            <button
              onClick={handleClose}
              className="text-xs px-2 py-1 rounded"
              style={{ color: '#6b7280', background: 'transparent', border: '1px solid #2a2a2a' }}
            >
              ✕
            </button>
          </div>

          {/* Path */}
          <div
            className="font-mono text-xs mb-2 break-all"
            style={{ color: '#6b7280' }}
          >
            {point.path}
          </div>

          {/* Zone badge */}
          <div className="mb-3">
            <span
              className="text-xs px-2 py-0.5 rounded font-mono"
              style={{ background: badgeColors.bg, color: badgeColors.text }}
            >
              {point.zone}
            </span>
          </div>

          {/* Label */}
          <div
            className="text-base font-semibold mb-3"
            style={{ color: '#e5e7eb' }}
          >
            {point.label}
          </div>

          {/* Separator */}
          <div style={{ borderTop: '1px solid #2a2a2a', marginBottom: 12 }} />

          {/* Excerpt / Editor */}
          {editing ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8, marginBottom: 16 }}>
              <textarea
                value={draftContent}
                onChange={(e) => setDraftContent(e.target.value)}
                style={{
                  background: '#1a1a1a', border: '1px solid #2a2a2a', color: '#e5e7eb',
                  borderRadius: 6, padding: 8, fontSize: 12, fontFamily: 'monospace',
                  resize: 'vertical', minHeight: 120, outline: 'none',
                }}
              />
              <div style={{ display: 'flex', gap: 8 }}>
                <button onClick={handleSave} disabled={saving}
                  style={{ background: '#6366f1', color: '#fff', border: 'none', borderRadius: 6, padding: '4px 12px', fontSize: 12, cursor: saving ? 'not-allowed' : 'pointer', opacity: saving ? 0.6 : 1 }}>
                  {saving ? 'Sauvegarde...' : 'Sauvegarder'}
                </button>
                <button onClick={() => setEditing(false)}
                  style={{ background: 'transparent', color: '#6b7280', border: '1px solid #2a2a2a', borderRadius: 6, padding: '4px 12px', fontSize: 12, cursor: 'pointer' }}>
                  Annuler
                </button>
              </div>
            </div>
          ) : (
            <div className="mb-4">
              <p style={{ color: '#9ca3af', fontSize: 14, lineHeight: 1.6, marginBottom: 8 }}>{point.excerpt}</p>
              {kernelAccess && (
                <button
                  onClick={() => { setEditing(true); setDraftContent(point.excerpt) }}
                  style={{ background: '#1a1a1a', color: '#6366f1', border: '1px solid #2a2a2a', borderRadius: 6, padding: '4px 12px', fontSize: 12, cursor: 'pointer' }}
                >
                  Modifier
                </button>
              )}
            </div>
          )}

          {/* Separator */}
          <div style={{ borderTop: '1px solid #2a2a2a', marginBottom: 12 }} />

          {/* Neighbors button */}
          <button
            onClick={handleToggleNeighbors}
            className="text-xs px-3 py-2 rounded text-left"
            style={{
              background: neighborsActive ? 'rgba(99,102,241,0.15)' : '#1a1a1a',
              color: neighborsActive ? '#6366f1' : '#e5e7eb',
              border: `1px solid ${neighborsActive ? '#6366f1' : '#2a2a2a'}`,
            }}
          >
            {neighborsActive ? 'Réinitialiser les voisins' : 'Voir les 10 voisins'}
          </button>

          {highlightedIds.size > 0 && (
            <div
              className="text-xs mt-2 font-mono"
              style={{ color: '#6b7280' }}
            >
              {highlightedIds.size} points mis en surbrillance
            </div>
          )}
        </>
      )}
    </div>
  )
}
