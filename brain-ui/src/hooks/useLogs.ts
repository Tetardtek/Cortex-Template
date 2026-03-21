import { useEffect, useRef } from 'react'
import { useBrainStore, LogLine } from '../store/brain.store'

const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

const MOCK_LINES: LogLine[] = [
  { ts: new Date().toISOString(), level: 'info',  msg: '[mock] workflow started' },
  { ts: new Date().toISOString(), level: 'debug', msg: '[mock] step INIT — done' },
  { ts: new Date().toISOString(), level: 'warn',  msg: '[mock] gate pending — awaiting approval' },
]

export function useLogs(project: string, active: boolean) {
  const logs       = useBrainStore((s) => s.logs[project] ?? [])
  const appendLogs = useBrainStore((s) => s.appendLogs)
  const lastTsRef  = useRef<string>('')

  useEffect(() => {
    if (!active) return

    if (USE_MOCK) {
      appendLogs(project, MOCK_LINES)
      return
    }

    const poll = async () => {
      try {
        const since = lastTsRef.current ? `?since=${encodeURIComponent(lastTsRef.current)}` : ''
        const r = await fetch(`${API_BASE}/logs/${encodeURIComponent(project)}${since}`, {
          credentials: 'include',
        })
        if (!r.ok) return
        const data = await r.json()
        const lines: LogLine[] = data.lines ?? []
        if (lines.length > 0) {
          lastTsRef.current = lines[lines.length - 1].ts
          appendLogs(project, lines)
        }
      } catch {
        // réseau — on ignore
      }
    }

    poll()
    const interval = setInterval(poll, 2000)
    return () => clearInterval(interval)
  }, [project, active]) // eslint-disable-line react-hooks/exhaustive-deps

  return logs
}
