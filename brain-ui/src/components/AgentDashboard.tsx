import { useState, useEffect } from 'react'

const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

interface Agent {
  id: string
  label: string
  tier: string
  export: boolean
  status: string
  triggers: string[]
  scope: string
  description: string
}

const TIER_COLORS: Record<string, { emoji: string; color: string; bg: string }> = {
  free:     { emoji: '🟢', color: '#4ade80', bg: 'rgba(34,197,94,0.1)' },
  featured: { emoji: '🔵', color: '#60a5fa', bg: 'rgba(59,130,246,0.1)' },
  pro:      { emoji: '🟠', color: '#fbbf24', bg: 'rgba(245,158,11,0.1)' },
  full:     { emoji: '🟣', color: '#c084fc', bg: 'rgba(168,85,247,0.1)' },
  owner:    { emoji: '🟣', color: '#c084fc', bg: 'rgba(168,85,247,0.1)' },
}

// Groupes métier pour organiser les agents
const AGENT_GROUPS: Record<string, { label: string; agents: string[] }> = {
  'code': {
    label: 'Code & Qualite',
    agents: ['code-review', 'security', 'testing', 'refacto', 'optimizer-backend', 'optimizer-db', 'optimizer-frontend', 'frontend-stack'],
  },
  'infra': {
    label: 'Infra & Deploy',
    agents: ['vps', 'ci-cd', 'monitoring', 'pm2', 'mail', 'migration'],
  },
  'brain': {
    label: 'Brain & Systeme',
    agents: ['scribe', 'todo-scribe', 'metabolism-scribe', 'wiki-scribe', 'coach', 'coach-boot', 'coach-scribe', 'capital-scribe', 'toolkit-scribe', 'helloWorld', 'session-orchestrator', 'secrets-guardian', 'brain-guardian', 'key-guardian', 'pre-flight', 'feature-gate', 'brain-hypervisor', 'kernel-orchestrator'],
  },
  'explore': {
    label: 'Exploration',
    agents: ['debug', 'brainstorm', 'mentor', 'orchestrator', 'interprete', 'aside', 'recruiter', 'agent-review', 'time-anchor', 'pattern-scribe'],
  },
}

function getAgentGroup(agentId: string): string {
  for (const [group, data] of Object.entries(AGENT_GROUPS)) {
    if (data.agents.includes(agentId)) return group
  }
  return 'other'
}

