import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
  type ReactNode,
} from 'react'

// ─── Types ───────────────────────────────────────────────────────────────────

export interface Toast {
  id:       string
  message:  string
  level:    'info' | 'warn' | 'error' | 'success'
  context?: string
}

interface ToastContextValue {
  addToast: (message: string, level: Toast['level'], context?: string) => void
}

// ─── Context ─────────────────────────────────────────────────────────────────

const ToastContext = createContext<ToastContextValue | null>(null)

// ─── Level → border color ────────────────────────────────────────────────────

const LEVEL_COLOR: Record<Toast['level'], string> = {
  info:    '#6366f1',
  warn:    '#f59e0b',
  error:   '#ef4444',
  success: '#22c55e',
}

const DISMISS_DELAY: Record<Toast['level'], number> = {
  info:    4000,
  success: 4000,
  warn:    7000,
  error:   7000,
}

const MAX_VISIBLE = 4

// ─── ToastItem ────────────────────────────────────────────────────────────────

interface ToastItemProps {
  toast:     Toast
  onDismiss: (id: string) => void
}

function ToastItem({ toast, onDismiss }: ToastItemProps) {
  const [visible, setVisible] = useState(false)

  // Slide-in on mount
  useEffect(() => {
    const raf = requestAnimationFrame(() => setVisible(true))
    return () => cancelAnimationFrame(raf)
  }, [])

  const handleDismiss = () => {
    setVisible(false)
    setTimeout(() => onDismiss(toast.id), 220)
  }

  const borderColor = LEVEL_COLOR[toast.level]

  return (
    <div
      style={{
        background:   '#0a0a0a',
        border:       `1px solid ${borderColor}`,
        borderRadius: 6,
        padding:      '10px 14px',
        minWidth:     280,
        maxWidth:     380,
        fontFamily:   'monospace',
        fontSize:     12,
        color:        '#e5e7eb',
        display:      'flex',
        alignItems:   'flex-start',
        gap:          8,
        boxShadow:    '0 4px 16px rgba(0,0,0,0.6)',
        transform:    visible ? 'translateX(0)' : 'translateX(110%)',
        transition:   'transform 200ms ease, opacity 200ms ease',
        opacity:      visible ? 1 : 0,
        cursor:       'default',
      }}
    >
      {/* Level dot */}
      <span
        style={{
          width:        8,
          height:       8,
          borderRadius: '50%',
          background:   borderColor,
          flexShrink:   0,
          marginTop:    3,
        }}
      />

      {/* Content */}
      <div style={{ flex: 1, lineHeight: 1.5 }}>
        {toast.context && (
          <span style={{ color: borderColor, marginRight: 6, fontSize: 10 }}>
            [{toast.context}]
          </span>
        )}
        {toast.message}
      </div>

      {/* Dismiss button */}
      <button
        onClick={handleDismiss}
        aria-label="Fermer"
        style={{
          background:   'transparent',
          border:       'none',
          color:        '#4b5563',
          cursor:       'pointer',
          fontSize:     14,
          lineHeight:   1,
          padding:      0,
          flexShrink:   0,
        }}
      >
        ✕
      </button>
    </div>
  )
}

// ─── ToastProvider ────────────────────────────────────────────────────────────

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])
  const timersRef = useRef<Map<string, ReturnType<typeof setTimeout>>>(new Map())

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id))
    const timer = timersRef.current.get(id)
    if (timer !== undefined) {
      clearTimeout(timer)
      timersRef.current.delete(id)
    }
  }, [])

  const addToast = useCallback(
    (message: string, level: Toast['level'], context?: string) => {
      const id = Date.now().toString()
      const toast: Toast = { id, message, level, context }

      setToasts((prev) => {
        const next = [...prev, toast]
        // Keep only the last MAX_VISIBLE toasts
        return next.slice(-MAX_VISIBLE)
      })

      const delay = DISMISS_DELAY[level]
      const timer = setTimeout(() => removeToast(id), delay)
      timersRef.current.set(id, timer)
    },
    [removeToast],
  )

  // Cleanup all timers on unmount
  useEffect(() => {
    const timers = timersRef.current
    return () => {
      timers.forEach((timer) => clearTimeout(timer))
      timers.clear()
    }
  }, [])

  return (
    <ToastContext.Provider value={{ addToast }}>
      {children}

      {/* Toast container */}
      <div
        style={{
          position:      'fixed',
          bottom:        16,
          right:         16,
          zIndex:        100,
          display:       'flex',
          flexDirection: 'column',
          gap:           8,
          pointerEvents: 'none',
        }}
      >
        {toasts.map((toast) => (
          <div key={toast.id} style={{ pointerEvents: 'auto' }}>
            <ToastItem toast={toast} onDismiss={removeToast} />
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}

// ─── useToast ─────────────────────────────────────────────────────────────────

export function useToast(): ToastContextValue {
  const ctx = useContext(ToastContext)
  if (!ctx) {
    throw new Error('useToast must be used inside <ToastProvider>')
  }
  return ctx
}
