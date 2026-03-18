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
  contexts/         ← sessions génériques (9 fichiers)
  agent-memory/     ← README + _template/
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

---

## Wiki

**v1.0 : wiki absent (Option A).**
Le nouvel utilisateur construit son wiki au fil des sessions.
Le wiki se construit naturellement via `wiki-scribe` en session.

Si un wiki starter est ajouté en v2.0 : auditer chaque fichier avant inclusion.

---

## Checklist avant release

- [ ] `grep tetardtek` → 0 résultats
- [ ] `ls contexts/` → 9 fichiers présents
- [ ] `ls agent-memory/` → README.md + _template/
- [ ] README.md lisible par un inconnu (pas de référence owner)
- [ ] PATHS.md vide / exemple — aucun chemin machine réel
- [ ] `brain-compose.local.yml.example` → aucun token/credential réel
- [ ] Tag git `vX.Y.Z` créé après vérification

---

*Dernière mise à jour : 2026-03-18 — v1.0 distribution-ready*
