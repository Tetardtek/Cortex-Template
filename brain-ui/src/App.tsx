import { useState, useEffect, Suspense, lazy } from 'react'
import Dashboard from './components/Dashboard'
import WorkflowBoard from './components/WorkflowBoard'
import SecretsZone, { MOCK_SECTIONS } from './components/SecretsZone'
import GatesDrawer from './components/GatesDrawer'
import GateDrawer from './components/GateDrawer'
import LogDrawer from './components/LogDrawer'
import CommandPalette from './components/CommandPalette'
import TierGate from './components/TierGate'
import InfraRegistry from './components/InfraRegistry'
import { ToastProvider, useToast } from './components/ToastProvider'
import { useWorkflows } from './hooks/useWorkflows'
import { useWebSocket } from './hooks/useWebSocket'
import { useBrainStore } from './store/brain.store'
import { useTier } from './hooks/useTier'

const CosmosView = lazy(() => import('./components/cosmos/CosmosView'))
const WorkspaceView = lazy(() => import('./components/workspace/WorkspaceView'))
const DocsView = lazy(() => import('./components/DocsView'))

type ActiveView = 'dashboard' | 'cosmos' | 'workflows' | 'secrets' | 'infra' | 'workspace'

interface NavItem {
  id: ActiveView
  icon: string
  label: string
  separator?: boolean
}

interface PendingGate {
  workflowId: string
  stepId:     string
  stepLabel:  string
}

const NAV_ITEMS: NavItem[] = [
  { id: 'dashboard', icon: '⬡',  label: 'Dashboard' },
  { id: 'cosmos',    icon: '🌌', label: 'Cosmos'    },
  { id: 'workflows', icon: '🔀', label: 'Workflows', separator: true },
  { id: 'infra',     icon: '🖥️', label: 'Infra'     },
  { id: 'secrets',   icon: '🔑', label: 'Secrets'   },
]

