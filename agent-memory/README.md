---
name: agent-memory
type: reference
context_tier: cold
---

# agent-memory/ — Couche L3a : mémoire privée des agents

> ADR de référence : ADR-012 (modèle de contexte L3a/L3b/L0)
> Northstar : ADR-011 (autonomie brain)
> Créé : 2026-03-16 — patch(l3a) shadow-sql

---

## Qu'est-ce que L3a

```
L0   agents/<agent>.md         ← graduation maximale — spec enrichie (kernel)
L3b  toolkit/<domaine>/        ← patterns promus, validés en prod, partagés
L3a  agent-memory/<agent>/     ← accumulation privée, non encore validée
```

L3a est la couche d'accumulation **privée** d'un agent sur ses projets réels.
Ce qu'il observe, tente, mesure — avant que ce soit assez solide pour entrer dans toolkit (L3b).

**Règle fondamentale :** brain-engine ne touche jamais aux `.md` de L3a.
Les `.md` restent souverains. SQLite (BE-1) indexera L3a — il n'en sera pas la source.

---

## Structure

```
agent-memory/
├── README.md                          ← ce fichier
├── _template/
│   ├── kpi.yml.example                ← template KPI par stack
│   └── observations.md.example       ← template observations session
└── <agent>/
    └── <projet>/
        ├── kpi.yml                    ← KPIs mesurés (alimenté par metabolism-scribe)
        ├── observations.md            ← patterns tentés, résultats, notes de session
        └── validated.md              ← patterns validés ≥ N fois (prêts graduation L3b)
```

---

## Cycle de vie

```
Session close (scope = <projet>) :
  metabolism-scribe → écrit/update agent-memory/<agent>/<projet>/kpi.yml
  metabolism-scribe → append agent-memory/<agent>/<projet>/observations.md

kpi_score stable + validations ≥ 3 :
  metabolism-scribe → signal toolkit-scribe
  toolkit-scribe → promotion L3b (toolkit/<domaine>/)
  kpi.yml → graduated: true

L3b consensus inter-projets (≥ 2 projets) :
  toolkit-scribe → signal scribe
  scribe → enrichissement L0 (agents/<agent>.md)
```

---

## Règle TTL

Un répertoire `agent-memory/<agent>/<projet>/` sans mise à jour depuis > 90 sessions
est candidate à l'archivage. Signal : `agent-review` lors de l'audit périodique.

Jamais supprimé automatiquement — décision humaine requise.
L'historique est précieux même après graduation.

---

## Agents propriétaires

| Qui écrit | Quoi | Quand |
|-----------|------|-------|
| `metabolism-scribe` | `kpi.yml` + `observations.md` | Session close sur un projet |
| `toolkit-scribe` | `validated.md` → promotion L3b | Seuil KPI atteint |
| `agent-review` | Audit TTL + graduation | Audit périodique |

**Jamais :** un agent métier n'écrit directement dans `agent-memory/` (scribe pattern).

---

## Lien avec BE-1 (SQLite)

BE-1 ingère `agent-memory/` en lecture seule :
```sql
-- Table agent_memory alimentée depuis les kpi.yml
agent_memory(agent, projet, stack, pattern_id, validations, kpi_score, graduated, updated_at)
```

La migration BE-1 parsera les `kpi.yml` existants.
Les `.yml` restent la source de vérité. SQLite = index queryable.
