import { useState, useEffect, useCallback } from 'react'
import type { CosmosPoint, VisualizeResponse, ZoneKey } from '../types'

const CACHE_TTL_MS = 30 * 60 * 1000
const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

interface CosmosCache {
  timestamp: number
  points: CosmosPoint[]
  generated_at: string
  umap_params: VisualizeResponse['umap_params']
}

const MOCK_ZONES: ZoneKey[] = ['public', 'kernel', 'instance', 'satellite']

function generateMockPoints(): CosmosPoint[] {
  return Array.from({ length: 50 }, (_, i) => {
    const zone = MOCK_ZONES[i % 4]
    return {
      id: `mock-${i}`,
      path: `${zone}/document-${i}.md`,
      zone,
      label: `Document ${i}`,
      excerpt: `Extrait du document ${i} — contenu de démonstration pour la visualisation Cosmos Sprint 4.`,
      x: (Math.random() - 0.5) * 4,
      y: (Math.random() - 0.5) * 4,
      z: (Math.random() - 0.5) * 4,
    }
  })
}

export function useCosmosData() {
  const [points, setPoints] = useState<CosmosPoint[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [generatedAt, setGeneratedAt] = useState<string | null>(null)
  const [cached, setCached] = useState(false)

  const cacheKey = `cosmos_cache_${Math.floor(Date.now() / CACHE_TTL_MS)}`

  const load = useCallback(async (force = false) => {
    setLoading(true)
    setError(null)

    if (USE_MOCK || !API_BASE) {
      await new Promise((r) => setTimeout(r, 400))
      setPoints(generateMockPoints())
      setGeneratedAt(new Date().toISOString())
      setCached(false)
      setLoading(false)
      return
    }

    if (!force) {
      const raw = localStorage.getItem(cacheKey)
      if (raw) {
        try {
          const parsed: CosmosCache = JSON.parse(raw)
          if (Date.now() - parsed.timestamp < CACHE_TTL_MS) {
            setPoints(parsed.points)
            setGeneratedAt(parsed.generated_at)
            setCached(true)
            setLoading(false)
            return
          }
        } catch {
          localStorage.removeItem(cacheKey)
        }
      }
    }

    try {
      const token = import.meta.env.VITE_BRAIN_TOKEN ?? ''
      const headers: Record<string, string> = token ? { Authorization: `Bearer ${token}` } : {}
      const url = force ? `${API_BASE}/visualize?force=true` : `${API_BASE}/visualize`
      const res = await fetch(url, { credentials: 'include', headers })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const data: VisualizeResponse = await res.json()

      setPoints(data.points)
      setGeneratedAt(data.generated_at)
      setCached(data.cached)

      const cachePayload: CosmosCache = {
        timestamp: Date.now(),
        points: data.points,
        generated_at: data.generated_at,
        umap_params: data.umap_params,
      }
      localStorage.setItem(cacheKey, JSON.stringify(cachePayload))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur inconnue')
    } finally {
      setLoading(false)
    }
  }, [cacheKey])

  useEffect(() => {
    load()
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  return { points, loading, error, generatedAt, cached, reload: () => load(true) }
}
