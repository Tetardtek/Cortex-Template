# Scribe System — Cartographie officielle du Scribe Pattern

> Décision architecturale — session 2026-03-13
> Complémentaire de `memory-integrity.md` (règles d'écriture) et `context-hygiene.md` (chargement)

---

## Le Scribe Pattern

**Règle dure — un agent métier n'écrit jamais directement dans le brain.**

```
Agent métier (vps, ci-cd, debug...)
  → observe, produit, détecte
  → signale au scribe compétent
  → le scribe écrit, commite, maintient

Jamais : agent métier → write directement
Toujours : agent métier → signal → scribe compétent → write
```

Pourquoi : un agent qui écrit directement = scope indéfini = dérive mémoire garantie.
Le scribe est le seul responsable de la cohérence de son repo.

---

## Carte des 6 scribes

| Scribe | Écrit où | Repo | Couche | Exportable | Cycle de vie |
|--------|----------|------|--------|------------|-------------|
| `scribe` | `focus.md`, `projets/`, `infrastructure/`, `agents/AGENTS.md`, `profil/objectifs.md` | `brain/` | Universel | ✅ | Permanent |
| `todo-scribe` | `todo/` | `brain/` (→ `todo/` futur) | Universel | ✅ structure | Stable quand todo en régime |
| `toolkit-scribe` | `toolkit/` | `toolkit/` | Universel | ✅ | Actif tant que nouveaux patterns |
| `git-analyst` | Commits git (narration sémantique) | Tous repos | Universel | ✅ | Ponctuel — invoqué sur demande |
| `coach-scribe` | `journal/`, `skills/`, `milestones/` | `progression/` | Personnel | ❌ | Suit le coach — retraité ensemble |
| `capital-scribe` | `profil/capital.md` | `brain/` | Personnel | ❌ strippé | Suit objectifs — veille quand CV stabilisé |

> `helloWorld` et `coach` ne sont **pas** des scribes — ils observent et rapportent, jamais n'écrivent.

---

## Ordre canonique de fin de session

Quand plusieurs scribes écrivent dans la même session :

```
1. todo-scribe    → commit brain/  "todo(<domaine>): <intention>"
2. capital-scribe → commit brain/  "feat(capital): <milestone>"     si signal reçu
3. scribe         → commit brain/  "feat(brain): <bilan session>"    toujours en dernier sur brain/
4. toolkit-scribe → commit toolkit/ "feat(toolkit): <pattern>"       si signal reçu
5. coach-scribe   → commit progression/ "feat(progression): <bilan>" si session coach
6. git-analyst    → valide cohérence sémantique des commits           optionnel
```

**Règle :** `scribe` est toujours le dernier à commiter sur `brain/` — il a la vue complète de ce que les autres ont écrit.

**Un commit = un scribe = un repo.** Voir `memory-integrity.md`.

---

## Comment un agent métier signale

Format standard de signal en fin d'action :

```
→ Signal scribe : <ce qui a changé> dans <fichier cible>
  Ex: "Signal scribe : nouveau container openclaw ajouté — mettre à jour brain/infrastructure/vps.md"

→ Signal todo-scribe : <intention de session future>
  Ex: "Signal todo-scribe : ⬜ configurer monitoring pour openclaw"

→ Signal toolkit-scribe : <pattern validé en prod>
  Ex: "Signal toolkit-scribe : pattern vhost reverse proxy validé — candidat toolkit/apache/"
```

Le scribe reçoit le signal en fin de session et écrit. Il ne demande pas — il déduit du signal.

---

## Chargement conditionnel

Ce fichier est chargé sur trigger — jamais au démarrage.

| Agent | Trigger | Pourquoi |
|-------|---------|----------|
| `scribe` | Au démarrage | Connaître ses pairs scribes et l'ordre de commit |
| `recruiter` | Quand il forge un agent qui écrit | Vérifier la déclaration `## Écrit où` |
| `agent-review` | Review d'un scribe | Grille : scope déclaré ? ordre respecté ? |
| Tout agent métier | Avant de signaler | Savoir à quel scribe déléguer |

---

## Séparation universel / personnel — export

```
Template public (claude-brain-template) :
  ✅ scribe, todo-scribe, toolkit-scribe, git-analyst

Couche personnelle (strippée à l'export) :
  ❌ coach-scribe, capital-scribe
  ❌ progression/, profil/capital.md
```

Quelqu'un qui fork récupère le moteur d'écriture. Pas le cerveau, pas la progression, pas le CV.

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-13 | Création — émergé de la session agent-review + architecture multi-repos + Scribe Pattern |
