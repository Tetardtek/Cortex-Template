# Memory Architecture — Les trois pilliers du brain

> **Type :** Référence
> Décision architecturale fondatrice — session 2026-03-13
> Complète `context-hygiene.md` (chargement) et `memory-integrity.md` (écriture)

---

## Principe fondateur

Un système de mémoire qui ne se gangrène pas repose sur trois pilliers.
Sans eux, le brain sature lentement, de l'intérieur, sans signal d'alarme visible.

---

## Pillier 1 — TTL (Time To Live)

Toute information a un cycle de vie. Ce qui est terminé doit mourir ou être archivé.
Un cerveau qui retient tout ce qui est résolu est un cerveau qui se bouche.

| État | Action | Délai | Responsable |
|------|--------|-------|-------------|
| Todo ✅ complété | Archivé dans `todo/archive/<projet>.md` | Session suivante | `todo-scribe` |
| `## État courant` d'un projet | Réécrit à chaque milestone | Immédiat | `scribe` |
| Fichier projet > 150 lignes | Compressé — historique → `## Historique` | Sur détection | `scribe` |
| Agent 🧪 jamais testé après 30 sessions | Signalé candidat archivage | Sur audit `agent-review` | `agent-review` |

> **Signal d'alarme :** un fichier qui dépasse sa taille cible sans nouvelles décisions = mémoire morte. Le scribe le compresse.

---

## Pillier 2 — Sectionnarisation

Un fichier n'est pas une unité atomique — une **section** l'est.

Chaque fichier déclare ses sections par volatilité. Un agent charge la section dont il a besoin, pas le fichier entier. C'est le principe de la RAM : tu pages ce qui est actif, pas le disque entier.

### Niveaux de volatilité

| Niveau | Label | Mise à jour | Chargement |
|--------|-------|-------------|------------|
| 🔴 Chaud | `## État courant` | Chaque session projet | Systématique — toujours en premier |
| 🟡 Tiède | `## Opérationnel` | Sur changement infra/deploy | Sur trigger deploy ou debug |
| 🔵 Froid | `## Architecture` | Sur refacto majeure uniquement | Sur trigger technique |
| ⚫ Archivé | `## Historique` | Jamais — lecture seule | Sur demande explicite uniquement |

### Template obligatoire — `projets/<X>.md`

```markdown
## État courant
<!-- 🔴 CHAUD — mis à jour à chaque session, état présent, en cours -->

## Opérationnel
<!-- 🟡 TIÈDE — container, env VPS, URLs, deploy, checklist -->

## Architecture
<!-- 🔵 FROID — stack, structure fichiers, fonctionnalités -->

## Historique
<!-- ⚫ ARCHIVÉ — décisions passées, bugs résolus, milestones -->
```

### Réflexe universel

Ce principe s'applique à **tout fichier du brain**, pas seulement les projets.
Avant d'écrire un fichier : identifier la volatilité de chaque bloc. Le placer au bon niveau.
Les agents chargent par section, pas par fichier entier.

---

## Pillier 3 — Stratification Chaud/Froid

Chaque élément du système (agent, fichier, pattern) existe sur un spectre de température.
Un index isotherme (tout au même niveau) est un vecteur de saturation garanti.

| Température | Définition | Comportement |
|-------------|------------|--------------|
| 🔴 Chaud | Accédé plusieurs fois par semaine | Auto-chargé sur détection domaine |
| 🔵 Froid | Accédé rarement | Invocation manuelle uniquement |
| ⚫ Archivé | Plus actif — obsolète ou graduation | Référence uniquement, jamais chargé |

**Application directe :** `AGENTS.md` est splitté en **Actifs** (auto-détectés) / **Stables** (invocation manuelle). L'index reste lisible et fonctionnel à 50+ agents.

---

## Procédure de reprise de projet

> La sectionnarisation rend possible la reprise rapide après une période de standby.
> Un projet peut dormir 6 mois. La reprise prend 3 échanges au lieu de 20.

```
1. Charger ## État courant     → où on en est, ce qui est en cours
2. Charger ## Opérationnel     → contexte technique actif (env, container, URLs)
3. Définir le scope de session → ce qu'on touche / ce qu'on ne touche pas
4. Charger les agents 🔴 chauds nécessaires → seulement ceux du scope défini
```

**Règle :** ne jamais charger `## Architecture` ou `## Historique` au démarrage d'une reprise.
Les charger uniquement si le scope de session l'exige (refacto, bug architectural...).

**Signal de reprise saine :** en 3 échanges, le contexte est posé et le travail peut commencer.
Si ça prend plus — l'`## État courant` n'est pas à jour. Le mettre à jour avant de continuer.

---

## Qui charge ce fichier

| Agent | Quand |
|-------|-------|
| `scribe` | Avant d'écrire dans un fichier projet |
| `todo-scribe` | Sur archivage todo ✅ |
| `recruiter` | Avant de forger un nouvel agent |
| `brainstorm` | Sur décision d'architecture brain |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-13 | Création — émergé du brainstorm memory/context. Trois pilliers : TTL, Sectionnarisation, Stratification |