function AppInner() {
  const { addToast } = useToast()

  // Detect URL path for direct routing (/ui/docs → docs view)
  const initialView = (): ActiveView => {
    const path = window.location.pathname
    if (path.includes('/cosmos')) return 'cosmos'
    if (path.includes('/workspace')) return 'workspace'
    return 'dashboard'
  }
  const [activeView, setActiveView] = useState<ActiveView>(initialView)
  const [pendingGate, setPendingGate] = useState<PendingGate | null>(null)
  const [gateDrawer, setGateDrawer] = useState<{ open: boolean; workflowId: string | null; stepId: string | null }>({
    open:       false,
    workflowId: null,
    stepId:     null,
  })
  const [logsProject, setLogsProject] = useState<string | null>(null)
  const [paletteOpen, setPaletteOpen] = useState(false)

  // Sync URL with active view
  const handleViewChange = (view: ActiveView) => {
    setActiveView(view)
    const base = import.meta.env.BASE_URL || '/ui/'
    const slug = view === 'workflows' ? '' : view
    window.history.replaceState(null, '', `${base}${slug}`)
  }

  const { workflows, wsStatus } = useWorkflows()
  useWebSocket(addToast)
  const storeWorkflows = useBrainStore((s) => s.workflows)
  const { hasFeature, tierInfo } = useTier()

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault()
        setPaletteOpen(true)
      }
      if ((e.metaKey || e.ctrlKey) && e.key === 'l') {
        e.preventDefault()
        setLogsProject((prev) => (prev ? null : (storeWorkflows[0]?.id ?? null)))
      }
    }
    window.addEventListener('keydown', handler)
    return () => window.removeEventListener('keydown', handler)
  }, [storeWorkflows])

  const handleGateApprove = (workflowId: string, stepId: string) => {
    const wf    = storeWorkflows.find((w) => w.id === workflowId)
    const step  = wf?.steps.find((s) => s.id === stepId)
    const label = step?.label ?? stepId
    setPendingGate({ workflowId, stepId, stepLabel: label })
    setGateDrawer({ open: true, workflowId, stepId })
  }

  const handleSecretSave = (section: string, key: string, value: string) => {
    console.log(`secret:save — ${section}.${key} (${value.length} chars)`)
    // TODO: appel API brain
  }

  return (
    <div className="flex h-screen w-screen overflow-hidden" style={{ background: '#0d0d0d', color: '#e5e7eb' }}>
      {/* Sidebar */}
      <aside
        className="flex flex-col flex-shrink-0 border-r"
        style={{ width: 220, background: '#1a1a1a', borderColor: '#2a2a2a' }}
      >
        {/* Header / Logo */}
        <div className="flex items-center gap-2 px-4 py-4 border-b" style={{ borderColor: '#2a2a2a' }}>
          <span className="font-bold text-white tracking-tight text-lg">brain ui</span>
          <span
            className="text-xs px-1.5 py-0.5 rounded font-mono"
            style={{ background: '#2a2a2a', color: '#9ca3af' }}
          >
            v0.2.0
          </span>
        </div>

        {/* Kernel status */}
        <div className="flex items-center gap-2 px-4 py-2 border-b" style={{ borderColor: '#2a2a2a' }}>
          <span
            className="w-2 h-2 rounded-full flex-shrink-0"
            style={{
              background:
                wsStatus === 'connected' ? '#22c55e' :
                wsStatus === 'error'     ? '#ef4444' : '#6b7280',
            }}
          />
          <span className="text-xs" style={{ color: '#6b7280' }}>
            {wsStatus === 'connected' ? 'kernel connecté' :
             wsStatus === 'error'     ? 'kernel erreur'   : 'kernel déconnecté'}
          </span>
        </div>

        {/* Navigation */}
        <nav className="flex flex-col gap-0.5 mt-3 px-2">
          {NAV_ITEMS.map((item) => {
            const isActive = activeView === item.id
            return (
              <div key={item.id}>
                {item.separator && (
                  <div className="mx-3 my-1" style={{ borderTop: '1px solid #2a2a2a' }} />
                )}
                <button
                  onClick={() => handleViewChange(item.id)}
                  className="flex items-center gap-3 px-3 py-2 rounded text-sm font-medium text-left transition-colors w-full"
                  style={
                    isActive
                      ? {
                          background: 'rgba(99,102,241,0.2)',
                          color: '#6366f1',
                          borderLeft: '2px solid #6366f1',
                          paddingLeft: 10,
                        }
                      : {
                          color: '#9ca3af',
                          borderLeft: '2px solid transparent',
                          paddingLeft: 10,
                        }
                  }
                >
                  <span className="text-base leading-none">{item.icon}</span>
                  <span>{item.label}</span>
                </button>
              </div>
            )
          })}
        </nav>

        {/* Docs — lien externe standalone */}
        <div className="px-2 mt-2">
          <a
            href="/ui/docs.html"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-3 px-3 py-2 rounded text-sm font-medium text-left w-full transition-colors"
            style={{ color: '#9ca3af', borderLeft: '2px solid transparent', paddingLeft: 10, textDecoration: 'none' }}
          >
            <span className="text-base leading-none">📖</span>
            <span>Docs</span>
            <span style={{ marginLeft: 'auto', fontSize: 9, color: '#4b5563' }}>↗</span>
          </a>
        </div>

        {/* Bouton Logs */}
        <div className="px-2 mt-2">
          <button
            onClick={() => setLogsProject((prev) => (prev ? null : (storeWorkflows[0]?.id ?? 'ambient')))}
            className="flex items-center gap-3 px-3 py-2 rounded text-sm font-medium text-left w-full transition-colors"
            style={
              logsProject
                ? {
                    background: 'rgba(99,102,241,0.2)',
                    color: '#6366f1',
                    borderLeft: '2px solid #6366f1',
                    paddingLeft: 10,
                  }
                : {
                    color: '#9ca3af',
                    borderLeft: '2px solid transparent',
                    paddingLeft: 10,
                  }
            }
          >
            <span className="text-base leading-none">📋</span>
            <span>Logs</span>
            <span style={{ marginLeft: 'auto', fontSize: 9, color: '#4b5563', fontFamily: 'monospace' }}>⌘L</span>
          </button>
        </div>

        {/* Tier badge — en bas de sidebar avant ⌘K */}
        <div style={{ padding: '4px 16px', color: '#374151', fontSize: 10, fontFamily: 'monospace' }}>
          {tierInfo.tier}
        </div>

        {/* Cmd+K hint */}
        <div className="mt-auto px-4 py-3 border-t" style={{ borderColor: '#2a2a2a' }}>
          <button
            onClick={() => setPaletteOpen(true)}
            className="flex items-center gap-2 w-full text-xs font-mono"
            style={{ color: '#4b5563', background: 'transparent' }}
          >
            <span>⌘K</span>
            <span>Commandes</span>
          </button>
        </div>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-hidden flex flex-col">
        {activeView === 'dashboard' && (
          <Dashboard />
        )}
        {activeView === 'workflows' && (
          <TierGate feature="workflows" hasFeature={hasFeature}>
            <WorkflowBoard
              workflows={workflows}
              onGateApprove={handleGateApprove}
              onWorkflowClick={(wfId) => setLogsProject(wfId)}
            />
          </TierGate>
        )}
        {activeView === 'secrets' && (
          <TierGate feature="secrets" hasFeature={hasFeature}>
            <SecretsZone sections={MOCK_SECTIONS} onSecretSave={handleSecretSave} />
          </TierGate>
        )}
        {activeView === 'infra' && (
          <TierGate feature="infra" hasFeature={hasFeature}>
            <InfraRegistry />
          </TierGate>
        )}
        {activeView === 'cosmos' && (
          <div style={{ position: 'relative', flex: 1, minHeight: 0 }}>
            <Suspense fallback={
              <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#4b5563' }}>
                <span className="text-sm font-mono">Chargement Cosmos...</span>
              </div>
            }>
              <CosmosView />
            </Suspense>
          </div>
        )}
        {activeView === 'workspace' && (
          <Suspense fallback={
            <div className="flex items-center justify-center h-full" style={{ color: '#4b5563' }}>
              <span className="text-sm font-mono">Chargement Workspace...</span>
            </div>
          }>
            <WorkspaceView />
          </Suspense>
        )}
      </main>

      {/* GatesDrawer — affiché si gate en attente */}
      {pendingGate && (
        <GatesDrawer
          workflowId={pendingGate.workflowId}
          stepId={pendingGate.stepId}
          stepLabel={pendingGate.stepLabel}
          onApprove={async () => setPendingGate(null)}
          onReject={async () => setPendingGate(null)}
          onClose={() => setPendingGate(null)}
        />
      )}

      {/* LogDrawer — slide-in depuis la droite */}
      <LogDrawer
        open={logsProject !== null}
        project={logsProject}
        onClose={() => setLogsProject(null)}
      />

      {/* GateDrawer — approbation workflow SuperOAuth */}
      <GateDrawer
        open={gateDrawer.open}
        workflowId={gateDrawer.workflowId}
        stepId={gateDrawer.stepId}
        onClose={() => setGateDrawer((prev) => ({ ...prev, open: false }))}
      />

      {/* CommandPalette — Cmd+K */}
      {paletteOpen && (
        <CommandPalette
          onClose={() => setPaletteOpen(false)}
          onNavigate={(view) => { handleViewChange(view as ActiveView); setPaletteOpen(false) }}
        />
      )}
    </div>
  )
}

export default function App() {
  return (
    <ToastProvider>
      <AppInner />
    </ToastProvider>
  )
}
