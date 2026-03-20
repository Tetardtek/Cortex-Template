import { useEffect } from 'react'
import { MOCK_WORKFLOWS } from '../components/WorkflowBoard'
import { useBrainStore } from '../store/brain.store'

const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

export function useWorkflows() {
  const workflows    = useBrainStore((s) => s.workflows)
  const wsStatus     = useBrainStore((s) => s.wsStatus)
  const setWorkflows = useBrainStore((s) => s.setWorkflows)
  const setWsStatus  = useBrainStore((s) => s.setWsStatus)

  useEffect(() => {
    if (USE_MOCK || !API_BASE) {
      setWorkflows(MOCK_WORKFLOWS)
      setWsStatus('connected')
      return
    }

    // Fetch initial
    const token = import.meta.env.VITE_BRAIN_TOKEN ?? ''
    const headers: Record<string, string> = token ? { Authorization: `Bearer ${token}` } : {}

    fetch(`${API_BASE}/workflows`, { credentials: 'include', headers })
      .then((r) => r.json())
      .then((data) => setWorkflows(data))
      .catch(() => setWorkflows(MOCK_WORKFLOWS))

    return () => {}
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  return { workflows, wsStatus }
}
