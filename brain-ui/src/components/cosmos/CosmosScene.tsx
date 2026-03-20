import { Canvas } from '@react-three/fiber'
import { OrbitControls } from '@react-three/drei'
import { CosmosPoints } from './CosmosPoints'
import type { CosmosPoint, ZoneKey } from '../../types'

interface CosmosSceneProps {
  points: CosmosPoint[]
  activeZone: 'all' | ZoneKey
  highlightedIds: Set<string>
  onPointClick: (point: CosmosPoint) => void
  heatmap?: boolean
}

export function CosmosScene({ points, activeZone, highlightedIds, onPointClick, heatmap }: CosmosSceneProps) {
  return (
    <Canvas
      style={{ height: '100%', background: '#080808' }}
      camera={{ position: [0, 0, 5], fov: 60 }}
      gl={{ antialias: false }}
      onCreated={({ gl }) => {
        gl.setPixelRatio(Math.min(window.devicePixelRatio, 2))
      }}
    >
      <ambientLight intensity={0.3} />
      <CosmosPoints
        points={points}
        activeZone={activeZone}
        highlightedIds={highlightedIds}
        onPointClick={onPointClick}
        heatmap={heatmap}
      />
      <OrbitControls
        enableDamping={true}
        dampingFactor={0.05}
        rotateSpeed={0.5}
        autoRotate={heatmap}
        autoRotateSpeed={0.4}
      />
    </Canvas>
  )
}
