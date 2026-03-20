import { useState, useEffect } from 'react'

const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

interface TierData {
  description: string
  coach_level: string
  distillation: boolean
  agents_new: string[]
  agents_total: string[]
  agents_count: number
  sessions_new: string[]
  sessions_total: string[]
  sessions_count: number
}

interface TiersResponse {
  version: string
  tiers: Record<string, TierData>
  tier_chain: string[]
}

const TIER_COLORS: Record<string, { emoji: string; border: string; bg: string; text: string }> = {
  free:     { emoji: '🟢', border: '#22c55e', bg: 'rgba(34,197,94,0.06)',  text: '#4ade80' },
  featured: { emoji: '🔵', border: '#3b82f6', bg: 'rgba(59,130,246,0.06)', text: '#60a5fa' },
  pro:      { emoji: '🟠', border: '#f59e0b', bg: 'rgba(245,158,11,0.06)', text: '#fbbf24' },
  full:     { emoji: '🟣', border: '#a855f7', bg: 'rgba(168,85,247,0.06)', text: '#c084fc' },
}

const TIER_TITLES: Record<string, string> = {
  free: 'Tu forkes, ca marche',
  featured: 'Le brain te connait',
  pro: "L'atelier complet",
  full: 'Ton brain, tes regles',
}

const COACH_LABELS: Record<string, string> = {
  boot: 'Observation — intervient sur risque critique uniquement',
  full: 'Mentorat complet — bilans, objectifs, progression',
  L2: 'Mentorat long terme — anticipe, challenge, milestones',
}

// Comparatif — vue multi-tiers
export function TierComparatif() {
  const [data, setData] = useState<TiersResponse | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetch(`${API_BASE}/brain-compose/tiers`)
      .then(r => r.json())
      .then(setData)
      .catch(e => setError(e.message))
  }, [])

  if (error) return <div style={{ color: '#ef4444' }}>Erreur: {error}</div>
  if (!data) return <div style={{ color: '#4b5563' }}>Chargement...</div>

  return (
    <div>
      <h1>Comparatif tiers</h1>
      <p style={{ color: '#9ca3af' }}>
        Donnees live depuis <code>brain-compose.yml</code> v{data.version}
      </p>

      {data.tier_chain.map(tierName => {
        const tier = data.tiers[tierName]
        if (!tier) return null
        const colors = TIER_COLORS[tierName]
        return (
          <blockquote
            key={tierName}
            style={{
              borderLeft: `3px solid ${colors.border}`,
              background: colors.bg,
              padding: '0.75rem 1rem',
              margin: '1rem 0',
              borderRadius: '0 4px 4px 0',
            }}
          >
            <p>
              <strong style={{ color: colors.text }}>
                {colors.emoji} {tierName} — {TIER_TITLES[tierName]}
              </strong>
            </p>
            <p>
              <strong style={{ color: '#f3f4f6' }}>{tier.agents_count} agents. {tier.sessions_count} sessions.</strong>
              {tier.distillation && <span style={{ color: '#60a5fa' }}> Distillation RAG active.</span>}
            </p>
            <p style={{ color: '#9ca3af' }}>{tier.description}</p>
          </blockquote>
        )
      })}

      <h2>Detail par tier</h2>

      {data.tier_chain.map(tierName => {
        const tier = data.tiers[tierName]
        if (!tier) return null
        const colors = TIER_COLORS[tierName]
        return (
          <div key={tierName} style={{ marginBottom: '2rem' }}>
            <h3 style={{ color: colors.text }}>{colors.emoji} {tierName}</h3>

            <p><strong>Sessions</strong> ({tier.sessions_count}) :</p>
            <p style={{ color: '#9ca3af' }}>{tier.sessions_total.join(' · ')}</p>

            <p><strong>Agents</strong> ({tier.agents_count}) :</p>
            <p style={{ color: '#9ca3af', fontSize: '0.875rem', lineHeight: '1.8' }}>
              {tier.agents_total.join(' · ')}
            </p>

            <p>
              <strong>Coach</strong> : {COACH_LABELS[tier.coach_level] || tier.coach_level}
            </p>
          </div>
        )
      })}
    </div>
  )
}

