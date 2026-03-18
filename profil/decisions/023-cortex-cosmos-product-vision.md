---
scope: kernel
name: 023-cortex-cosmos-product-vision
type: decision
context_tier: warm
status: vision
---

# ADR-023 — CORTEX + Cosmos — Vision produit et naming

> Date : 2026-03-17
> Statut : vision — implémentation au premier push public GitHub
> Décidé par : brainstorm navigate + coach (session 2026-03-17 ~23h)

---

## Naming évolution

| Actuel | Futur | Pourquoi |
|--------|-------|----------|
| brain | **CORTEX** | Plus précis — centre de traitement, pas l'organe. Kernel cognitif. |
| brain-ui | **Cosmos** | Interface orbitale — ce qui gravite autour de CORTEX |
| projets | **Satellites** | Naturels — pas des extensions, des orbites |

**Quand renommer :** au premier push public sur GitHub. Pas avant.
Tous les repos brain-* restent inchangés jusqu'à ce moment.

---

## Architecture produit

```
CORTEX          — le kernel cognitif (OS distribué, forkable)
  ↑ expose
Cosmos          — UI orbitale (chat, clés API, secrets, feature flags)
  ↑ orbite
Satellites      — projets, outils, contextes personnels
```

---

## Vision Cosmos (UI)

Interface Rust accessible par les bons agents au bon moment :
- Onglet **Chat** — interface principale
- Onglet **Clés API** — gestion `brain-compose.local.yml`
- Onglet **Secrets** — accès contrôlé MYSECRETS par agents autorisés
- Onglet **Features** — `user.featureEnh(coach=on, frigo=on, ...)`

`user.featureEnh()` = API de personnalisation cognitive.
Chaque user configure son CORTEX comme il configure son terminal.
PayByFeature s'exprime ici — activer/désactiver selon tier + préférences.

---

## Ce que le naming révèle

CORTEX n'est pas un renommage cosmétique. C'est la formalisation de ce qui
était senti avant d'être articulé :

- Brain = organe entier (trop large)
- CORTEX = centre de traitement = kernel (précis)
- Cosmos = l'espace où les satellites gravitent (scalable à l'infini)

Le nom s'est imposé par récursivité — en voyant émerger la structure,
pas en la décidant.

---

## Coexistence avec l'existant

CORTEX coexiste avec tout ce qui a été construit.
Les ADRs 001-022 restent valides — le naming change, l'architecture non.
brain-template → cortex-template au premier push public.

---

## Références

- ADR-022 (open-core distribution) — modèle de distribution CORTEX
- brain-ui (futur Cosmos) — UI orbitale
- `keys.<OWNER_DOMAIN>` — gate PayByFeature pour user.featureEnh()
