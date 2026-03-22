/**
 * DemoPreview — previews statiques read-only pour la vitrine template.
 * Données génériques, zéro dépendance aux hooks ou composants métier.
 * Affiché par TierGate quand VITE_DEMO_MODE=true + feature non disponible.
 */

import { CheckCircle2, AlertTriangle, XCircle, ChevronDown, ChevronRight } from 'lucide-react'
import { useState } from 'react'

// ─── Badge demo ──────────────────────────────────────────────────────────────

function DemoBadge() {
  return (
    <div style={{
      position: 'absolute', top: 16, right: 16, zIndex: 10,
      background: 'rgba(99,102,241,0.15)', border: '1px solid rgba(99,102,241,0.3)',
      borderRadius: 6, padding: '4px 10px',
      fontSize: 11, fontFamily: 'monospace', color: '#6366f1',
    }}>
      demo
    </div>
  )
}

// ─── Infra Preview ───────────────────────────────────────────────────────────

const DEMO_SERVICES = [
  { name: 'brain-engine',  type: 'pm2',    status: 'online',  port: 7700, uptime: '4d 12h', mem: '58 MB', restarts: 0 },
  { name: 'my-api',        type: 'pm2',    status: 'online',  port: 3000, uptime: '4d 12h', mem: '124 MB', restarts: 2 },
  { name: 'my-frontend',   type: 'pm2',    status: 'online',  port: 3001, uptime: '2d 6h',  mem: '42 MB', restarts: 0 },
  { name: 'nginx',         type: 'system', status: 'online',  port: 443,  uptime: '30d',    mem: '12 MB', restarts: 0 },
  { name: 'cron-backup',   type: 'system', status: 'stopped', port: null, uptime: '—',      mem: '—',     restarts: 0 },
]

const STATUS_DOT: Record<string, string> = {
  online: '#22c55e', stopped: '#6b7280', errored: '#ef4444', unknown: '#f59e0b',
}

const TYPE_BADGE: Record<string, { bg: string; color: string; label: string }> = {
  pm2:    { bg: 'rgba(99,102,241,0.15)',  color: '#6366f1', label: 'pm2' },
  system: { bg: 'rgba(34,197,94,0.15)',   color: '#22c55e', label: 'system' },
}

function DemoInfra() {
  return (
    <div style={{ padding: 24, maxWidth: 900, position: 'relative' }}>
      <DemoBadge />
      <div style={{ marginBottom: 24 }}>
        <h2 style={{ color: '#e5e7eb', fontSize: 18, fontWeight: 600, margin: 0 }}>InfraRegistry</h2>
        <p style={{ color: '#6b7280', fontSize: 12, margin: '4px 0 0', fontFamily: 'monospace' }}>
          {DEMO_SERVICES.length} services
        </p>
      </div>

      <div style={{ border: '1px solid #2a2a2a', borderRadius: 8, overflow: 'hidden' }}>
        <div style={{
          display: 'grid', gridTemplateColumns: '1fr 80px 80px 70px 70px 60px 60px',
          padding: '8px 16px', background: '#1a1a1a', borderBottom: '1px solid #2a2a2a',
          fontSize: 10, fontFamily: 'monospace', color: '#4b5563', textTransform: 'uppercase', letterSpacing: 1,
        }}>
          <span>Service</span><span>Type</span><span>Statut</span>
          <span>Port</span><span>Uptime</span><span>Mem</span><span>Restarts</span>
        </div>

        {DEMO_SERVICES.map((svc) => {
          const dot = STATUS_DOT[svc.status] ?? '#6b7280'
          const badge = TYPE_BADGE[svc.type] ?? TYPE_BADGE.system
          return (
            <div key={svc.name} style={{
              display: 'grid', gridTemplateColumns: '1fr 80px 80px 70px 70px 60px 60px',
              padding: '10px 16px', borderBottom: '1px solid #1a1a1a', alignItems: 'center', fontSize: 13,
            }}>
              <span style={{ color: '#e5e7eb', fontWeight: 500 }}>{svc.name}</span>
              <span style={{
                display: 'inline-block', padding: '2px 6px', borderRadius: 4,
                fontSize: 10, fontFamily: 'monospace', background: badge.bg, color: badge.color,
              }}>{badge.label}</span>
              <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                <span style={{ width: 7, height: 7, borderRadius: '50%', background: dot, flexShrink: 0 }} />
                <span style={{ color: dot, fontSize: 11, fontFamily: 'monospace' }}>{svc.status}</span>
              </span>
              <span style={{ color: '#6b7280', fontFamily: 'monospace', fontSize: 12 }}>{svc.port ?? '—'}</span>
              <span style={{ color: '#6b7280', fontFamily: 'monospace', fontSize: 12 }}>{svc.uptime}</span>
              <span style={{ color: '#6b7280', fontFamily: 'monospace', fontSize: 12 }}>{svc.mem}</span>
              <span style={{ color: '#6b7280', fontFamily: 'monospace', fontSize: 12 }}>{svc.restarts}</span>
            </div>
          )
        })}
      </div>
    </div>
  )
}

