import { useEffect, useRef } from 'react'
import { useBrainStore } from '../store/brain.store'
import type { Toast } from '../components/ToastProvider'

const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

function buildWsUrl(): string {
  // Si API_BASE est un chemin relatif (ex: '/api'), construire l'URL dynamiquement
  if (!API_BASE || API_BASE.startsWith('/')) {
    const proto = location.protocol === 'https:' ? 'wss' : 'ws'
    const base  = API_BASE || ''
    return `${proto}://${location.host}${base}/ws`
  }
  // Si API_BASE est une URL absolue (ex: 'http://localhost:3333/api')
  return API_BASE.replace(/^http/, 'ws') + '/ws'
}

const RECONNECT_DELAY_MS = 3000

type AddToast = (message: string, level: Toast['level'], context?: string) => void

export function useWebSocket(addToast?: AddToast) {
  const statusRef = useRef<'connecting' | 'connected' | 'disconnected'>('disconnected')

  useEffect(() => {
    if (USE_MOCK || !API_BASE) {
      useBrainStore.getState().setWsStatus('connected')
      return
    }

    const wsUrl = buildWsUrl()
    let ws: WebSocket | null = null
    let reconnectTimeout: ReturnType<typeof setTimeout> | null = null
    let destroyed = false

    const setStatus = (s: 'connecting' | 'connected' | 'disconnected') => {
      statusRef.current = s
      const storeStatus =
        s === 'connected'    ? 'connected' :
        s === 'connecting'   ? 'disconnected' :
        'disconnected'
      useBrainStore.getState().setWsStatus(storeStatus)
    }

    const connect = () => {
      if (destroyed) return
      setStatus('connecting')
      ws = new WebSocket(wsUrl)

      ws.onopen = () => {
        setStatus('connected')
      }

      ws.onmessage = (event) => {
        try {
          const msg = JSON.parse(event.data as string)
          const store = useBrainStore.getState()

          switch (msg.type) {
            case 'workflow:update':
              if (Array.isArray(msg.data?.workflows)) {
                store.setWorkflows(msg.data.workflows)
              } else if (msg.payload) {
                store.updateWorkflow(msg.payload)
              }
              break

            case 'log:line': {
              const project = msg.data?.project ?? msg.project ?? 'unknown'
              const line    = msg.data?.line    ?? msg.line    ?? ''
              if (line) {
                store.appendLogs(project, [{
                  ts:    new Date().toISOString(),
                  level: detectLevel(line),
                  msg:   line,
                }])
              }
              break
            }

            case 'ambient:event': {
              const context = msg.data?.context ?? msg.context ?? ''
              const message = msg.data?.message ?? msg.message ?? ''
              store.appendLogs('ambient', [{
                ts:    new Date().toISOString(),
                level: 'info',
                msg:   `[${context}] ${message}`,
              }])
              addToast?.(
                message,
                (msg.data?.level ?? msg.level) === 'warn' ? 'warn' : 'info',
                context || undefined,
              )
              break
            }

            case 'brain:updated': {
              const path = msg.data?.path ?? msg.path ?? ''
              console.log('brain:updated', path)
              addToast?.(`brain mis à jour : ${path}`, 'success')
              break
            }

            // Compatibilité avec l'ancien format gate:pending de useWorkflows
            case 'gate:pending': {
              const { workflowId, stepId } = msg.payload ?? {}
              if (workflowId && stepId) {
                store.appendLogs(workflowId, [{
                  ts:    new Date().toISOString(),
                  level: 'warn',
                  msg:   `Gate en attente — step ${stepId}`,
                }])
              }
              const step     = msg.payload?.stepId     ?? msg.data?.step     ?? ''
              const workflow = msg.payload?.workflowId ?? msg.data?.workflow ?? ''
              addToast?.(`Gate en attente : ${step} — ${workflow}`, 'warn')
              break
            }

            default:
              break
          }
        } catch {
          // message malformé — ignorer
        }
      }

      ws.onclose = () => {
        if (!destroyed) {
          setStatus('disconnected')
          reconnectTimeout = setTimeout(connect, RECONNECT_DELAY_MS)
        }
      }

      ws.onerror = () => {
        useBrainStore.getState().setWsStatus('error')
        ws?.close()
      }
    }

    connect()

    return () => {
      destroyed = true
      if (reconnectTimeout) clearTimeout(reconnectTimeout)
      ws?.close()
    }
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  return { status: statusRef.current }
}

// Détecte le niveau de log d'une ligne texte brute
function detectLevel(line: string): 'info' | 'warn' | 'error' | 'debug' {
  const upper = line.toUpperCase()
  if (upper.includes('ERROR') || upper.includes('ERR ') || upper.includes('FATAL')) return 'error'
  if (upper.includes('WARN'))  return 'warn'
  if (upper.includes('DEBUG')) return 'debug'
  return 'info'
}
