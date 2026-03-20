import { useState, Suspense } from 'react'

function checkWebGL(): boolean {
  try {
    const canvas = document.createElement('canvas')
    return !!(canvas.getContext('webgl') || canvas.getContext('experimental-webgl'))
  } catch { return false }
}

function NoWebGL() {
  return (
    <div className="flex flex-col items-center justify-center h-full" style={{ background: '#080808' }}>
      <div className="text-3xl mb-3">🖥️</div>
      <div style={{ color: '#ef4444' }} className="text-sm font-mono mb-1">WebGL non disponible</div>
      <div style={{ color: '#4b5563' }} className="text-xs text-center max-w-xs">
        Active l'accélération matérielle dans Chrome : Paramètres → Système → Utiliser l'accélération matérielle
      </div>
    </div>
  )
}
import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import { useWorkspaceData } from '../../hooks/useWorkspaceData'
import { useCosmosData } from '../../hooks/useCosmosData'
import { WorkflowConstellation } from './WorkflowConstellation'
import { WorkspaceInfoPanel } from './WorkspaceInfoPanel'
import { WorkspaceMetrics } from './WorkspaceMetrics'
import { CosmosBackground } from './CosmosBackground'
import type { WorkspaceStep, WorkspaceWorkflow } from '../../types'

function WorkspaceInner() {
  const { workflows } = useWorkspaceData()
  const { points } = useCosmosData()
  const [selectedStep, setSelectedStep] = useState<{
    step: WorkspaceStep
    wf: WorkspaceWorkflow
  } | null>(null)
  const [showCosmos, setShowCosmos] = useState(true)

  if (workflows.length === 0) {
    return (
      <div
        className="flex flex-col items-center justify-center h-full"
        style={{ background: '#080808' }}
      >
        <div className="text-4xl mb-3">🌌</div>
        <div style={{ color: '#4b5563' }} className="text-sm font-mono">
          Aucun workflow actif
        </div>
        <div style={{ color: '#374151' }} className="text-xs mt-1">
          Créer un workflow via ⌘K → Nouveau workflow
        </div>
      </div>
    )
  }

  return (
    <div style={{ width: '100%', height: '100%', background: '#080808', position: 'relative' }}>
      <Canvas
        camera={{ position: [0, 2, 12], fov: 60 }}
        gl={{ antialias: true }}
        style={{ width: '100%', height: '100%' }}
      >
        <ambientLight intensity={0.2} />
        <pointLight position={[10, 10, 10]} intensity={0.5} />

        <Suspense fallback={null}>
          {showCosmos && <CosmosBackground points={points} />}
          {workflows.map((wf) => (
            <WorkflowConstellation
              key={wf.id}
              workflow={wf}
              onStepClick={(step) => setSelectedStep({ step, wf })}
            />
          ))}
        </Suspense>

        <OrbitControls
          enableDamping
          dampingFactor={0.05}
          rotateSpeed={0.4}
          minDistance={3}
          maxDistance={30}
        />
      </Canvas>

      <WorkspaceInfoPanel
        selection={selectedStep}
        onClose={() => setSelectedStep(null)}
      />

      <WorkspaceMetrics workflows={workflows} />

      <button
        onClick={() => setShowCosmos((v) => !v)}
        style={{
          position: 'absolute',
          top: '0.5rem',
          right: '0.5rem',
          background: '#1a1a1a',
          border: '1px solid #2a2a2a',
          color: showCosmos ? '#6366f1' : '#6b7280',
          fontFamily: 'monospace',
          fontSize: '0.75rem',
          padding: '0.25rem 0.5rem',
          borderRadius: '0.25rem',
          cursor: 'pointer',
          zIndex: 10,
        }}
      >
        🌌 Cosmos
      </button>
    </div>
  )
}

export default function WorkspaceView() {
  if (!checkWebGL()) return <NoWebGL />
  return <WorkspaceInner />
}
