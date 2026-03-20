import { Text } from '@react-three/drei'
import * as THREE from 'three'
import { StepSphere } from './StepSphere'
import { GateOctahedron } from './GateOctahedron'
import type { WorkspaceWorkflow, WorkspaceStep } from '../../types'

interface Props {
  workflow: WorkspaceWorkflow
  onStepClick: (step: WorkspaceStep) => void
}

const STATUS_COLORS: Record<string, string> = {
  done:          '#22c55e',
  'in-progress': '#6366f1',
  pending:       '#4b5563',
  gate:          '#f59e0b',
  fail:          '#ef4444',
  blocked:       '#6b7280',
}

function ConnectionLine({
  from,
  to,
  color,
  animated,
}: {
  from: [number, number, number]
  to: [number, number, number]
  color: string
  animated: boolean
}) {
  const points = [new THREE.Vector3(...from), new THREE.Vector3(...to)]
  const geometry = new THREE.BufferGeometry().setFromPoints(points)
  const line = new THREE.Line(
    geometry,
    new THREE.LineBasicMaterial({ color, opacity: animated ? 1 : 0.4, transparent: true })
  )

  return <primitive object={line} />
}

export function WorkflowConstellation({ workflow, onStepClick }: Props) {
  const firstStep = workflow.steps[0]

  return (
    <group>
      {firstStep && (
        <Text
          position={[firstStep.x, firstStep.y + 1.2, firstStep.z]}
          fontSize={0.25}
          color={workflow.color}
          anchorX="center"
          anchorY="bottom"
          font={undefined}
        >
          {workflow.name}
        </Text>
      )}

      {workflow.steps.slice(0, -1).map((step, i) => {
        const next = workflow.steps[i + 1]
        return (
          <ConnectionLine
            key={`edge-${step.id}-${next.id}`}
            from={[step.x, step.y, step.z]}
            to={[next.x, next.y, next.z]}
            color={STATUS_COLORS[step.status] ?? '#4b5563'}
            animated={step.status === 'in-progress'}
          />
        )
      })}

      {workflow.steps.map((step) =>
        step.isGate ? (
          <GateOctahedron
            key={step.id}
            step={step}
            onClick={() => onStepClick(step)}
          />
        ) : (
          <StepSphere
            key={step.id}
            step={step}
            color={STATUS_COLORS[step.status] ?? '#4b5563'}
            onClick={() => onStepClick(step)}
          />
        )
      )}
    </group>
  )
}