export function AgentCatalog() {
  const [agents, setAgents] = useState<Agent[]>([])
  const [error, setError] = useState<string | null>(null)
  const [filter, setFilter] = useState<string>('all')

  useEffect(() => {
    fetch(`${API_BASE}/agents`)
      .then(r => r.json())
      .then(data => setAgents(Array.isArray(data) ? data : []))
      .catch(e => setError(e.message))
  }, [])

  if (error) return <div style={{ color: '#ef4444' }}>Erreur: {error}</div>
  if (!agents.length) return <div style={{ color: '#4b5563' }}>Chargement...</div>

  // Grouper les agents
  const grouped: Record<string, Agent[]> = {}
  for (const agent of agents) {
    const group = getAgentGroup(agent.id)
    if (!grouped[group]) grouped[group] = []
    grouped[group].push(agent)
  }

  // Stats
  const tierCounts = agents.reduce<Record<string, number>>((acc, a) => {
    acc[a.tier] = (acc[a.tier] || 0) + 1
    return acc
  }, {})

  const filteredAgents = filter === 'all' ? agents : agents.filter(a => {
    if (filter === 'code' || filter === 'infra' || filter === 'brain' || filter === 'explore') {
      return getAgentGroup(a.id) === filter
    }
    return a.tier === filter
  })

  const filteredGrouped: Record<string, Agent[]> = {}
  for (const agent of filteredAgents) {
    const group = getAgentGroup(agent.id)
    if (!filteredGrouped[group]) filteredGrouped[group] = []
    filteredGrouped[group].push(agent)
  }

  return (
    <div>
      <h1>Catalogue des agents</h1>
      <p style={{ color: '#9ca3af' }}>
        {agents.length} agents disponibles — donnees live depuis brain-engine
      </p>

      {/* Stats bar */}
      <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap', margin: '1rem 0' }}>
        <StatBadge
          label="Tous"
          count={agents.length}
          active={filter === 'all'}
          color="#818cf8"
          onClick={() => setFilter('all')}
        />
        {Object.entries(TIER_COLORS).filter(([t]) => tierCounts[t]).map(([tier, colors]) => (
          <StatBadge
            key={tier}
            label={`${colors.emoji} ${tier}`}
            count={tierCounts[tier] || 0}
            active={filter === tier}
            color={colors.color}
            onClick={() => setFilter(filter === tier ? 'all' : tier)}
          />
        ))}
      </div>

      {/* Group filters */}
      <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', margin: '0.5rem 0 1.5rem' }}>
        {Object.entries(AGENT_GROUPS).map(([key, data]) => (
          <button
            key={key}
            onClick={() => setFilter(filter === key ? 'all' : key)}
            style={{
              background: filter === key ? 'rgba(99,102,241,0.15)' : 'transparent',
              color: filter === key ? '#818cf8' : '#6b7280',
              border: '1px solid #2a2a2a',
              borderRadius: '4px',
              padding: '0.25rem 0.75rem',
              fontSize: '0.8rem',
              cursor: 'pointer',
            }}
          >
            {data.label}
          </button>
        ))}
      </div>

      {/* Agent cards by group */}
      {Object.entries(AGENT_GROUPS)
        .filter(([key]) => filteredGrouped[key]?.length)
        .map(([key, data]) => (
          <div key={key} style={{ marginBottom: '2rem' }}>
            <h2>{data.label}</h2>
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              {filteredGrouped[key].map(agent => (
                <AgentCard key={agent.id} agent={agent} />
              ))}
            </div>
          </div>
        ))
      }

      {/* Uncategorized */}
      {filteredGrouped['other']?.length > 0 && (
        <div style={{ marginBottom: '2rem' }}>
          <h2>Autres</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            {filteredGrouped['other'].map(agent => (
              <AgentCard key={agent.id} agent={agent} />
            ))}
          </div>
        </div>
      )}
    </div>
  )
}

function AgentCard({ agent }: { agent: Agent }) {
  const tier = TIER_COLORS[agent.tier] || TIER_COLORS['free']
  return (
    <div
      style={{
        background: '#141414',
        border: '1px solid #2a2a2a',
        borderLeft: `3px solid ${tier.color}`,
        borderRadius: '4px',
        padding: '0.75rem 1rem',
        display: 'flex',
        alignItems: 'flex-start',
        gap: '0.75rem',
      }}
    >
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
          <code style={{ color: '#a78bfa', fontSize: '0.875rem' }}>{agent.id}</code>
          <span
            style={{
              fontSize: '0.65rem',
              padding: '0.1em 0.4em',
              borderRadius: '3px',
              background: tier.bg,
              color: tier.color,
              fontWeight: 600,
            }}
          >
            {tier.emoji} {agent.tier}
          </span>
        </div>
        {agent.description && (
          <p style={{ color: '#9ca3af', fontSize: '0.8rem', margin: '0.25rem 0 0' }}>
            {agent.description}
          </p>
        )}
      </div>
      {agent.triggers.length > 0 && (
        <div style={{ fontSize: '0.7rem', color: '#4b5563', whiteSpace: 'nowrap' }}>
          {agent.triggers.slice(0, 3).join(', ')}
        </div>
      )}
    </div>
  )
}

function StatBadge({ label, count, active, color, onClick }: {
  label: string; count: number; active: boolean; color: string; onClick: () => void
}) {
  return (
    <button
      onClick={onClick}
      style={{
        background: active ? `${color}22` : 'transparent',
        border: `1px solid ${active ? color : '#2a2a2a'}`,
        borderRadius: '6px',
        padding: '0.4rem 0.75rem',
        cursor: 'pointer',
        display: 'flex',
        alignItems: 'center',
        gap: '0.4rem',
      }}
    >
      <span style={{ color, fontWeight: 700, fontSize: '1rem' }}>{count}</span>
      <span style={{ color: active ? '#d1d5db' : '#6b7280', fontSize: '0.8rem' }}>{label}</span>
    </button>
  )
}
