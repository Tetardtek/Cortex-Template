export type StepStatus = 'pending' | 'in-progress' | 'done' | 'gate' | 'partial' | 'fail' | 'blocked'

export interface WorkflowStep {
  id: string
  label: string
  status: StepStatus
  isGate?: boolean
}

export interface Workflow {
  id: string
  name: string
  project: string
  steps: WorkflowStep[]
}

// Team presets
export interface TeamPreset {
  id: string
  label: string
  icon: string
  agents: string[]
  capabilities: string[]
  gate_required: boolean
  default_timeout_min: number
}

// WorkflowBuilder
export type StepDraftType = 'step' | 'gate'

export interface StepDraft {
  id: string
  label: string
  type: StepDraftType
  agentHint?: string
}

export interface WorkflowDraft {
  title: string
  teamId: string
  steps: StepDraft[]
  gateRequired: boolean
}

// Cosmos — Sprint 4
export type ZoneKey = 'public' | 'work' | 'kernel' | 'instance' | 'satellite' | 'unknown'

export interface CosmosPoint {
  id: string
  path: string
  zone: ZoneKey
  label: string
  excerpt: string
  x: number
  y: number
  z: number
}

export interface VisualizeResponse {
  points: CosmosPoint[]
  generated_at: string
  cached: boolean
  umap_params: {
    n_components: 3
    n_neighbors: number
    min_dist: number
  }
}

// Workspace — Sprint 5
export interface WorkspaceStep {
  id: string
  label: string
  status: 'pending' | 'in-progress' | 'done' | 'gate' | 'fail' | 'blocked'
  isGate?: boolean
  x: number
  y: number
  z: number
}

export interface WorkspaceWorkflow {
  id: string
  name: string
  steps: WorkspaceStep[]
  teamId?: string
  color: string
}

// InfraRegistry — Sprint 7
export interface InfraService {
  id: string
  name: string
  type: 'pm2' | 'system' | 'info'
  status: 'online' | 'stopped' | 'errored' | 'unknown'
  port?: number | null
  uptime?: number | null
  restarts?: number
  memory?: number
  cpu?: number
}

export interface InfraResponse {
  services: InfraService[]
  total: number
}
