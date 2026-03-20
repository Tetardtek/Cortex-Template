import { useState, useEffect, useRef, useCallback } from 'react'

interface PaletteCommand {
  id: string
  label: string
  description: string
  keywords: string[]
  action: () => void
}

interface CommandPaletteProps {
  onClose: () => void
  onNavigate: (view: string) => void
}

export default function CommandPalette({ onClose, onNavigate }: CommandPaletteProps) {
  const [query, setQuery] = useState('')
  const [selectedIdx, setSelectedIdx] = useState(0)
  const inputRef = useRef<HTMLInputElement>(null)

  const commands: PaletteCommand[] = [
    {
      id: 'workspace:open',
      label: 'Espace Workflow 3D',
      description: "Piloter les workflows dans l'espace",
      keywords: ['workspace', '3d', 'workflow', 'constellation', 'space'],
      action: () => { onNavigate('workspace'); onClose() },
    },
    {
      id: 'cosmos:open',
      label: 'Ouvrir Cosmos',
      description: 'Visualisation 3D du brain',
      keywords: ['cosmos', '3d', 'brain', 'visualisation', 'points', 'umap'],
      action: () => { onNavigate('cosmos'); onClose() },
    },
    {
      id: 'workflows:view',
      label: 'Workflows',
      description: 'Voir les workflows actifs',
      keywords: ['workflows', 'pipeline', 'tasks'],
      action: () => { onNavigate('workflows'); onClose() },
    },
    {
      id: 'builder:open',
      label: 'Nouveau workflow',
      description: 'Ouvrir le WorkflowBuilder',
      keywords: ['builder', 'nouveau', 'create', 'workflow', 'new'],
      action: () => { onNavigate('builder'); onClose() },
    },
    {
      id: 'secrets:view',
      label: 'Secrets',
      description: 'Gérer les secrets et tokens',
      keywords: ['secrets', 'tokens', 'keys', 'env'],
      action: () => { onNavigate('secrets'); onClose() },
    },
    {
      id: 'infra:view',
      label: 'Infra',
      description: 'Registre infrastructure',
      keywords: ['infra', 'infrastucture', 'servers', 'vps'],
      action: () => { onNavigate('infra'); onClose() },
    },
  ]

  const filtered = query.trim()
    ? commands.filter((cmd) => {
        const q = query.toLowerCase()
        return (
          cmd.label.toLowerCase().includes(q) ||
          cmd.description.toLowerCase().includes(q) ||
          cmd.keywords.some((kw) => kw.includes(q))
        )
      })
    : commands

  useEffect(() => {
    setSelectedIdx(0)
  }, [query])

  useEffect(() => {
    inputRef.current?.focus()
  }, [])

  const handleKeyDown = useCallback((e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      onClose()
    } else if (e.key === 'ArrowDown') {
      e.preventDefault()
      setSelectedIdx((i) => Math.min(i + 1, filtered.length - 1))
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      setSelectedIdx((i) => Math.max(i - 1, 0))
    } else if (e.key === 'Enter') {
      if (filtered[selectedIdx]) {
        filtered[selectedIdx].action()
      }
    }
  }, [filtered, selectedIdx, onClose])

  return (
    <div
      className="fixed inset-0 flex items-start justify-center"
      style={{ background: 'rgba(0,0,0,0.6)', zIndex: 100, paddingTop: 80 }}
      onClick={(e) => { if (e.target === e.currentTarget) onClose() }}
    >
      <div
        className="w-full rounded-lg overflow-hidden"
        style={{
          maxWidth: 512,
          background: '#1a1a1a',
          border: '1px solid #2a2a2a',
          boxShadow: '0 20px 60px rgba(0,0,0,0.5)',
        }}
        onKeyDown={handleKeyDown}
      >
        {/* Input */}
        <div style={{ borderBottom: '1px solid #2a2a2a' }}>
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Taper une commande..."
            className="w-full px-4 py-3 text-sm font-mono outline-none"
            style={{
              background: 'transparent',
              color: '#e5e7eb',
            }}
          />
        </div>

        {/* Commands list */}
        <div style={{ maxHeight: 320, overflowY: 'auto' }}>
          {filtered.length === 0 && (
            <div
              className="px-4 py-3 text-xs font-mono"
              style={{ color: '#4b5563' }}
            >
              Aucune commande trouvée
            </div>
          )}
          {filtered.map((cmd, idx) => (
            <button
              key={cmd.id}
              onClick={cmd.action}
              onMouseEnter={() => setSelectedIdx(idx)}
              className="w-full flex items-start gap-3 px-4 py-3 text-left"
              style={{
                background: idx === selectedIdx ? 'rgba(99,102,241,0.1)' : 'transparent',
                borderLeft: `2px solid ${idx === selectedIdx ? '#6366f1' : 'transparent'}`,
              }}
            >
              <div className="flex-1 min-w-0">
                <div
                  className="text-sm font-medium"
                  style={{ color: '#e5e7eb' }}
                >
                  {cmd.label}
                </div>
                <div
                  className="text-xs mt-0.5 font-mono"
                  style={{ color: '#6b7280' }}
                >
                  {cmd.description}
                </div>
              </div>
              <div
                className="text-xs font-mono flex-shrink-0 mt-0.5"
                style={{ color: '#4b5563' }}
              >
                {cmd.id}
              </div>
            </button>
          ))}
        </div>

        {/* Footer */}
        <div
          className="flex items-center gap-4 px-4 py-2"
          style={{ borderTop: '1px solid #2a2a2a', color: '#4b5563', fontSize: 10, fontFamily: 'monospace' }}
        >
          <span>↑↓ naviguer</span>
          <span>↵ exécuter</span>
          <span>Esc fermer</span>
        </div>
      </div>
    </div>
  )
}
