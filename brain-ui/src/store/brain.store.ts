import { create } from 'zustand'
import type { Workflow } from '../types'

export interface LogLine {
  ts: string
  level: 'info' | 'warn' | 'error' | 'debug'
  msg: string
}

interface BrainStore {
  workflows:  Workflow[]
  logs:       Record<string, LogLine[]>
  wsStatus:   'connected' | 'disconnected' | 'error'
  setWorkflows:   (w: Workflow[]) => void
  updateWorkflow: (w: Workflow) => void
  appendLogs:     (project: string, lines: LogLine[]) => void
  clearLogs:      (project: string) => void
  setWsStatus:    (s: BrainStore['wsStatus']) => void
}

export const useBrainStore = create<BrainStore>((set) => ({
  workflows:  [],
  logs:       {},
  wsStatus:   'disconnected',
  setWorkflows:   (workflows) => set({ workflows }),
  updateWorkflow: (w) => set((s) => ({
    workflows: s.workflows.map((x) => (x.id === w.id ? w : x)),
  })),
  appendLogs: (project, lines) => set((s) => ({
    logs: { ...s.logs, [project]: [...(s.logs[project] ?? []), ...lines] },
  })),
  clearLogs: (project) => set((s) => ({
    logs: { ...s.logs, [project]: [] },
  })),
  setWsStatus: (wsStatus) => set({ wsStatus }),
}))
