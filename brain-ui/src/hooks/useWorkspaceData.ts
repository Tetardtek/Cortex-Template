import { useMemo } from 'react'
import { useBrainStore } from '../store/brain.store'
import type { WorkspaceWorkflow } from '../types'

const WORKFLOW_COLORS = ['#6366f1', '#f59e0b', '#22c55e', '#ef4444', '#8b5cf6', '#06b6d4']

function computeLayout(workflows: ReturnType<typeof useBrainStore.getState>['workflows']): WorkspaceWorkflow[] {
  return workflows.map((wf, wfIdx) => {
    const baseX = (wfIdx - workflows.length / 2) * 4
    const color = WORKFLOW_COLORS[wfIdx % WORKFLOW_COLORS.length]

    const steps = (wf.steps ?? []).map((step, stepIdx) => {
      const z = step.status === 'done' ? -stepIdx * 0.5 : stepIdx === 0 ? 1 : 0
      return {
        id: step.id,
        label: step.label,
        status: step.status as WorkspaceWorkflow['steps'][number]['status'],
        isGate: step.isGate ?? false,
        x: baseX + Math.sin(stepIdx * 0.8) * 0.5,
        y: (workflows.length / 2 - stepIdx) * 1.5,
        z,
      }
    })

    return { id: wf.id, name: wf.name, steps, teamId: undefined, color }
  })
}

export function useWorkspaceData() {
  const workflows = useBrainStore((s) => s.workflows)
  const workspaceWorkflows = useMemo(() => computeLayout(workflows), [workflows])
  return { workflows: workspaceWorkflows }
}
