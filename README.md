# brain

> Un systeme de contexte persistant pour Claude. Fork, boot, code.

Le brain est un **cerveau externalise** : 75 agents specialises, un protocole de sessions, et une memoire qui persiste entre les conversations. Chaque session repart d'un etat connu. Chaque agent sait ce qu'il fait et ce qu'il ne fait pas.

```
git clone <ce-repo> ~/Dev/Brain
cd ~/Dev/Brain && bash setup.sh
bash brain-engine/start.sh
```

Ouvre Claude Code dans le dossier et tape `brain boot`. C'est tout.

> Guide complet : [docs/getting-started.md](docs/getting-started.md)

---

## Ce que tu as

### Sans cle API — tier free

- **16 agents** : debug, brainstorm, scribe, recruiter, mentor, orchestrator...
- **6 types de sessions** : navigate, work, debug, brainstorm, brain, handoff
- **Coach** en observation — intervient sur risque critique
- **Protection secrets** permanente — le brain ne fuit jamais
- **Protocole BSI** — sessions tracees, multi-instances sans conflit
- **Dashboard web** avec documentation interactive

### Avec cle API — tiers featured, pro, full

Le brain a 4 niveaux. Chaque niveau debloque des agents et des capacites :

**featured** — Le brain te connait. Coach complet avec bilans de session, objectifs, progression tracee. Distillation RAG — le brain se souvient entre sessions.

**pro** — L'atelier complet. Code review (7 priorites), audit securite (8 audits OWASP), tests automatises, 3 optimiseurs perf, deploy VPS + CI/CD + SSL, sessions urgence et infra. 40 agents.

**full** — Ton brain, tes regles. Modification du kernel, copilotage long, supervision multi-phase. 75 agents, 15 sessions, tout.

> Detail complet : ouvre le dashboard (`http://localhost:7700/ui/`) → onglet Docs

---

## Installation

### Prerequis

- Git
- Python 3.10+
- Node.js 18+ et npm
- Claude Code CLI
- Ollama (recommande — active la recherche semantique et le RAG au boot)

### 1. Cloner

```bash
git clone <ce-repo> ~/Dev/Brain
cd ~/Dev/Brain
```

### 2. Setup

```bash
bash setup.sh
```

Le script fait tout : config machine, satellites, dashboard, brain-engine.

### 3. Configurer Claude Code

```bash
cp profil/CLAUDE.md.example ~/.claude/CLAUDE.md
# Editer : brain_root et brain_name
```

### 4. Lancer brain-engine

```bash
bash brain-engine/start.sh
# → http://localhost:7700/ui/  (dashboard + docs)
# → http://localhost:7700/health  (API)
```

### 5. Premier boot

Ouvre Claude Code dans le dossier brain :

```
brain boot
```

Le brain charge le contexte, fait le briefing, et te demande ce que tu veux faire.

---

## Structure

```
brain/
  agents/          75 agents specialises (boot-summary + detail)
  contexts/        10 sessions predefinies
  docs/            14 guides humains (getting-started, architecture, workflows...)
  brain-engine/    moteur local (API, search, RAG, MCP, embeddings)
  brain-ui/        dashboard React (docs, workflows, cosmos 3D)
  scripts/         protocole BSI (claims, locks, gates, feature-gate)
  brain-compose.yml   config, modes, tiers, agents autorises
  KERNEL.md        loi des zones — ce qui est protege

  # Satellites (repos git autonomes, clones par setup.sh)
  profil/          identite, collaboration, decisions architecturales
  todo/            intentions de session
  toolkit/         patterns valides en prod
  progression/     parcours, metriques, bilans
  reviews/         audits agents
```

---

## Comment ca marche

**Les agents se chargent tout seuls.** Tu parles de "bug" → `debug` arrive. Tu dis "deploy" → `vps` + `ci-cd` se chargent.

**Chaque session est isolee.** Un claim BSI trace ce que tu fais. Plusieurs fenetres Claude Code peuvent travailler en parallele sans conflit.

**Le brain se documente.** Les scribes capturent les metriques, mettent a jour les todos, et maintiennent la documentation a chaque session.

**Le kernel est protege.** Les fichiers critiques (KERNEL.md, agents/, profil/) ne se modifient qu'avec confirmation humaine.

---

## Documentation

Ouvre le dashboard (`http://localhost:7700/ui/`) et va dans l'onglet Docs :

- **Demarrer** — les 5 premieres minutes
- **Architecture** — comment les pieces s'assemblent
- **Sessions** — types, permissions, metabolisme
- **Workflows** — recettes d'agents par situation
- **Agents** — catalogue par famille + comparatif tiers
- **Vues par tier** — ce qui est disponible a chaque niveau

---

## Roadmap

- [x] 75 agents avec boot-summary/detail (chargement optimise)
- [x] 4 tiers (free → featured → pro → full)
- [x] Protocole BSI-v3 multi-instances
- [x] brain-engine standalone (API + search + RAG)
- [x] Dashboard web avec docs interactives
- [x] Feature gate par tier
- [ ] brain-engine hosted (distillation managee)
- [ ] Docs dynamiques (generation depuis brain-compose.yml)
- [ ] BaaS multi-tenant

---

## Licence

BSL 1.1 — usage libre sauf hosting commercial. Apache 2.0 en 2028.
