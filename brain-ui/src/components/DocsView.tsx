import { useState, useEffect, ReactNode } from 'react'
import ReactMarkdown, { Components } from 'react-markdown'

interface DocFile {
  name: string
  label: string
  path: string
  group?: string
}

const DOCS: DocFile[] = [
  { name: 'getting-started', label: 'Demarrer', path: import.meta.env.BASE_URL + 'docs/getting-started.md', group: 'Guides' },
  { name: 'architecture', label: 'Architecture', path: import.meta.env.BASE_URL + 'docs/architecture.md', group: 'Guides' },
  { name: 'sessions', label: 'Sessions', path: import.meta.env.BASE_URL + 'docs/sessions.md', group: 'Guides' },
  { name: 'satellites', label: 'Satellites', path: import.meta.env.BASE_URL + 'docs/satellites.md', group: 'Guides' },
  { name: 'brain-engine-guide', label: 'Brain-engine', path: import.meta.env.BASE_URL + 'docs/brain-engine-guide.md', group: 'Guides' },
  { name: 'workflows', label: 'Workflows', path: import.meta.env.BASE_URL + 'docs/workflows.md', group: 'Guides' },
  { name: 'agents', label: 'Vue d\'ensemble', path: import.meta.env.BASE_URL + 'docs/agents.md', group: 'Agents' },
  { name: 'agents-code', label: 'Code & Qualite', path: import.meta.env.BASE_URL + 'docs/agents-code.md', group: 'Agents' },
  { name: 'agents-infra', label: 'Infra & Deploy', path: import.meta.env.BASE_URL + 'docs/agents-infra.md', group: 'Agents' },
  { name: 'agents-brain', label: 'Brain & Systeme', path: import.meta.env.BASE_URL + 'docs/agents-brain.md', group: 'Agents' },
  { name: 'vue-tiers', label: 'Comparatif', path: import.meta.env.BASE_URL + 'docs/vue-tiers.md', group: 'Vues' },
  { name: 'vue-free', label: '🟢 free', path: import.meta.env.BASE_URL + 'docs/vue-free.md', group: 'Vues' },
  { name: 'vue-featured', label: '🔵 featured', path: import.meta.env.BASE_URL + 'docs/vue-featured.md', group: 'Vues' },
  { name: 'vue-pro', label: '🟠 pro', path: import.meta.env.BASE_URL + 'docs/vue-pro.md', group: 'Vues' },
  { name: 'vue-full', label: '🟣 full', path: import.meta.env.BASE_URL + 'docs/vue-full.md', group: 'Vues' },
]

// Detect tier markers in blockquote content and apply CSS class
const TIER_MARKERS: Record<string, string> = {
  '\u{1F7E2}': 'tier-free',     // 🟢
  '\u{1F535}': 'tier-featured',  // 🔵
  '\u{1F7E0}': 'tier-pro',      // 🟠
  '\u{1F7E3}': 'tier-full',     // 🟣
}

function extractText(children: ReactNode): string {
  if (typeof children === 'string') return children
  if (Array.isArray(children)) return children.map(extractText).join('')
  if (children && typeof children === 'object' && 'props' in children) {
    return extractText((children as { props: { children?: ReactNode } }).props.children)
  }
  return ''
}

const mdComponents: Components = {
  blockquote({ children }) {
    const text = extractText(children)
    let tierClass = ''
    for (const [marker, cls] of Object.entries(TIER_MARKERS)) {
      if (text.includes(marker)) {
        tierClass = cls
        break
      }
    }
    return <blockquote className={tierClass || undefined}>{children}</blockquote>
  },
}

export default function DocsView() {
  const [activeDoc, setActiveDoc] = useState<string>('getting-started')
  const [content, setContent] = useState<string>('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    const doc = DOCS.find((d) => d.name === activeDoc)
    if (!doc) return

    setLoading(true)
    setError(null)

    fetch(doc.path)
      .then((res) => {
        if (!res.ok) throw new Error(`${res.status}`)
        return res.text()
      })
      .then((text) => {
        const stripped = text.replace(/^---[\s\S]*?---\n*/, '')
        setContent(stripped)
        setLoading(false)
      })
      .catch((err) => {
        setError(`Impossible de charger ${doc.path}: ${err.message}`)
        setLoading(false)
      })
  }, [activeDoc])

  // Group docs by group
  const groups = DOCS.reduce<Record<string, DocFile[]>>((acc, doc) => {
    const g = doc.group || 'Autres'
    if (!acc[g]) acc[g] = []
    acc[g].push(doc)
    return acc
  }, {})

  return (
    <div className="flex h-full overflow-hidden">
      {/* Sidebar docs */}
      <div
        className="flex flex-col flex-shrink-0 border-r overflow-y-auto"
        style={{ width: 200, borderColor: '#2a2a2a', background: '#141414' }}
      >
        <div className="px-3 py-3 border-b" style={{ borderColor: '#2a2a2a' }}>
          <span className="text-xs font-mono" style={{ color: '#6b7280' }}>
            Documentation
          </span>
        </div>
        <nav className="flex flex-col gap-0.5 p-2">
          {Object.entries(groups).map(([group, docs]) => (
            <div key={group}>
              <div
                className="text-xs font-mono px-3 py-1.5 mt-2"
                style={{ color: '#4b5563', letterSpacing: '0.05em' }}
              >
                {group.toUpperCase()}
              </div>
              {docs.map((doc) => (
                <button
                  key={doc.name}
                  onClick={() => setActiveDoc(doc.name)}
                  className="text-left px-3 py-1.5 rounded text-sm transition-colors w-full"
                  style={
                    activeDoc === doc.name
                      ? { background: 'rgba(99,102,241,0.15)', color: '#818cf8' }
                      : { color: '#9ca3af' }
                  }
                >
                  {doc.label}
                </button>
              ))}
            </div>
          ))}
        </nav>
      </div>

      {/* Content */}
      <div className="flex-1 overflow-y-auto" style={{ padding: '2rem 3rem' }}>
        {loading && (
          <div style={{ color: '#4b5563' }} className="text-sm font-mono">
            Chargement...
          </div>
        )}
        {error && (
          <div style={{ color: '#ef4444' }} className="text-sm font-mono">
            {error}
          </div>
        )}
        {!loading && !error && (
          <article className="docs-markdown">
            <ReactMarkdown components={mdComponents}>{content}</ReactMarkdown>
          </article>
        )}
      </div>
    </div>
  )
}
