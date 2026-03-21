import { useState, useEffect, useCallback } from 'react'

const API = import.meta.env.VITE_BRAIN_API ?? ''

interface SearchResult {
  score: number
  title: string
  filepath: string
  excerpt: string
}

interface HealthData {
  status: string
  indexed: number
  uptime: number
}

interface ClaimData {
  sess_id: string
  type: string
  scope: string
  status: string
  opened_at: string
  closed_at: string | null
}

interface AgentData {
  id: string
  label: string
  tier: string
  status: string
  scope: string
}

interface DocData {
  name: string
  label: string
  group: string
}

function formatUptime(seconds: number): string {
  if (seconds < 60) return `${seconds}s`
  if (seconds < 3600) return `${Math.floor(seconds / 60)}min`
  if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ${Math.floor((seconds % 3600) / 60)}min`
  return `${Math.floor(seconds / 86400)}j ${Math.floor((seconds % 86400) / 3600)}h`
}

function formatTimeAgo(dateStr: string): string {
  const diff = Date.now() - new Date(dateStr).getTime()
  const mins = Math.floor(diff / 60000)
  if (mins < 1) return "à l'instant"
  if (mins < 60) return `il y a ${mins}min`
  const hours = Math.floor(mins / 60)
  if (hours < 24) return `il y a ${hours}h`
  const days = Math.floor(hours / 24)
  return `il y a ${days}j`
}

function StatCard({ label, value, sub, color }: { label: string; value: string | number; sub?: string; color?: string }) {
  return (
    <div style={{
      background: '#141414', border: '1px solid #2a2a2a', borderRadius: 8,
      padding: '16px 20px', flex: '1 1 0', minWidth: 140,
    }}>
      <div style={{ fontSize: 11, color: '#6b7280', fontFamily: 'monospace', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
        {label}
      </div>
      <div style={{ fontSize: 28, fontWeight: 700, color: color ?? '#e5e7eb', marginTop: 4 }}>
        {value}
      </div>
      {sub && (
        <div style={{ fontSize: 11, color: '#4b5563', marginTop: 2, fontFamily: 'monospace' }}>
          {sub}
        </div>
      )}
    </div>
  )
}

function SessionRow({ claim }: { claim: ClaimData }) {
  const isOpen = claim.status === 'open'
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '10px 16px', borderBottom: '1px solid #1e1e1e',
    }}>
      <span style={{
        width: 8, height: 8, borderRadius: '50%', flexShrink: 0,
        background: isOpen ? '#22c55e' : '#4b5563',
      }} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 13, color: '#e5e7eb', fontFamily: 'monospace' }}>
          {claim.sess_id}
        </div>
        <div style={{ fontSize: 11, color: '#6b7280', marginTop: 2 }}>
          {claim.type} — {claim.scope}
        </div>
      </div>
      <div style={{ fontSize: 11, color: '#4b5563', fontFamily: 'monospace', flexShrink: 0 }}>
        {formatTimeAgo(claim.opened_at)}
      </div>
    </div>
  )
}

function FileViewer({ path, onClose }: { path: string; onClose: () => void }) {
  const [content, setContent] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetch(`${API}/brain/${path}`)
      .then(r => { if (!r.ok) throw new Error(`${r.status}`); return r.json() })
      .then(d => setContent(d.content))
      .catch(e => setError(`Impossible de charger ${path}: ${e.message}`))
  }, [path])

  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 50,
      background: 'rgba(0,0,0,0.7)', display: 'flex', alignItems: 'center', justifyContent: 'center',
    }} onClick={onClose}>
      <div
        style={{
          background: '#141414', border: '1px solid #2a2a2a', borderRadius: 12,
          width: '70%', maxWidth: 800, maxHeight: '80vh',
          display: 'flex', flexDirection: 'column', overflow: 'hidden',
        }}
        onClick={e => e.stopPropagation()}
      >
        <div style={{
          padding: '12px 20px', borderBottom: '1px solid #2a2a2a',
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        }}>
          <span style={{ fontSize: 13, fontFamily: 'monospace', color: '#818cf8' }}>{path}</span>
          <button
            onClick={onClose}
            style={{ background: 'none', border: 'none', color: '#6b7280', cursor: 'pointer', fontSize: 18 }}
          >
            ×
          </button>
        </div>
        <div style={{ padding: '16px 20px', overflowY: 'auto', flex: 1 }}>
          {error && <div style={{ color: '#ef4444', fontSize: 13 }}>{error}</div>}
          {!content && !error && <div style={{ color: '#4b5563', fontSize: 13, fontFamily: 'monospace' }}>Chargement...</div>}
          {content && (
            <pre style={{
              fontSize: 13, lineHeight: 1.6, color: '#d1d5db',
              fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
              whiteSpace: 'pre-wrap', wordBreak: 'break-word', margin: 0,
            }}>
              {content}
            </pre>
          )}
        </div>
      </div>
    </div>
  )
}

function SearchBar() {
  const [query, setQuery] = useState('')
  const [results, setResults] = useState<SearchResult[]>([])
  const [searching, setSearching] = useState(false)
  const [searched, setSearched] = useState(false)
  const [viewingFile, setViewingFile] = useState<string | null>(null)

  const search = useCallback(async (q: string) => {
    if (q.trim().length < 2) { setResults([]); setSearched(false); return }
    setSearching(true)
    try {
      const res = await fetch(`${API}/search?q=${encodeURIComponent(q)}&top=6`)
      if (!res.ok) throw new Error()
      const data = await res.json()
      setResults(data.results ?? [])
      setSearched(true)
    } catch {
      setResults([])
    } finally {
      setSearching(false)
    }
  }, [])

  useEffect(() => {
    const timer = setTimeout(() => { if (query.trim().length >= 2) search(query) }, 400)
    return () => clearTimeout(timer)
  }, [query, search])

  return (
    <div style={{ marginBottom: 24 }}>
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        background: '#141414', border: '1px solid #2a2a2a', borderRadius: 8,
        padding: '8px 16px',
      }}>
        <span style={{ color: '#4b5563', fontSize: 16 }}>🔍</span>
        <input
          type="text"
          placeholder="Rechercher dans le brain..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onKeyDown={(e) => { if (e.key === 'Enter') search(query) }}
          style={{
            flex: 1, background: 'transparent', border: 'none', outline: 'none',
            color: '#e5e7eb', fontSize: 14, fontFamily: 'inherit',
          }}
        />
        {searching && <span style={{ color: '#4b5563', fontSize: 12, fontFamily: 'monospace' }}>...</span>}
      </div>
      {searched && results.length > 0 && (
        <div style={{
          marginTop: 8, background: '#141414', border: '1px solid #2a2a2a',
          borderRadius: 8, overflow: 'hidden',
        }}>
          {results.map((r, i) => (
            <div key={i} style={{
              padding: '12px 16px', borderBottom: i < results.length - 1 ? '1px solid #1e1e1e' : 'none',
              cursor: 'pointer', transition: 'background 0.15s',
            }}
            onClick={() => setViewingFile(r.filepath)}
            onMouseEnter={e => (e.currentTarget.style.background = '#1a1a1a')}
            onMouseLeave={e => (e.currentTarget.style.background = 'transparent')}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
                <span style={{ fontSize: 12, fontFamily: 'monospace', color: '#818cf8' }}>
                  {r.filepath}
                </span>
                <span style={{
                  fontSize: 10, fontFamily: 'monospace', color: '#4b5563',
                  marginLeft: 'auto',
                }}>
                  {(r.score * 100).toFixed(0)}%
                </span>
              </div>
              <div style={{ fontSize: 13, color: '#9ca3af', lineHeight: 1.5 }}>
                {r.excerpt.slice(0, 200)}{r.excerpt.length > 200 ? '...' : ''}
              </div>
            </div>
          ))}
        </div>
      )}
      {searched && results.length === 0 && !searching && (
        <div style={{ marginTop: 8, fontSize: 13, color: '#4b5563', fontFamily: 'monospace', padding: '8px 16px' }}>
          Aucun résultat pour "{query}"
        </div>
      )}
      {viewingFile && <FileViewer path={viewingFile} onClose={() => setViewingFile(null)} />}
    </div>
  )
}

export default function Dashboard() {
  const [health, setHealth] = useState<HealthData | null>(null)
  const [claims, setClaims] = useState<ClaimData[]>([])
  const [agents, setAgents] = useState<AgentData[]>([])
  const [docs, setDocs] = useState<DocData[]>([])
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    Promise.allSettled([
      fetch(`${API}/health`).then(r => r.json()),
      fetch(`${API}/bsi/claims`).then(r => r.ok ? r.json() : []),
      fetch(`${API}/agents`).then(r => r.ok ? r.json() : []),
      fetch(`${API}/docs`).then(r => r.ok ? r.json() : { docs: [] }),
    ]).then(([h, c, a, d]) => {
      if (h.status === 'fulfilled') setHealth(h.value)
      if (c.status === 'fulfilled') setClaims(Array.isArray(c.value) ? c.value : [])
      if (a.status === 'fulfilled') setAgents(Array.isArray(a.value) ? a.value : [])
      if (d.status === 'fulfilled') setDocs(d.value?.docs ?? [])
    }).catch(() => setError('Impossible de charger les données'))
  }, [])

  const openClaims = claims.filter(c => c.status === 'open')
  const recentClaims = claims.slice(0, 8)
  const agentsByTier = agents.reduce<Record<string, number>>((acc, a) => {
    acc[a.tier] = (acc[a.tier] || 0) + 1
    return acc
  }, {})

  return (
    <div style={{ padding: '2rem 3rem', overflowY: 'auto', height: '100%' }}>
      {/* Header */}
      <div style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 20, fontWeight: 700, color: '#fff', margin: 0 }}>
          Dashboard
        </h1>
        <p style={{ fontSize: 12, color: '#4b5563', fontFamily: 'monospace', marginTop: 4 }}>
          {health ? `brain-engine up — ${formatUptime(health.uptime)}` : 'connexion...'}
        </p>
      </div>

      {error && (
        <div style={{ color: '#ef4444', fontSize: 13, marginBottom: 16 }}>{error}</div>
      )}

      {/* Search */}
      <SearchBar />

      {/* Stats row */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
        <StatCard
          label="Embeddings"
          value={health?.indexed?.toLocaleString() ?? '—'}
          sub="chunks indexés"
          color="#818cf8"
        />
        <StatCard
          label="Agents"
          value={agents.length || '—'}
          sub={Object.entries(agentsByTier).map(([t, n]) => `${n} ${t}`).join(' · ') || undefined}
          color="#22c55e"
        />
        <StatCard
          label="Docs"
          value={docs.length || '—'}
          sub="pages live"
          color="#f59e0b"
        />
        <StatCard
          label="Sessions"
          value={openClaims.length}
          sub={openClaims.length > 0 ? 'actives' : 'aucune active'}
          color={openClaims.length > 0 ? '#22c55e' : '#6b7280'}
        />
      </div>

      {/* Two columns */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        {/* Recent sessions */}
        <div style={{ background: '#141414', border: '1px solid #2a2a2a', borderRadius: 8, overflow: 'hidden' }}>
          <div style={{
            padding: '12px 16px', borderBottom: '1px solid #2a2a2a',
            fontSize: 12, fontFamily: 'monospace', color: '#6b7280',
            textTransform: 'uppercase', letterSpacing: '0.05em',
          }}>
            Sessions récentes
          </div>
          {recentClaims.length === 0 ? (
            <div style={{ padding: 16, fontSize: 13, color: '#4b5563' }}>
              Aucune session enregistrée
            </div>
          ) : (
            recentClaims.map(c => <SessionRow key={c.sess_id} claim={c} />)
          )}
        </div>

        {/* Quick links */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {/* Agents by scope */}
          <div style={{ background: '#141414', border: '1px solid #2a2a2a', borderRadius: 8, overflow: 'hidden' }}>
            <div style={{
              padding: '12px 16px', borderBottom: '1px solid #2a2a2a',
              fontSize: 12, fontFamily: 'monospace', color: '#6b7280',
              textTransform: 'uppercase', letterSpacing: '0.05em',
            }}>
              Agents par scope
            </div>
            <div style={{ padding: 16, display: 'flex', gap: 16, flexWrap: 'wrap' }}>
              {Object.entries(
                agents.reduce<Record<string, number>>((acc, a) => {
                  acc[a.scope || 'unknown'] = (acc[a.scope || 'unknown'] || 0) + 1
                  return acc
                }, {})
              ).map(([scope, count]) => (
                <div key={scope} style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: 20, fontWeight: 700, color: '#e5e7eb' }}>{count}</div>
                  <div style={{ fontSize: 10, color: '#6b7280', fontFamily: 'monospace' }}>{scope}</div>
                </div>
              ))}
            </div>
          </div>

          {/* Docs groups */}
          <div style={{ background: '#141414', border: '1px solid #2a2a2a', borderRadius: 8, overflow: 'hidden' }}>
            <div style={{
              padding: '12px 16px', borderBottom: '1px solid #2a2a2a',
              display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            }}>
              <span style={{ fontSize: 12, fontFamily: 'monospace', color: '#6b7280', textTransform: 'uppercase', letterSpacing: '0.05em' }}>
                Documentation
              </span>
              <a href="/docs" target="_blank" rel="noopener noreferrer"
                style={{ fontSize: 11, color: '#818cf8', textDecoration: 'none', fontFamily: 'monospace' }}>
                Ouvrir ↗
              </a>
            </div>
            <div style={{ padding: 16, display: 'flex', gap: 16, flexWrap: 'wrap' }}>
              {Object.entries(
                docs.reduce<Record<string, number>>((acc, d) => {
                  acc[d.group || 'Autres'] = (acc[d.group || 'Autres'] || 0) + 1
                  return acc
                }, {})
              ).map(([group, count]) => (
                <div key={group} style={{ textAlign: 'center' }}>
                  <div style={{ fontSize: 20, fontWeight: 700, color: '#e5e7eb' }}>{count}</div>
                  <div style={{ fontSize: 10, color: '#6b7280', fontFamily: 'monospace' }}>{group}</div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
