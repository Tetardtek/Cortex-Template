---
name: ADR-012
type: decision
context_tier: cold
---

# ADR-012 — Modèle de contexte : L3a (mémoire privée agent) + protocole de graduation

> Date : 2026-03-15
> Statut : actif
> Décidé par : session sess-20260315-2031-kernel-audit — brainstorm coach + tech-lead

---

## Contexte

Le brain dispose de :
- L0 : kernel (invariant, permanent)
- L1 : session state (TTL session)
- L2 : agent workspace (TTL sprint)
- toolkit/ (patterns validés, partagés) — ce qu'on appelait implicitement L3

Ce qui manquait : une couche entre le travail d'un agent et sa promotion dans le toolkit partagé.
Sans elle, la graduation est manuelle, tardive, ou jamais faite.

---

## Insight fondateur

**Le toolkit est L3b. Il existait déjà. Ce qui manquait : L3a.**

```
L3a  agent/memory/<projet>/   ← accumulation privée, non encore validée
L3b  toolkit/<domaine>/        ← patterns promus, partagés, validés en prod
L0   agents/<agent>.md         ← graduation maximale — spec enrichie
```

L3a est la couche d'accumulation privée de l'agent — ce qu'il observe, tente, apprend sur un projet spécifique — avant que ce soit assez solide pour être partagé.

---

## Décision

Introduire L3a comme couche officielle du modèle de contexte.

```
Structure :
  brain/agent-memory/<agent>/<projet>/
    observations.md   ← ce que l'agent a observé (patterns tentés, résultats)
    validated.md      ← patterns validés N fois sur ce projet
    kpi.yml           ← KPIs par stack : { stack, validations, kpi_score, graduated }

Graduation automatique :
  kpi_score stable + validations ≥ N  →  signal toolkit-scribe  →  promotion L3b
  L3b consensus inter-projets         →  signal scribe           →  enrichissement L0
```

---

## Protocole de graduation

```
Sprint close :
  agent observe pattern → écrit dans L3a/<agent>/<projet>/observations.md

Pattern validé en prod :
  N = 3 validations minimum (configurable par stack)
  metabolism-scribe incrémente kpi.yml

Seuil atteint :
  trigger → toolkit-scribe → L3b (toolkit/<domaine>/)
  agent gagne flag variance sur cette stack
  tech-lead gate optionnel sur cette stack pour cet agent

Variance débloquée :
  l'agent peut proposer des variantes de pattern (pas seulement "le" pattern)
  "j'ai build ça N fois — voici 3 approches selon le contexte"
```

---

## Différence L3a vs L3b

| | L3a | L3b |
|--|-----|-----|
| Scope | Agent × projet | Brain global |
| Ownership | L'agent | toolkit-scribe |
| Accès | Privé (agent en session) | Partagé (tous agents) |
| Contenu | Observations + tentatives | Patterns validés en prod |
| TTL | Permanent (mémoire accumulée) | Permanent (validé) |
| Graduation | → L3b sur seuil KPI | → L0 sur consensus |

---

## Lien avec SQLite (BE-1)

SQLite est le medium naturel pour tracker L3a :
```sql
CREATE TABLE agent_memory (
  agent       TEXT,
  projet      TEXT,
  stack       TEXT,
  pattern_id  TEXT,
  validations INTEGER,
  kpi_score   REAL,
  graduated   BOOLEAN,
  created_at  TEXT
);
```

Requête graduation : `SELECT * FROM agent_memory WHERE validations >= 3 AND graduated = 0`

---

## Conséquences

**Positives :**
- Le tech-lead se décharge progressivement par stack × agent graduée
- Les agents accumulent une expertise réelle mesurable, pas déclarative
- La variance est earned, pas donnée — l'agent propose des alternatives parce qu'il les a vécues
- BE-1 (SQLite) devient la fondation naturelle de L3a tracking

**Négatives / trade-offs :**
- brain/agent-memory/ est un nouveau répertoire satellite à gérer
- La graduation automatique requiert metabolism-scribe enrichi
- Risque : L3a devient une décharge si rien n'est jamais gradué → TTL ou nettoyage requis

---

## Références

- ADR-011 : North Star autonomie — L3a est une brique vers l'autonomie agent
- ADR-003 : Scribe pattern — graduation via toolkit-scribe (non-contamination)
- `todo/brain.md` : BE-1 SQLite — substrate de L3a tracking
- Session source : sess-20260315-2031-kernel-audit