// Vue single tier
export function TierSingle({ tierName }: { tierName: string }) {
  const [data, setData] = useState<TiersResponse | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetch(`${API_BASE}/brain-compose/tiers`)
      .then(r => r.json())
      .then(setData)
      .catch(e => setError(e.message))
  }, [])

  if (error) return <div style={{ color: '#ef4444' }}>Erreur: {error}</div>
  if (!data) return <div style={{ color: '#4b5563' }}>Chargement...</div>

  const tier = data.tiers[tierName]
  if (!tier) return <div style={{ color: '#ef4444' }}>Tier "{tierName}" introuvable</div>

  const colors = TIER_COLORS[tierName]
  const chain = data.tier_chain
  const tierIndex = chain.indexOf(tierName)

  // Trouver les agents/sessions "nouveaux" par rapport au tier precedent
  const prevTier = tierIndex > 0 ? data.tiers[chain[tierIndex - 1]] : null
  const prevAgents = new Set(prevTier?.agents_total || [])
  const newAgents = tier.agents_total.filter(a => !prevAgents.has(a))
  const prevSessions = new Set(prevTier?.sessions_total || [])
  const newSessions = tier.sessions_total.filter(s => !prevSessions.has(s))

  // Tier suivant pour le "ce que tu n'as pas encore"
  const nextTierName = tierIndex < chain.length - 1 ? chain[tierIndex + 1] : null
  const nextTier = nextTierName ? data.tiers[nextTierName] : null

  return (
    <div>
      <h1>{colors.emoji} {tierName} — Ce que tu as</h1>
      <p style={{ color: '#9ca3af' }}>
        Donnees live depuis <code>brain-compose.yml</code> v{data.version}
      </p>

      <blockquote
        style={{
          borderLeft: `3px solid ${colors.border}`,
          background: colors.bg,
          padding: '0.75rem 1rem',
          margin: '1rem 0',
          borderRadius: '0 4px 4px 0',
        }}
      >
        <p>
          <strong style={{ color: colors.text }}>
            {tier.agents_count} agents. {tier.sessions_count} sessions.
          </strong>
          {tier.distillation && <span style={{ color: '#60a5fa' }}> Distillation RAG active.</span>}
        </p>
        <p style={{ color: '#9ca3af' }}>{tier.description}</p>
      </blockquote>

      <hr />

      <h2>Sessions {tierIndex > 0 && newSessions.length > 0 ? `(+${newSessions.length} nouvelles)` : ''}</h2>
      {tierIndex > 0 && newSessions.length > 0 && (
        <>
          <p><strong>Ajoutees a ce tier :</strong></p>
          <ul>{newSessions.map(s => <li key={s}><code>{s}</code></li>)}</ul>
        </>
      )}
      <p><strong>Toutes les sessions disponibles :</strong></p>
      <p style={{ color: '#9ca3af' }}>{tier.sessions_total.join(' · ')}</p>

      <hr />

      <h2>Agents {tierIndex > 0 && newAgents.length > 0 ? `(+${newAgents.length} nouveaux)` : ''}</h2>
      {tierIndex > 0 && newAgents.length > 0 && (
        <>
          <p><strong>Ajoutes a ce tier :</strong></p>
          <p style={{ color: '#9ca3af', fontSize: '0.875rem', lineHeight: '1.8' }}>
            {newAgents.join(' · ')}
          </p>
        </>
      )}
      <p><strong>Tous les agents disponibles ({tier.agents_count}) :</strong></p>
      <p style={{ color: '#9ca3af', fontSize: '0.875rem', lineHeight: '1.8' }}>
        {tier.agents_total.join(' · ')}
      </p>

      <hr />

      <h2>Coach</h2>
      <blockquote
        style={{
          borderLeft: `3px solid ${colors.border}`,
          background: colors.bg,
          padding: '0.5rem 1rem',
          borderRadius: '0 4px 4px 0',
        }}
      >
        <p><strong style={{ color: colors.text }}>{tier.coach_level}</strong> — {COACH_LABELS[tier.coach_level] || tier.coach_level}</p>
      </blockquote>

      {nextTier && nextTierName && (
        <>
          <hr />
          <h2>Ce que tu n'as pas encore</h2>
          <blockquote
            style={{
              borderLeft: `3px solid ${TIER_COLORS[nextTierName].border}`,
              background: TIER_COLORS[nextTierName].bg,
              padding: '0.5rem 1rem',
              borderRadius: '0 4px 4px 0',
            }}
          >
            <p>
              <strong style={{ color: TIER_COLORS[nextTierName].text }}>
                {TIER_COLORS[nextTierName].emoji} {nextTierName}
              </strong>
              {' '}te donne : +{nextTier.agents_count - tier.agents_count} agents, +{nextTier.sessions_count - tier.sessions_count} sessions.
            </p>
            <p style={{ color: '#9ca3af' }}>{nextTier.description}</p>
          </blockquote>
        </>
      )}

      {tierName === 'full' && (
        <>
          <hr />
          <h2>Tu as tout</h2>
          <p>C'est ton brain. Tu peux modifier n'importe quel agent, forger les tiens, restructurer le kernel. Le seul gate c'est toi.</p>
        </>
      )}
    </div>
  )
}