// ─── Secrets Preview ─────────────────────────────────────────────────────────

interface DemoSecret { key: string; label: string; status: 'filled' | 'empty' | 'missing' }
interface DemoSection { id: string; label: string; keys: DemoSecret[] }

const DEMO_SECTIONS: DemoSection[] = [
  {
    id: 'infra', label: 'Infrastructure',
    keys: [
      { key: 'VPS_SSH_KEY', label: 'Clé SSH serveur', status: 'filled' },
      { key: 'DOMAIN_API_KEY', label: 'API registrar', status: 'filled' },
    ],
  },
  {
    id: 'database', label: 'Database',
    keys: [
      { key: 'DB_PASSWORD', label: 'Mot de passe principal', status: 'filled' },
      { key: 'DB_REPLICA_PASSWORD', label: 'Mot de passe replica', status: 'empty' },
    ],
  },
  {
    id: 'auth', label: 'Authentification',
    keys: [
      { key: 'JWT_SECRET', label: 'Secret JWT', status: 'filled' },
      { key: 'OAUTH_CLIENT_SECRET', label: 'OAuth client secret', status: 'filled' },
      { key: 'SESSION_SECRET', label: 'Secret session', status: 'missing' },
    ],
  },
  {
    id: 'external', label: 'APIs externes',
    keys: [
      { key: 'STRIPE_SECRET_KEY', label: 'Stripe secret key', status: 'filled' },
      { key: 'SENDGRID_API_KEY', label: 'SendGrid API key', status: 'empty' },
    ],
  },
]

function StatusIcon({ status }: { status: DemoSecret['status'] }) {
  if (status === 'filled') return <CheckCircle2 size={14} className="text-emerald-400 shrink-0" />
  if (status === 'empty') return <AlertTriangle size={14} className="text-amber-400 shrink-0" />
  return <XCircle size={14} className="text-red-500 shrink-0" />
}

function statusLabel(status: DemoSecret['status']): string {
  if (status === 'filled') return 'remplie'
  if (status === 'empty') return 'vide'
  return 'manquante'
}

