import { useState, useEffect } from 'react'

const USE_MOCK = import.meta.env.VITE_USE_MOCK !== 'false'
const API_BASE = import.meta.env.VITE_BRAIN_API ?? ''

export interface TierInfo {
  tier: 'owner' | 'pro' | 'free'
  features: string[]
  kernel_access: boolean
}

const MOCK_TIER: TierInfo = {
  tier: 'owner',
  features: ['cosmos', 'workspace', 'workflows', 'builder', 'secrets', 'infra', 'editor'],
  kernel_access: true,
}

export function useTier() {
  const [tierInfo, setTierInfo] = useState<TierInfo>(MOCK_TIER)
  const [loading, setLoading] = useState(!USE_MOCK)

  useEffect(() => {
    if (USE_MOCK) {
      setTierInfo(MOCK_TIER)
      setLoading(false)
      return
    }

    fetch(`${API_BASE}/tier`, { credentials: 'include' })
      .then((r) => r.json())
      .then((data: TierInfo) => setTierInfo(data))
      .catch(() => setTierInfo(MOCK_TIER))
      .finally(() => setLoading(false))
  }, [])

  const hasFeature = (feature: string) => tierInfo.features.includes(feature)

  return { tierInfo, loading, hasFeature }
}
