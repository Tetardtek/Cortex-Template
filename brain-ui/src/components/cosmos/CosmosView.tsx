import { useState, useMemo, useEffect, useRef, useCallback } from 'react'

function checkWebGL(): boolean {
  try {
    const canvas = document.createElement('canvas')
    return !!(canvas.getContext('webgl') || canvas.getContext('experimental-webgl'))
  } catch { return false }
}
import { useCosmosData } from '../../hooks/useCosmosData'
import { CosmosScene } from './CosmosScene'
import { CosmosControls } from './CosmosControls'
import { CosmosInfoPanel } from './CosmosInfoPanel'
import { CosmosMetrics } from './CosmosMetrics'
import type { CosmosPoint, ZoneKey } from '../../types'

type ZoneFilter = 'all' | ZoneKey

function NoWebGL() {
  return (
    <div className="flex flex-col items-center justify-center h-full" style={{ background: '#080808' }}>
      <div className="text-3xl mb-3">🖥️</div>
      <div style={{ color: '#ef4444' }} className="text-sm font-mono mb-1">WebGL non disponible</div>
      <div style={{ color: '#4b5563' }} className="text-xs text-center max-w-xs">
        Active l'accélération matérielle dans Chrome : Paramètres → Système → Utiliser l'accélération matérielle
      </div>
    </div>
  )
}

function CosmosInner() {
  const { points, loading, error, generatedAt, reload } = useCosmosData()

  const [selectedPoint, setSelectedPoint] = useState<CosmosPoint | null>(null)
  const [activeZone, setActiveZone] = useState<ZoneFilter>('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [highlightedIds, setHighlightedIds] = useState<Set<string>>(new Set())
  const [isFullscreen, setIsFullscreen] = useState(false)
  const [isHeatmap, setIsHeatmap] = useState(false)
  const containerRef = useRef<HTMLDivElement>(null)

  const toggleFullscreen = useCallback(() => {
    if (!document.fullscreenElement) {
      containerRef.current?.requestFullscreen()
    } else {
      document.exitFullscreen()
    }
  }, [])

  useEffect(() => {
    const onFsChange = () => setIsFullscreen(!!document.fullscreenElement)
    document.addEventListener('fullscreenchange', onFsChange)
    return () => document.removeEventListener('fullscreenchange', onFsChange)
  }, [])

  const filteredPoints = useMemo(() => {
    if (!searchQuery.trim()) return points
    const q = searchQuery.toLowerCase()
    const matched = points.filter(
      (p) => p.label.toLowerCase().includes(q) || p.path.toLowerCase().includes(q)
    )
    return points.map((p) => p) // keep all points but highlight matched
  }, [points, searchQuery])

  const searchHighlightedIds = useMemo(() => {
    if (!searchQuery.trim()) return new Set<string>()
    const q = searchQuery.toLowerCase()
    return new Set(
      points
        .filter((p) => p.label.toLowerCase().includes(q) || p.path.toLowerCase().includes(q))
        .map((p) => p.id)
    )
  }, [points, searchQuery])

  const effectiveHighlightedIds = useMemo(() => {
    if (highlightedIds.size > 0) return highlightedIds
    return searchHighlightedIds
  }, [highlightedIds, searchHighlightedIds])

  const handlePointClick = (point: CosmosPoint) => {
    setSelectedPoint(point)
    setHighlightedIds(new Set())
  }

  const handleSearchChange = (query: string) => {
    setSearchQuery(query)
    setHighlightedIds(new Set())
    if (!query.trim()) setSelectedPoint(null)
  }

  return (
    <div
      ref={containerRef}
      style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', background: '#080808' }}
    >
      <CosmosControls
        activeZone={activeZone}
        searchQuery={searchQuery}
        onZoneChange={setActiveZone}
        onSearchChange={handleSearchChange}
        isFullscreen={isFullscreen}
        onToggleFullscreen={toggleFullscreen}
        isHeatmap={isHeatmap}
        onToggleHeatmap={() => setIsHeatmap((v) => !v)}
      />

      <div style={{ position: 'relative', flex: 1, minHeight: 0, overflow: 'hidden' }}>
        {/* Canvas 3D — toujours monté si on a des données (caméra + état préservés au reload) */}
        {!error && filteredPoints.length > 0 && (
          <CosmosScene
            points={filteredPoints}
            activeZone={activeZone}
            highlightedIds={effectiveHighlightedIds}
            onPointClick={handlePointClick}
            heatmap={isHeatmap}
          />
        )}

        {/* Loading overlay — par-dessus la scène, ne la démonte pas */}
        {loading && (
          <div
            className="absolute inset-0 flex flex-col items-center justify-center"
            style={{ background: filteredPoints.length > 0 ? 'rgba(8,8,8,0.75)' : '#080808', zIndex: 10 }}
          >
            <div className="text-2xl mb-3">🌌</div>
            <div style={{ color: '#6366f1' }} className="text-sm font-mono">
              {filteredPoints.length > 0 ? 'Mise à jour UMAP…' : 'Projection UMAP en cours…'}
            </div>
            {filteredPoints.length === 0 && (
              <div style={{ color: '#4b5563' }} className="text-xs mt-2">
                Peut prendre jusqu'à 30s lors de la première génération
              </div>
            )}
          </div>
        )}

        {/* Error overlay */}
        {!loading && error && (
          <div
            className="absolute inset-0 flex flex-col items-center justify-center"
            style={{ background: '#080808' }}
          >
            <div style={{ color: '#ef4444' }} className="text-sm font-mono mb-2">
              Erreur : {error}
            </div>
            <button
              onClick={reload}
              style={{ background: '#1a1a1a', color: '#e5e7eb', border: '1px solid #2a2a2a' }}
              className="text-xs px-3 py-1.5 rounded mt-2"
            >
              Réessayer
            </button>
          </div>
        )}

        {/* Info panel */}
        <CosmosInfoPanel
          point={selectedPoint}
          allPoints={points}
          onClose={() => setSelectedPoint(null)}
          onHighlightNeighbors={setHighlightedIds}
          highlightedIds={highlightedIds}
        />
      </div>

      <CosmosMetrics
        points={points}
        generatedAt={generatedAt}
        onReload={reload}
        loading={loading}
      />
    </div>
  )
}

export default function CosmosView() {
  if (!checkWebGL()) return <NoWebGL />
  return <CosmosInner />
}
