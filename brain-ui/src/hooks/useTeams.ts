import { useState, useEffect } from 'react'
import type { TeamPreset } from '../types'

const MOCK_TEAMS: TeamPreset[] = [
  {
    id: 'team-frontend',
    label: 'Team Frontend',
    icon: '⚛️',
    agents: ['brain-ui-scribe', 'frontend-stack', 'optimizer-frontend'],
    capabilities: ['react', 'typescript', 'tailwind', 'vite'],
    gate_required: false,
    default_timeout_min: 30,
  },
  {
    id: 'team-backend',
    label: 'Team Backend',
    icon: '⚙️',
    agents: ['debug', 'optimizer-backend', 'optimizer-db', 'pm2', 'migration'],
    capabilities: ['nestjs', 'typescript', 'mysql', 'typeorm'],
    gate_required: false,
    default_timeout_min: 45,
  },
  {
    id: 'team-infra',
    label: 'Team Infra',
    icon: '🖥️',
    agents: ['vps', 'ci-cd', 'monitoring', 'secrets-guardian'],
    capabilities: ['apache', 'vps', 'ssl', 'ci-cd'],
    gate_required: true,
    default_timeout_min: 20,
  },
  {
    id: 'team-content',
    label: 'Team Content',
    icon: '🎬',
    agents: ['content-strategist', 'scriptwriter', 'seo-youtube'],
    capabilities: ['youtube', 'seo', 'scriptwriting'],
    gate_required: false,
    default_timeout_min: 60,
  },
  {
    id: 'team-security',
    label: 'Team Sécurité',
    icon: '🔒',
    agents: ['security', 'secrets-guardian', 'code-review'],
    capabilities: ['jwt', 'oauth', 'owasp', 'secrets-rotation'],
    gate_required: true,
    default_timeout_min: 30,
  },
  {
    id: 'team-fullstack',
    label: 'Team Fullstack',
    icon: '🔀',
    agents: ['frontend-stack', 'optimizer-backend', 'optimizer-db', 'debug'],
    capabilities: ['react', 'nestjs', 'mysql', 'typescript'],
    gate_required: false,
    default_timeout_min: 60,
  },
  {
    id: 'team-game',
    label: 'Team Game',
    icon: '🎮',
    agents: ['game-designer', 'optimizer-backend', 'optimizer-db'],
    capabilities: ['game-design', 'nestjs', 'mysql'],
    gate_required: false,
    default_timeout_min: 45,
  },
]

const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

export function useTeams() {
  const [teams, setTeams] = useState<TeamPreset[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    if (USE_MOCK || !API_BASE) {
      setTeams(MOCK_TEAMS)
      setIsLoading(false)
      return
    }

    const token = import.meta.env.VITE_BRAIN_TOKEN ?? ''
    fetch(`${API_BASE}/teams`, {
      credentials: 'include',
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    })
      .then((r) => r.json())
      .then((data) => setTeams(data))
      .catch(() => setTeams(MOCK_TEAMS))
      .finally(() => setIsLoading(false))
  }, [])

  return { teams, isLoading }
}
