import { useState, useCallback } from 'react'
import { ChevronDown, ChevronRight, Eye, EyeOff, RefreshCw, Save, CheckCircle2, AlertTriangle, XCircle } from 'lucide-react'

export interface SecretKey {
  key: string
  label: string
  status: 'filled' | 'empty' | 'missing'
  canGenerate?: boolean
}

export interface SecretSection {
  id: string
  label: string
  keys: SecretKey[]
}

interface SecretsZoneProps {
  sections: SecretSection[]
  onSecretSave: (section: string, key: string, value: string) => void
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function generateSecret(length = 48): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()-_=+'
  return Array.from({ length }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
}

function StatusIcon({ status }: { status: SecretKey['status'] }) {
  if (status === 'filled')
    return <CheckCircle2 size={14} className="text-emerald-400 shrink-0" />
  if (status === 'empty')
    return <AlertTriangle size={14} className="text-amber-400 shrink-0" />
  return <XCircle size={14} className="text-red-500 shrink-0" />
}

function statusLabel(status: SecretKey['status']): string {
  if (status === 'filled') return 'remplie'
  if (status === 'empty') return 'vide'
  return 'manquante'
}

// ---------------------------------------------------------------------------
// SecretRow
// ---------------------------------------------------------------------------

interface SecretRowProps {
  sectionId: string
  secret: SecretKey
  onSave: (section: string, key: string, value: string) => void
}

function SecretRow({ sectionId, secret, onSave }: SecretRowProps) {
  const [editing, setEditing] = useState(false)
  const [value, setValue] = useState('')
  const [showValue, setShowValue] = useState(false)
  const [saved, setSaved] = useState(false)

  const handleGenerate = useCallback(() => {
    setValue(generateSecret())
    setEditing(true)
    setShowValue(false)
  }, [])

  const handleSave = useCallback(() => {
    if (!value.trim()) return
    onSave(sectionId, secret.key, value)
    setValue('')
    setShowValue(false)
    setEditing(false)
    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
  }, [value, sectionId, secret.key, onSave])

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLInputElement>) => {
      if (e.key === 'Enter') handleSave()
      if (e.key === 'Escape') {
        setValue('')
        setEditing(false)
        setShowValue(false)
      }
    },
    [handleSave],
  )

  return (
    <div className="group">
      {/* Row header */}
      <div
        className="flex items-center gap-2 px-3 py-2 rounded-md cursor-pointer hover:bg-[#242424] transition-colors"
        onClick={() => !editing && setEditing(true)}
      >
        <StatusIcon status={saved ? 'filled' : secret.status} />
        <span className="flex-1 text-sm text-gray-300">{secret.label}</span>
        <span className="text-xs text-gray-600 font-mono">{secret.key}</span>
        <span
          className={`text-xs px-1.5 py-0.5 rounded font-medium ${
            saved
              ? 'text-emerald-400 bg-emerald-400/10'
              : secret.status === 'filled'
              ? 'text-emerald-400 bg-emerald-400/10'
              : secret.status === 'empty'
              ? 'text-amber-400 bg-amber-400/10'
              : 'text-red-400 bg-red-400/10'
          }`}
        >
          {saved ? 'sauvegardée' : statusLabel(secret.status)}
        </span>
      </div>

      {/* Inline edit */}
      {editing && (
        <div className="mx-3 mb-2 p-3 rounded-md bg-[#141414] border border-[#2a2a2a] space-y-2">
          <div className="flex items-center gap-2">
            <div className="relative flex-1">
              <input
                type={showValue ? 'text' : 'password'}
                value={value}
                onChange={(e) => setValue(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder={`Valeur pour ${secret.key}`}
                autoFocus
                className="w-full bg-[#1a1a1a] border border-[#2a2a2a] rounded px-3 py-1.5 text-sm text-gray-200 placeholder-gray-600 focus:outline-none focus:border-[#6366f1] pr-9 font-mono"
              />
              <button
                type="button"
                onClick={() => setShowValue((v) => !v)}
                className="absolute right-2 top-1/2 -translate-y-1/2 text-gray-500 hover:text-gray-300 transition-colors"
                title={showValue ? 'Masquer' : 'Afficher'}
              >
                {showValue ? <EyeOff size={14} /> : <Eye size={14} />}
              </button>
            </div>

            {secret.canGenerate && (
              <button
                type="button"
                onClick={handleGenerate}
                className="flex items-center gap-1 px-2 py-1.5 rounded text-xs text-indigo-400 border border-indigo-400/30 hover:bg-indigo-400/10 transition-colors whitespace-nowrap"
                title="Générer un secret aléatoire"
              >
                <RefreshCw size={12} />
                Générer
              </button>
            )}

            <button
              type="button"
              onClick={handleSave}
              disabled={!value.trim()}
              className="flex items-center gap-1 px-2 py-1.5 rounded text-xs text-emerald-400 border border-emerald-400/30 hover:bg-emerald-400/10 transition-colors disabled:opacity-40 disabled:cursor-not-allowed whitespace-nowrap"
            >
              <Save size={12} />
              Sauvegarder
            </button>
          </div>

          <p className="text-xs text-gray-600">
            La valeur ne sera jamais affichée en clair après sauvegarde. Appuyez sur Échap pour annuler.
          </p>
        </div>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// SectionCard
// ---------------------------------------------------------------------------

interface SectionCardProps {
  section: SecretSection
  onSave: (section: string, key: string, value: string) => void
}

function SectionCard({ section, onSave }: SectionCardProps) {
  const [open, setOpen] = useState(false)

  const filledCount = section.keys.filter((k) => k.status === 'filled').length
  const total = section.keys.length
  const allFilled = filledCount === total
  const hasIssues = section.keys.some((k) => k.status === 'missing')

  return (
    <div className="rounded-lg border border-[#2a2a2a] bg-[#1a1a1a] overflow-hidden">
      {/* Header */}
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center gap-3 px-4 py-3 hover:bg-[#212121] transition-colors text-left"
      >
        <span className="text-gray-400">
          {open ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
        </span>

        <span className="font-semibold text-sm text-gray-100 flex-1">{section.label}</span>

        {/* Progress pill */}
        <span
          className={`text-xs px-2 py-0.5 rounded-full font-medium ${
            allFilled
              ? 'text-emerald-400 bg-emerald-400/10'
              : hasIssues
              ? 'text-red-400 bg-red-400/10'
              : 'text-amber-400 bg-amber-400/10'
          }`}
        >
          {filledCount}/{total}
        </span>
      </button>

      {/* Body */}
      {open && (
        <div className="border-t border-[#2a2a2a] py-1">
          {section.keys.map((secret) => (
            <SecretRow key={secret.key} sectionId={section.id} secret={secret} onSave={onSave} />
          ))}
        </div>
      )}
    </div>
  )
}

// ---------------------------------------------------------------------------
// SecretsZone (root)
// ---------------------------------------------------------------------------

export const MOCK_SECTIONS: SecretSection[] = [
  {
    id: 'brain',
    label: 'BRAIN',
    keys: [
      { key: 'BRAIN_TOKEN_READ', label: 'Token lecture', status: 'filled' },
      { key: 'BRAIN_TOKEN_WRITE', label: 'Token écriture', status: 'filled' },
      { key: 'BRAIN_SERVEUR_SECRET', label: 'Secret serveur', status: 'empty', canGenerate: true },
    ],
  },
  {
    id: 'vps',
    label: 'VPS',
    keys: [
      { key: 'VPS_IP', label: 'IP du VPS', status: 'filled' },
      { key: 'VPS_USER', label: 'Utilisateur SSH', status: 'filled' },
    ],
  },
  {
    id: 'mysql',
    label: 'MySQL',
    keys: [
      { key: 'MYSQL_ROOT_PASSWORD', label: 'Mot de passe root', status: 'empty', canGenerate: true },
    ],
  },
  {
    id: 'tetardpg',
    label: 'TetaRdPG',
    keys: [
      { key: 'TETARDPG_DATABASE_URL', label: 'Database URL', status: 'missing' },
      { key: 'TETARDPG_TWITCH_WEBHOOK_SECRET', label: 'Twitch Webhook Secret', status: 'missing', canGenerate: true },
      { key: 'TETARDPG_COOKIE_SECRET', label: 'Cookie Secret', status: 'missing', canGenerate: true },
    ],
  },
  {
    id: 'originsdigital',
    label: 'OriginsDigital',
    keys: [
      { key: 'ORIGINSDIGITAL_DB_PASSWORD', label: 'DB Password', status: 'empty', canGenerate: true },
      { key: 'ORIGINSDIGITAL_JWT_SECRET', label: 'JWT Secret', status: 'missing', canGenerate: true },
    ],
  },
]

export default function SecretsZone({ sections, onSecretSave }: SecretsZoneProps) {
  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-base font-semibold text-gray-100">Secrets</h2>
        <p className="text-xs text-gray-500">Les valeurs ne sont jamais affichées en clair</p>
      </div>

      {sections.map((section) => (
        <SectionCard key={section.id} section={section} onSave={onSecretSave} />
      ))}
    </div>
  )
}
