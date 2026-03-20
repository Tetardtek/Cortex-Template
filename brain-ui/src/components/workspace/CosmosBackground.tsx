import { useMemo } from 'react'
import * as THREE from 'three'
import type { CosmosPoint, ZoneKey } from '../../types'

const ZONE_COLORS: Record<ZoneKey, string> = {
  public:  '#6366f1',
  work:    '#22c55e',
  kernel:  '#f59e0b',
  unknown: '#6b7280',
}

interface Props {
  points: CosmosPoint[]
}

export function CosmosBackground({ points }: Props) {
  const { positions, colors } = useMemo(() => {
    const positions = new Float32Array(points.length * 3)
    const colors = new Float32Array(points.length * 3)
    const color = new THREE.Color()

    points.forEach((p, i) => {
      positions[i * 3]     = p.x * 3
      positions[i * 3 + 1] = p.y * 3
      positions[i * 3 + 2] = p.z * 3

      color.set(ZONE_COLORS[p.zone] ?? ZONE_COLORS.unknown)
      colors[i * 3]     = color.r
      colors[i * 3 + 1] = color.g
      colors[i * 3 + 2] = color.b
    })

    return { positions, colors }
  }, [points])

  if (points.length === 0) return null

  return (
    <points>
      <bufferGeometry>
        <bufferAttribute
          attach="attributes-position"
          array={positions}
          count={points.length}
          itemSize={3}
        />
        <bufferAttribute
          attach="attributes-color"
          array={colors}
          count={points.length}
          itemSize={3}
        />
      </bufferGeometry>
      <pointsMaterial
        size={0.04}
        vertexColors
        transparent
        opacity={0.2}
        sizeAttenuation
        depthWrite={false}
      />
    </points>
  )
}
