import { useRef, useMemo, useCallback } from 'react'
import { useThree } from '@react-three/fiber'
import * as THREE from 'three'
import type { CosmosPoint, ZoneKey } from '../../types'

export const ZONE_COLORS: Record<ZoneKey, [number, number, number]> = {
  kernel:    [0.937, 0.267, 0.267],  // rouge — protection maximale
  instance:  [1.000, 0.600, 0.200],  // orange — config machine
  satellite: [0.388, 0.400, 0.945],  // bleu — satellites autonomes
  public:    [0.898, 0.906, 0.922],  // blanc — visible, distribué
  work:      [0.388, 0.400, 0.945],  // bleu (compat legacy)
  unknown:   [0.294, 0.337, 0.369],  // gris
}

interface CosmosPointsProps {
  points: CosmosPoint[]
  activeZone: 'all' | ZoneKey
  highlightedIds: Set<string>
  onPointClick: (point: CosmosPoint) => void
  heatmap?: boolean
}

export function CosmosPoints({ points, activeZone, highlightedIds, onPointClick, heatmap = false }: CosmosPointsProps) {
  const pointsRef = useRef<THREE.Points>(null)
  const { camera, raycaster, gl } = useThree()

  const { positions, colors } = useMemo(() => {
    const positions = new Float32Array(points.length * 3)
    const colors = new Float32Array(points.length * 3)

    // Normalise les coords UMAP vers [-2, 2] centrées à l'origine
    // Centre de masse (mean) — robuste aux outliers qui décalent le bounding box
    const xs = points.map((p) => p.x)
    const ys = points.map((p) => p.y)
    const zs = points.map((p) => p.z)
    const n = points.length || 1
    const cx = xs.reduce((a, b) => a + b, 0) / n
    const cy = ys.reduce((a, b) => a + b, 0) / n
    const cz = zs.reduce((a, b) => a + b, 0) / n
    // Scale sur percentile 95 — les outliers ne déforment plus la nébuleuse
    const dists = points.map((p) =>
      Math.max(Math.abs(p.x - cx), Math.abs(p.y - cy), Math.abs(p.z - cz))
    ).sort((a, b) => a - b)
    const p95 = dists[Math.floor(n * 0.95)] ?? dists[dists.length - 1] ?? 1
    const scale = 2 / Math.max(p95, 0.001)

    points.forEach((p, i) => {
      positions[i * 3]     = (p.x - cx) * scale
      positions[i * 3 + 1] = (p.y - cy) * scale
      positions[i * 3 + 2] = (p.z - cz) * scale

      const [r, g, b] = ZONE_COLORS[p.zone] ?? ZONE_COLORS.unknown

      if (heatmap) {
        // Mode nébuleuse — couleur pleine, l'alpha est géré dans le fragment shader
        const dimmed = activeZone !== 'all' && p.zone !== activeZone ? 0.15 : 1.0
        colors[i * 3]     = r * dimmed
        colors[i * 3 + 1] = g * dimmed
        colors[i * 3 + 2] = b * dimmed
      } else {
        let alpha = 1.0
        if (activeZone !== 'all' && p.zone !== activeZone) {
          alpha = 0.08
        } else if (highlightedIds.size > 0 && !highlightedIds.has(p.id)) {
          alpha = 0.05
        }
        colors[i * 3]     = r * alpha
        colors[i * 3 + 1] = g * alpha
        colors[i * 3 + 2] = b * alpha
      }
    })

    return { positions, colors }
  }, [points, activeZone, highlightedIds])

  const handleClick = useCallback((event: { nativeEvent: MouseEvent }) => {
    if (!pointsRef.current) return
    const nativeEvent = event.nativeEvent
    const rect = gl.domElement.getBoundingClientRect()
    const mouse = new THREE.Vector2(
      ((nativeEvent.clientX - rect.left) / rect.width) * 2 - 1,
      -((nativeEvent.clientY - rect.top) / rect.height) * 2 + 1,
    )
    raycaster.setFromCamera(mouse, camera)
    raycaster.params.Points = { threshold: 0.05 }
    const intersects = raycaster.intersectObject(pointsRef.current)
    if (intersects.length > 0 && intersects[0].index != null) {
      const idx = intersects[0].index
      onPointClick(points[idx])
    }
  }, [points, camera, raycaster, gl, onPointClick])

  return (
    <points ref={pointsRef} onClick={handleClick}>
      <bufferGeometry>
        <bufferAttribute attach="attributes-position" args={[positions, 3]} />
        <bufferAttribute attach="attributes-color"    args={[colors, 3]} />
      </bufferGeometry>
      {heatmap ? (
        <shaderMaterial
          vertexShader={`
            attribute vec3 color;
            varying vec3 vColor;
            void main() {
              vColor = color;
              vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
              gl_PointSize = clamp(60.0 / -mvPosition.z, 10.0, 50.0);
              gl_Position = projectionMatrix * mvPosition;
            }
          `}
          fragmentShader={`
            varying vec3 vColor;
            void main() {
              vec2 uv = gl_PointCoord - vec2(0.5);
              float d = dot(uv, uv);
              if (d > 0.25) discard;
              float alpha = 0.25 * (1.0 - d * 3.0);
              gl_FragColor = vec4(vColor, alpha);
            }
          `}
          transparent={true}
          blending={THREE.AdditiveBlending}
          depthWrite={false}
        />
      ) : (
        <shaderMaterial
          vertexShader={`
            attribute vec3 color;
            varying vec3 vColor;
            void main() {
              vColor = color;
              vec4 mvPosition = modelViewMatrix * vec4(position, 1.0);
              gl_PointSize = clamp(12.0 / -mvPosition.z, 1.5, 5.0);
              gl_Position = projectionMatrix * mvPosition;
            }
          `}
          fragmentShader={`
            varying vec3 vColor;
            void main() {
              vec2 uv = gl_PointCoord - vec2(0.5);
              if (dot(uv, uv) > 0.25) discard;
              gl_FragColor = vec4(vColor, 1.0);
            }
          `}
          transparent={false}
        />
      )}
    </points>
  )
}
