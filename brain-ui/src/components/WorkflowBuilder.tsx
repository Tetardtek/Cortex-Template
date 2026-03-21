import { useState } from 'react'
import type { StepDraft, WorkflowDraft } from '../types'
import TeamSelector from './TeamSelector'
import { useTeams } from '../hooks/useTeams'

const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''
const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'

function makeId() {
  return Math.random().toString(36).slice(2, 8)
}

export default function WorkflowBuilder() {
  const { teams, isLoading: teamsLoading } = useTeams()

  const [title, setTitle] = useState('')
  const [teamId, setTeamId] = useState<string | null>(null)
  const [steps, setSteps] = useState<StepDraft[]>([
    { id: makeId(), label: '', type: 'step' },
  ])
  const [gateRequired, setGateRequired] = useState(false)
  const [sending, setSending] = useState(false)
  const [result, setResult] = useState<{ ok: boolean; claimId?: string; error?: string } | null>(null)

  // Sync gateRequired depuis le preset sélectionné
  const handleTeamChange = (id: string) => {
    setTeamId(id)
    const preset = teams.find((t) => t.id === id)
    if (preset) setGateRequired(preset.gate_required)
    setResult(null)
  }

  const addStep = (type: 'step' | 'gate') => {
    setSteps((prev) => [...prev, { id: makeId(), label: '', type }])
    setResult(null)
  }

  const updateStep = (id: string, label: string) => {
    setSteps((prev) => prev.map((s) => (s.id === id ? { ...s, label } : s)))
  }

  const removeStep = (id: string) => {
    setSteps((prev) => prev.filter((s) => s.id !== id))
  }

  const moveStep = (id: string, dir: -1 | 1) => {
    setSteps((prev) => {
      const idx = prev.findIndex((s) => s.id === id)
      if (idx < 0) return prev
      const next = idx + dir
      if (next < 0 || next >= prev.length) return prev
      const arr = [...prev]
      ;[arr[idx], arr[next]] = [arr[next], arr[idx]]
      return arr
    })
  }

  const canSend = title.trim().length > 0 && teamId !== null && steps.some((s) => s.label.trim())

  const handleSend = async () => {
    if (!canSend) return
    setSending(true)
    setResult(null)

    const draft: WorkflowDraft = {
      title: title.trim(),
      teamId: teamId!,
      steps: steps.filter((s) => s.label.trim()),
      gateRequired,
    }

    if (USE_MOCK) {
      // Simulation locale
      await new Promise((r) => setTimeout(r, 600))
      const fakeId = `sess-mock-${Date.now()}`
      setResult({ ok: true, claimId: fakeId })
      setSending(false)
      return
    }

    try {
      const token = import.meta.env.VITE_BRAIN_TOKEN ?? ''
      const resp = await fetch(`${API_BASE}/workflows/create`, {
        method: 'POST',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
          ...(token ? { Authorization: `Bearer ${token}` } : {}),
        },
        body: JSON.stringify(draft),
      })
      const data = await resp.json()
      if (resp.ok && data.ok) {
        setResult({ ok: true, claimId: data.claimId })
      } else {
        setResult({ ok: false, error: data.error ?? 'Erreur inconnue' })
      }
    } catch (e) {
      setResult({ ok: false, error: 'Impossible de joindre le kernel' })
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="flex flex-col gap-6 p-6 max-w-2xl">
      <div>
        <h2 className="text-lg font-semibold text-white mb-1">Nouveau workflow</h2>
        <p className="text-sm" style={{ color: '#6b7280' }}>
          Configure et envoie un workflow au kernel brain.
        </p>
      </div>

      {/* Titre */}
      <div className="flex flex-col gap-1.5">
        <label className="text-xs font-medium" style={{ color: '#9ca3af' }}>
          Titre
        </label>
        <input
          autoFocus
          type="text"
          value={title}
          onChange={(e) => { setTitle(e.target.value); setResult(null) }}
          placeholder="ex: Clickerz Sprint 2 — Zustand + Gates"
          className="px-3 py-2 rounded text-sm text-white placeholder-gray-600 outline-none"
          style={{ background: '#1a1a1a', border: '1px solid #2a2a2a' }}
        />
      </div>

      {/* Team preset */}
      <div className="flex flex-col gap-1.5">
        <label className="text-xs font-medium" style={{ color: '#9ca3af' }}>
          Équipe
        </label>
        <TeamSelector
          presets={teams}
          selected={teamId}
          onChange={handleTeamChange}
          isLoading={teamsLoading}
        />
      </div>

      {/* Steps */}
      <div className="flex flex-col gap-1.5">
        <label className="text-xs font-medium" style={{ color: '#9ca3af' }}>
          Étapes
        </label>
        <div className="flex flex-col gap-1">
          {steps.map((step, idx) => (
            <div key={step.id} className="flex items-center gap-2">
              {/* Move */}
              <div className="flex flex-col gap-0.5">
                <button
                  type="button"
                  onClick={() => moveStep(step.id, -1)}
                  disabled={idx === 0}
                  className="text-xs leading-none px-1"
                  style={{ color: idx === 0 ? '#374151' : '#6b7280' }}
                >
                  ▲
                </button>
                <button
                  type="button"
                  onClick={() => moveStep(step.id, 1)}
                  disabled={idx === steps.length - 1}
                  className="text-xs leading-none px-1"
                  style={{ color: idx === steps.length - 1 ? '#374151' : '#6b7280' }}
                >
                  ▼
                </button>
              </div>

              {/* Type badge */}
              <span
                className="text-xs px-1.5 py-0.5 rounded font-mono w-10 text-center flex-shrink-0"
                style={
                  step.type === 'gate'
                    ? { background: 'rgba(245,158,11,0.15)', color: '#f59e0b' }
                    : { background: '#1a1a1a', color: '#6b7280' }
                }
              >
                {step.type === 'gate' ? 'gate' : 'step'}
              </span>

              {/* Label input */}
              <input
                type="text"
                value={step.label}
                onChange={(e) => updateStep(step.id, e.target.value)}
                placeholder={step.type === 'gate' ? 'ex: Review humain' : 'ex: Setup Zustand store'}
                className="flex-1 px-2 py-1.5 rounded text-sm text-white placeholder-gray-600 outline-none"
                style={{ background: '#1a1a1a', border: '1px solid #2a2a2a' }}
              />

              {/* Remove */}
              {steps.length > 1 && (
                <button
                  type="button"
                  onClick={() => removeStep(step.id)}
                  className="text-xs px-1"
                  style={{ color: '#4b5563' }}
                >
                  ✕
                </button>
              )}
            </div>
          ))}
        </div>

        {/* Add step / gate */}
        <div className="flex gap-2 mt-1">
          <button
            type="button"
            onClick={() => addStep('step')}
            className="text-xs px-2 py-1 rounded"
            style={{ background: '#1a1a1a', color: '#9ca3af', border: '1px solid #2a2a2a' }}
          >
            + step
          </button>
          <button
            type="button"
            onClick={() => addStep('gate')}
            className="text-xs px-2 py-1 rounded"
            style={{ background: 'rgba(245,158,11,0.1)', color: '#f59e0b', border: '1px solid rgba(245,158,11,0.2)' }}
          >
            + gate
          </button>
        </div>
      </div>

      {/* Gate required toggle */}
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => { setGateRequired((v) => !v); setResult(null) }}
          className="relative w-10 h-5 rounded-full transition-colors flex-shrink-0"
          style={{ background: gateRequired ? '#6366f1' : '#2a2a2a' }}
        >
          <span
            className="absolute top-0.5 left-0.5 w-4 h-4 rounded-full transition-transform"
            style={{
              background: '#fff',
              transform: gateRequired ? 'translateX(20px)' : 'translateX(0)',
            }}
          />
        </button>
        <span className="text-sm" style={{ color: '#9ca3af' }}>
          Gate humaine requise avant exécution
        </span>
      </div>

      {/* Submit */}
      <div className="flex items-center gap-4">
        <button
          type="button"
          onClick={handleSend}
          disabled={!canSend || sending}
          className="flex items-center gap-2 px-4 py-2 rounded text-sm font-medium transition-opacity"
          style={{
            background: canSend && !sending ? '#6366f1' : '#2a2a2a',
            color: canSend && !sending ? '#fff' : '#4b5563',
            cursor: canSend && !sending ? 'pointer' : 'not-allowed',
          }}
        >
          {sending ? 'Envoi…' : 'Envoyer au kernel ▶'}
        </button>

        {result && (
          <div
            className="text-sm px-3 py-1.5 rounded"
            style={
              result.ok
                ? { background: 'rgba(34,197,94,0.1)', color: '#22c55e' }
                : { background: 'rgba(239,68,68,0.1)', color: '#ef4444' }
            }
          >
            {result.ok ? `✓ Claim créé : ${result.claimId}` : `✗ ${result.error}`}
          </div>
        )}
      </div>
    </div>
  )
}
