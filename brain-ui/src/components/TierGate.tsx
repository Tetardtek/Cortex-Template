import type { ReactNode } from 'react'
import DemoPreview from './DemoPreview'

const DEMO_MODE = import.meta.env.VITE_DEMO_MODE === 'true'

interface TierGateProps {
  feature: string
  hasFeature: (f: string) => boolean
  fallback?: ReactNode
  children: ReactNode
}

export default function TierGate({ feature, hasFeature, fallback, children }: TierGateProps) {
  if (!hasFeature(feature)) {
    if (DEMO_MODE) {
      return <DemoPreview feature={feature} />
    }
    return fallback ? <>{fallback}</> : (
      <div className="flex flex-col items-center justify-center h-full" style={{ color: '#4b5563' }}>
        <div className="text-3xl mb-3">🔒</div>
        <div className="text-sm font-medium">Fonctionnalité non disponible</div>
        <div className="text-xs mt-1 font-mono" style={{ color: '#374151' }}>{feature} — tier insuffisant</div>
      </div>
    )
  }
  return <>{children}</>
}
