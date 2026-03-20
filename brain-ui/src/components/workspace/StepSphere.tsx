import { useRef, useState } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import type { WorkspaceStep } from '../../types'

interface Props {
  step: WorkspaceStep
  color: string
  onClick: () => void
}

export function StepSphere({ step, color, onClick }: Props) {
  const meshRef = useRef<THREE.Mesh>(null)
  const [hovered, setHovered] = useState(false)

  useFrame(() => {
    if (!meshRef.current) return
    if (step.status === 'in-progress') {
      meshRef.current.scale.setScalar(1 + Math.sin(Date.now() * 0.003) * 0.08)
    }
  })

  const size = step.status === 'done' ? 0.18 : 0.25

  return (
    <mesh
      ref={meshRef}
      position={[step.x, step.y, step.z]}
      onClick={(e) => { e.stopPropagation(); onClick() }}
      onPointerOver={() => setHovered(true)}
      onPointerOut={() => setHovered(false)}
    >
      <sphereGeometry args={[hovered ? size * 1.3 : size, 16, 16]} />
      <meshStandardMaterial
        color={color}
        emissive={color}
        emissiveIntensity={step.status === 'in-progress' ? 0.4 : hovered ? 0.3 : 0.1}
        transparent
        opacity={step.status === 'done' ? 0.5 : 1}
      />
    </mesh>
  )
}
