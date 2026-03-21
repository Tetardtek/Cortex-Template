# Brain — Référence Patterns

> Patterns 1-N validés en prod. Source complète : `profil/orchestration-patterns.md`.

---

| # | Nom | Problème résolu | Forgé |
|---|-----|----------------|-------|
| 1 | Session-as-identity | Sessions parallèles sur une machine — routing par slug | 2026-03-14 |
| 2 | Passive listener | Agent écoute sans charger de contexte lourd au boot | 2026-03-14 |
| 3 | Parallel session handoff | Handoff entre deux sessions parallèles (CHECKPOINT signal) | 2026-03-14 |
| 4 | Context-tier split | Scinder un agent always lourd en header (always) + détail (warm) | 2026-03-15 |
| 5 | BHP validation | 4 greps de validation always-tier + convention CI brain | 2026-03-15 |
| 6 | HumanSupervisor | Extraire la logique d'exécution — laisser à l'humain les bifurcations décisionnelles | 2026-03-14 |
| 7 | Todo → KANBAN Sprint Setup | Todo structuré → KANBAN avec prompts autonomes prêts à coller | 2026-03-15 |
| 8 | Context Compact Checkpoint | Warm restart < 30 sec via checkpoint.md — vs cold bootstrap 2-3 min | 2026-03-15 |
| 9 | Kanban Pipeline Flow | Boot minimal scopé → work → wrap → kanban-scribe → états `✅`/`🤖` → viabilité agent | 2026-03-15 |
| 10 | Pilot + Satellites | Session pilote garde le contexte riche — satellites minimaux résolvent les sous-problèmes et remontent le résultat | 2026-03-16 |
| 11 | Session Ending Standard | Wrap toujours = Résumé session + Retour coach + Prompt session suivante | 2026-03-16 |

---

## Pattern 7 — Usage rapide

```
1. Todo structuré (chaque tâche : agents, input, output, prérequis)
2. "Génère le KANBAN depuis brain/todo/<fichier>.md"
3. → workspace/<sprint>/kanban.md créé avec prompts prêts
4. Envoyer les prompts carte par carte (ou en parallèle si pas de dépendance)
5. [ ] → [x] + commit à chaque carte terminée
```

## Pattern 8 — Usage rapide

```
En session : /checkpoint → checkpoint.md écrit
Warm restart : "Lis brain/workspace/<sprint>/checkpoint.md et reprends"
```

## Pattern 10 — Usage rapide (Pilot + Satellites)

```
Session pilote  → contexte riche, vision, décisions archi
                → identifie un sous-problème bloquant
                → génère un prompt satellite minimal

Session satellite → contexte minimal, tâche unique
                 → résout et remonte le résultat dans la pilote
                 → se ferme proprement (claim + wrap)

Session pilote  → intègre le résultat, continue d'avancer
```

Règle : la pilote ne descend jamais dans le détail d'implémentation.
Elle délègue, intègre, décide.

## Pattern 11 — Usage rapide (Session Ending Standard)

```
1. Résumé session  → ce qui a été livré (jalons, commits, décisions)
2. Retour coach    → progression observée + point à surveiller
3. Prompt suivant  → copier-coller prêt pour la prochaine session
```

S'applique à toute session pilote au wrap. Non-négociable.

## Pattern 9 — Usage rapide

```
1. "brain boot mode <scope>"    → claim BSI ouvert, agent chargé, prêt en 5 lignes
2. Travailler sur le scope
3. "wrap"                       → kanban-scribe lit le claim scope
                                → todo/<scope>.md mis à jour
                                → ✅ si intervention humaine / 🤖 si autonome
                                → BSI close + push
4. 🤖 accumulés → scope validé → entre dans le toolkit
```
