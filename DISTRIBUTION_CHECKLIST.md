# DISTRIBUTION_CHECKLIST.md — brain-template maintenance

> Référence pour garantir que brain-template reste distribution-ready.
> À exécuter avant chaque release / tag.

---

## Vérification zéro fuite identité

```bash
# Depuis la racine du repo brain-template
grep -ri "tetardtek" . --include="*.md" --include="*.yml" \
  | grep -v ".git" \
  | grep -v "bsi-schema.md"   # bsi-schema: exemple username accepté
```

Attendu : **0 résultats**.

---

## Placeholders en production dans brain-template

| Placeholder | Signification | Fichiers concernés |
|-------------|---------------|-------------------|
| `<OWNER_DOMAIN>` | Domaine de l'owner (ex: `monbrain.com`) | `profil/decisions/006`, `007`, `022`, `README.md` |
| `<BRAIN_ROOT>` | Chemin absolu local du brain (ex: `/home/user/Dev/Brain`) | `ARCHITECTURE.md`, `profil/architecture.md` |
| `<owner>` | Identifiant/username de l'owner | `profil/decisions/008` |
| `l'owner` | Référence générique à l'utilisateur du brain | agents/ (tous) |

---

## Répertoires obligatoires (structure v1.0)

```
brain-template/
  agents/           ← tous les agents dépersonnalisés
  contexts/         ← sessions génériques (10 fichiers)
  agent-memory/     ← README + _template/
  brain-engine/     ← moteur local (server, embed, search, RAG, MCP)
  brain-ui/         ← dashboard React (docs, workflows, cosmos)
  docs/             ← guides humains (14 pages)
  profil/
    decisions/      ← ADRs (placeholders domaine)
    collaboration.md.example
    CLAUDE.md.example
  handoffs/
  workflows/
  README.md
  KERNEL.md
  ARCHITECTURE.md
  DISTRIBUTION_CHECKLIST.md  ← ce fichier
```

---

## Contextes inclus (génériques uniquement)

| Fichier | Usage |
|---------|-------|
| `session-navigate.yml` | Lecture légère — exploration brain |
| `session-work.yml` | Projet actif — mode travail |
| `session-pilote.yml` | Co-construction — mode pilote (ADR-035) |
| `session-edit-brain.yml` | Écriture kernel — writes autorisés |
| `session-kernel.yml` | Lecture kernel — read-only |
| `session-brainstorm.yml` | Mode brainstorm |
| `session-debug.yml` | Debug actif |
| `session-audit.yml` | Audit code/système |
| `session-coach.yml` | Mode coaching |

**Exclus** (trop owner-specific) : `session-infra.yml`, `session-deploy.yml`,
`session-urgence.yml`, `session-capital.yml`, `session-handoff.yml`

> v1.0 → v1.1 : `session-brain.yml` ajouté (10e contexte) — sessions de travail sur le brain lui-même, 100% générique.

---

## Docs (guides humains)

**v1.1 : docs/ inclus — 14 pages.**
Guides humains lisibles sans contexte brain : getting-started, architecture, sessions, workflows, agents par famille, vues par tier.

```
docs/
  README.md              ← index
  getting-started.md     ← premiere page — "j'ai forke, quoi maintenant ?"
  architecture.md        ← comment les pieces s'assemblent
  sessions.md            ← types, permissions, metabolisme, close
  workflows.md           ← recettes d'agents par situation
  agents.md              ← vue d'ensemble + comparatif tiers
  agents-code.md         ← review, securite, tests, refacto, perf
  agents-infra.md        ← VPS, CI/CD, monitoring, mail
  agents-brain.md        ← coach, scribes, orchestration, kernel
  vue-tiers.md           ← comparatif tous tiers
  vue-free.md            ← detail tier free
  vue-featured.md        ← detail tier featured
  vue-pro.md             ← detail tier pro
  vue-full.md            ← detail tier full
```

**Audit avant release :** `grep -ri "tetardtek" docs/` → 0 resultats.

## Wiki

**v1.0 : wiki absent.**
Le nouvel utilisateur construit son wiki au fil des sessions via `wiki-scribe`.
Le wiki est technique (audience agents) — le docs/ couvre l'onboarding humain.

---

## Checklist avant release

- [ ] `grep tetardtek` → 0 résultats
- [ ] `ls contexts/` → 10 fichiers présents
- [ ] `ls agent-memory/` → README.md + _template/
- [ ] README.md lisible par un inconnu (pas de référence owner)
- [ ] `ls docs/` → 14 fichiers présents
- [ ] `grep -ri "tetardtek" docs/` → 0 résultats
- [ ] `ls brain-engine/` → server.py, embed.py, search.py, start.sh présents
- [ ] `grep -ri "tetardtek" brain-engine/` → 0 résultats
- [ ] `ls brain-ui/src/` → composants présents
- [ ] `grep -ri "tetardtek" brain-ui/src/` → 0 résultats
- [ ] PATHS.md vide / exemple — aucun chemin machine réel
- [ ] `brain-compose.local.yml.example` → aucun token/credential réel
- [ ] Tag git `vX.Y.Z` créé après vérification

---

*Dernière mise à jour : 2026-03-20 — v1.2 docs + brain-engine + brain-ui standalone*
