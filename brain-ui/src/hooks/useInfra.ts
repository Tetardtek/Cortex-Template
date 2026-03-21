import { useState, useEffect } from 'react'
import type { InfraService, InfraResponse } from '../types'

const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

const MOCK_SERVICES: InfraService[] = [
  { id: 'pm2-brain-engine',   name: 'brain-engine',       type: 'pm2',    status: 'online',  port: 7700, uptime: 3600000,  restarts: 0,  memory: 52428800, cpu: 0 },
  { id: 'pm2-tetardpg',       name: 'tetardpg',           type: 'pm2',    status: 'online',  port: 4000, uptime: 7200000,  restarts: 2,  memory: 97517568, cpu: 0 },
  { id: 'pm2-super-oauth',    name: 'super-oauth',        type: 'pm2',    status: 'online',  port: 3001, uptime: 18000000, restarts: 0,  memory: 94371840, cpu: 0 },
  { id: 'pm2-originsdigital', name: 'originsdigital',     type: 'pm2',    status: 'online',  port: 3002, uptime: 7200000,  restarts: 58, memory: 83886080, cpu: 0 },
  { id: 'apache',             name: 'Apache2',            type: 'system', status: 'online',  port: 443 },
  { id: 'brain-engine-info',  name: 'brain-engine',       type: 'info',   status: 'online',  port: 7700 },
  { id: 'gitea',              name: 'Gitea',              type: 'info',   status: 'online',  port: 3000 },
]

function formatUptime(ms: number | null | undefined): string {
  if (!ms) return '—'
  const s = Math.floor(ms / 1000)
  if (s < 60) return `${s}s`
  if (s < 3600) return `${Math.floor(s / 60)}m`
  if (s < 86400) return `${Math.floor(s / 3600)}h`
  return `${Math.floor(s / 86400)}j`
}

function formatMemory(bytes: number | null | undefined): string {
  if (!bytes) return '—'
  return `${Math.round(bytes / 1024 / 1024)}mb`
}

export function useInfra() {
  const [services, setServices] = useState<InfraService[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = async () => {
    setLoading(true)
    setError(null)

    if (USE_MOCK) {
      await new Promise(r => setTimeout(r, 300))
      setServices(MOCK_SERVICES)
      setLoading(false)
      return
    }

    try {
      const r = await fetch(`${API_BASE}/infra`, { credentials: 'include' })
      if (!r.ok) throw new Error(`HTTP ${r.status}`)
      const data: InfraResponse = await r.json()
      setServices(data.services)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Erreur')
      setServices(MOCK_SERVICES)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  return { services, loading, error, reload: load, formatUptime, formatMemory }
}
