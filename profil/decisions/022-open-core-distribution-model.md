---
name: 022-open-core-distribution-model
type: decision
context_tier: warm
status: actif
---

# ADR-022 — Modèle de distribution open-core

> Date : 2026-03-17
> Statut : actif
> Décidé par : brainstorm navigate + coach (session 2026-03-17 ~23h)

---

## Contexte

Brainstorm sur la vision produit et la frontière kernel/locked.
Question centrale : distribuer le kernel seul, ou kernel + capacité de distillation ?

---

## Décision

**Modèle open-core :**
- **Kernel** = forkable, open, chaque fork = instance propriétaire
- **Features avancées** = locked derrière `keys.tetardtek.com` (PayByFeature existant)
- **MCP** = pont entre distribution OS (fork/own) et runtime BaaS (instance expose un service)

---

## Frontière free / paid

| Free (kernel) | Paid (PayByFeature — clé) |
|---|---|
| Structure brain + agents | Distillation engine |
| Coach de base (présence, pousse à progresser) | Coach complet (milestones, progression tracée) |
| Sessions typées + mémoire globale | BACT / SYMSEC |
| Agents métier | Multi-session orchestration + ambient layer |
| | Brain qui grandit seul (brain-state-bot, phi-3-mini) |

---

## Modèle de distribution

```
git clone brain-template   → kernel propre (pas l'instance perso)
claude → CLAUDE.md boot    → Claude IS l'onboarding (pas de wizard)
keys.tetardtek.com          → gate PayByFeature sur features locked
```

Chaque fork = instance propriétaire. L'humain possède son brain.
Sans clé = rails sans le train. Utilisable, pas transformatif.

---

## Le vrai différenciateur

Pas les agents qui travaillent ensemble (commodity — n8n, Make font ça).
**La continuité de contexte dans le temps.** Un brain qui connaît qui tu es,
trace ta progression, te pousse à grandir. Ça ne se reproduit pas sans la clé
et sans avoir accumulé du contexte sur la durée.

---

## Ce qui n'est PAS encore prêt

- `brain-template` incomplet : mélange instance perso + kernel distribuable
- Séparation perso/kernel à finaliser avant toute distribution publique

---

## Cible

N'importe quel dev qui ouvre le repo dans Claude Code comprend en 20 minutes.
Claude = l'onboarding. `git clone + claude` = installation complète.
Horizon distribution : post-Avril 2026 (brain still owner-only jusqu'au 2026-04).

---

## Références

- ADR-006 (BaaS) — compatible, pas exclusif
- ADR-007 (distribution kernel) — prérequis
- `brain-key-server` + `keys.tetardtek.com` — gate existant
- `brain-template/` — repo distribution (à compléter)
