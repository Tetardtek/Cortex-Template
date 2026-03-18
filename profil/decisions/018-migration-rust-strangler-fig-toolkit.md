---
scope: kernel
name: 018-migration-rust-strangler-fig-toolkit
type: decision
context_tier: warm
---

# ADR-018 — Migration Rust : strangler fig + toolkit pattern

> Date : 2026-03-17
> Statut : actif
> Décidé par : brainstorm session brain

---

## Contexte

Le brain-engine actuel est en Python (FastAPI). Deux problèmes émergent à mesure que le modèle d'utilisation se précise :

1. **BSI sur git n'est pas viable** pour l'async multimodal — git est synchrone et lourd. Un vrai bus d'événements async requiert un backend capable de gérer des channels, du state en mémoire, et de la persistance légère.

2. **Cold start multi-plateforme** — le modèle d'utilisation cible (session pilote + sessions doc + CLI futur) implique de tourner sur laptop, VPS, et potentiellement d'autres machines. Une dépendance Python (venv, pip, uvicorn, FastAPI) est un frein.

Rust répond aux deux : binaire unique cross-platform, `tokio` pour l'async réel, performances natives.

---

## Décision

Migration **progressive** de brain-engine vers Rust via le pattern **strangler fig** :

1. Python brain-engine reste en prod pendant toute la migration
2. Un service Rust monte en parallèle sur un port distinct
3. Apache redirige les endpoints un par un vers Rust dès qu'ils sont stables
4. Quand Rust couvre ~80% des endpoints, Python est éteint

**Ordre de migration :**

```
Phase 1 — Fondations (forge les patterns toolkit)
  /health        → Axum hello world + config loading
  /state         → tokio + pm2 query + JSON response

Phase 2 — Core read-only
  /agents        → SQLite read + Layer 2 gate
  /workflows     → état dérivé
  /focus         → lecture fichier

Phase 3 — Write + auth
  /brain/:path   → write + tier enforcement
  /tier          → key validation

Phase 4 — RAG (dernière, la plus Python-dépendante)
  /boot          → embeddings → à évaluer selon maturité Rust ML
```

---

## Toolkit pattern — KPI stonks

Chaque endpoint extrait des **patterns réutilisables** qui s'appliquent aux suivants :

```rust
// Ces 4 patterns apparaissent sur chaque endpoint
// On les forge une fois sur /health + /state

1. Auth middleware     → x-api-key validation
2. _is_localhost()     → Layer 2 gate
3. JSON response       → helpers 200/401/403/404
4. Config struct       → env vars → typed config
```

**Courbe de vélocité :**
```
Endpoint 1 (/health)  → 2 jours  (Rust + forge toolkit)
Endpoint 2 (/state)   → 4h       (patterns existent)
Endpoint 3+           → 30min    (composition pure)
```

Le toolkit brain-rust devient lui-même distribuable — partie du kernel open.

---

## Stack cible

| Besoin | Crate |
|--------|-------|
| HTTP async | `axum` (tokio-based) |
| Async runtime | `tokio` |
| Sérialisation | `serde` + `serde_json` |
| SQLite | `rusqlite` ou `sqlx` |
| Config env | `dotenvy` |
| Process query (pm2) | `std::process::Command` + parse JSON |

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Rester Python | Cold start lourd, pas de binaire unique, bus async limité |
| Greenfield Rust | Big bang = risque, Python en prod = valeur certaine à ne pas perdre |
| Go | Rust = binaire plus léger, memory safety compile-time, "le pti crab fait de l'oeil" |
| Node.js | Déjà Python en prod, pas besoin d'ajouter un 3e runtime |

---

## Conséquences

**Positives :**
- Zéro downtime pendant la migration
- Apprentissage Rust progressif sur des vrais endpoints en prod
- Chaque iteration dégage un toolkit réutilisable
- Binaire unique → cold start trivial sur toute plateforme
- BSI v2 possible : vrai bus async (tokio channels + SQLite)

**Négatives / trade-offs assumés :**
- Deux services à maintenir pendant la transition
- Phase RAG (embeddings) : Rust ML moins mature que Python — décision reportée
- Temps d'apprentissage Rust non nul sur les premières itérations

---

## Références

- Fichiers concernés : `brain-engine/` (Python, à migrer), futur `brain-engine-rs/`
- ADR-015 : architecture L1/L2
- ADR-016 : BSI → now.md (le bus async justifie Rust)
- ADR-017 : brain_state Layer 2 (premier endpoint candidat Phase 1)
- Sessions où la décision a émergé : session brain 2026-03-17