function DemoSectionCard({ section }: { section: DemoSection }) {
  const [open, setOpen] = useState(section.id === 'auth')
  const filledCount = section.keys.filter((k) => k.status === 'filled').length
  const total = section.keys.length
  const allFilled = filledCount === total
  const hasIssues = section.keys.some((k) => k.status === 'missing')

  return (
    <div className="rounded-lg border border-[#2a2a2a] bg-[#1a1a1a] overflow-hidden">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="w-full flex items-center gap-3 px-4 py-3 hover:bg-[#212121] transition-colors text-left"
      >
        <span className="text-gray-400">
          {open ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
        </span>
        <span className="font-semibold text-sm text-gray-100 flex-1">{section.label}</span>
        <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
          allFilled ? 'text-emerald-400 bg-emerald-400/10'
          : hasIssues ? 'text-red-400 bg-red-400/10'
          : 'text-amber-400 bg-amber-400/10'
        }`}>
          {filledCount}/{total}
        </span>
      </button>

      {open && (
        <div className="border-t border-[#2a2a2a] py-1">
          {section.keys.map((secret) => (
            <div key={secret.key} className="flex items-center gap-2 px-3 py-2 rounded-md">
              <StatusIcon status={secret.status} />
              <span className="flex-1 text-sm text-gray-300">{secret.label}</span>
              <span className="text-xs text-gray-600 font-mono">{secret.key}</span>
              <span className={`text-xs px-1.5 py-0.5 rounded font-medium ${
                secret.status === 'filled' ? 'text-emerald-400 bg-emerald-400/10'
                : secret.status === 'empty' ? 'text-amber-400 bg-amber-400/10'
                : 'text-red-400 bg-red-400/10'
              }`}>
                {statusLabel(secret.status)}
              </span>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}

function DemoSecrets() {
  return (
    <div style={{ padding: 24, position: 'relative' }}>
      <DemoBadge />
      <div className="space-y-3">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-base font-semibold text-gray-100">Secrets</h2>
          <p className="text-xs text-gray-500">Les valeurs ne sont jamais affichées en clair</p>
        </div>
        {DEMO_SECTIONS.map((section) => (
          <DemoSectionCard key={section.id} section={section} />
        ))}
      </div>
    </div>
  )
}

// ─── Workflows Preview ───────────────────────────────────────────────────────

interface DemoStep { label: string; status: string; isGate?: boolean }
interface DemoWorkflow { name: string; steps: DemoStep[] }

const DEMO_WORKFLOWS: DemoWorkflow[] = [
  {
    name: 'Deploy Production',
    steps: [
      { label: 'Build', status: 'done' },
      { label: 'Tests', status: 'done' },
      { label: 'Review', status: 'in-progress', isGate: true },
      { label: 'Deploy', status: 'pending', isGate: true },
    ],
  },
  {
    name: 'Feature Sprint',
    steps: [
      { label: 'INIT', status: 'done' },
      { label: 'Backend API', status: 'done' },
      { label: 'Frontend UI', status: 'in-progress' },
      { label: 'Integration', status: 'pending' },
      { label: 'Ship', status: 'pending', isGate: true },
    ],
  },
]

const STATUS_COLORS: Record<string, { bg: string; dot: string; text: string }> = {
  done:          { bg: 'rgba(34,197,94,0.1)',   dot: '#22c55e', text: '#22c55e' },
  'in-progress': { bg: 'rgba(99,102,241,0.1)',  dot: '#6366f1', text: '#6366f1' },
  pending:       { bg: 'rgba(107,114,128,0.08)', dot: '#4b5563', text: '#4b5563' },
  gate:          { bg: 'rgba(245,158,11,0.1)',   dot: '#f59e0b', text: '#f59e0b' },
  blocked:       { bg: 'rgba(107,114,128,0.08)', dot: '#6b7280', text: '#6b7280' },
}

function DemoWorkflows() {
  return (
    <div style={{ padding: 24, position: 'relative', height: '100%' }}>
      <DemoBadge />
      <h2 style={{ color: '#e5e7eb', fontSize: 18, fontWeight: 600, margin: '0 0 24px' }}>Workflows</h2>

      <div style={{ display: 'flex', gap: 32 }}>
        {DEMO_WORKFLOWS.map((wf) => (
          <div key={wf.name} style={{ flex: 1, maxWidth: 280 }}>
            <div style={{
              fontSize: 12, fontWeight: 600, color: '#9ca3af', letterSpacing: 0.5,
              marginBottom: 16, textTransform: 'uppercase',
            }}>
              {wf.name}
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {wf.steps.map((step, i) => {
                const colors = STATUS_COLORS[step.status] ?? STATUS_COLORS.pending
                return (
                  <div key={i}>
                    {/* Connector line */}
                    {i > 0 && (
                      <div style={{
                        width: 2, height: 12, marginLeft: 18,
                        background: step.status === 'done' ? '#22c55e33' : '#2a2a2a',
                      }} />
                    )}

                    {/* Step card */}
                    <div style={{
                      display: 'flex', alignItems: 'center', gap: 10,
                      padding: '10px 14px', borderRadius: 8,
                      background: colors.bg,
                      border: `1px solid ${step.status === 'in-progress' ? 'rgba(99,102,241,0.3)' : '#2a2a2a'}`,
                    }}>
                      {step.isGate ? (
                        <span style={{
                          width: 10, height: 10, transform: 'rotate(45deg)',
                          background: colors.dot, flexShrink: 0,
                        }} />
                      ) : (
                        <span style={{
                          width: 8, height: 8, borderRadius: '50%',
                          background: colors.dot, flexShrink: 0,
                        }} />
                      )}
                      <span style={{ flex: 1, fontSize: 13, color: '#e5e7eb', fontWeight: 500 }}>
                        {step.label}
                      </span>
                      <span style={{ fontSize: 10, fontFamily: 'monospace', color: colors.text }}>
                        {step.status}
                      </span>
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

// ─── Export ───────────────────────────────────────────────────────────────────

const DEMO_COMPONENTS: Record<string, () => JSX.Element> = {
  infra: DemoInfra,
  secrets: DemoSecrets,
  workflows: DemoWorkflows,
}

export default function DemoPreview({ feature }: { feature: string }) {
  const Component = DEMO_COMPONENTS[feature]

  if (!Component) {
    return (
      <div className="flex flex-col items-center justify-center h-full" style={{ color: '#4b5563' }}>
        <div className="text-3xl mb-3">👀</div>
        <div className="text-sm font-medium">Aperçu bientôt disponible</div>
        <div className="text-xs mt-1 font-mono" style={{ color: '#374151' }}>{feature}</div>
      </div>
    )
  }

  return <Component />
}
