import { useRef, useState } from 'react'
import { useFrame } from '@react-three/fiber'
import * as THREE from 'three'
import type { WorkspaceStep } from '../../types'

interface Props {
  step: WorkspaceStep
  onClick: () => void
}

export function GateOctahedron({ step, onClick }: Props) {
  const meshRef = useRef<THREE.Mesh>(null)
  const [hovered, setHovered] = useState(false)

  useFrame((_, delta) => {
    if (meshRef.current) {
      meshRef.current.rotation.y += delta * 0.8
      meshRef.current.rotation.x += delta * 0.3
    }
  })

  return (
    <mesh
      ref={meshRef}
      position={[step.x, step.y, step.z]}
      onClick={(e) => { e.stopPropagation(); onClick() }}
      onPointerOver={() => setHovered(true)}
      onPointerOut={() => setHovered(false)}
    >
      <octahedronGeometry args={[hovered ? 0.45 : 0.35]} />
      <meshStandardMaterial
        color="#f59e0b"
        emissive="#f59e0b"
        emissiveIntensity={hovered ? 0.6 : 0.3}
        wireframe={!hovered}
      />
    </mesh>
  )
}
