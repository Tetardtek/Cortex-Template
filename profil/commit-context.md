# commit-context.md — Règles commits sémantiques

> **Type :** Invariant — règles d'écriture git du brain
> Rédigé : 2026-03-15
> Propriétaire : scribe (brain/), scribes satellites pour leurs repos
> Source de vérité pour : tous les agents qui commitent

---

## Problème résolu

Sans règle formalisée, les messages de commit dérivent. En 10 sessions : `update`, `fix`, `misc`, `wip`. L'historique devient illisible. Les ADRs ne peuvent pas être détectés automatiquement. L'architecture-scribe n'a pas de matière.

---

## Types de commits — convention

Voir aussi `KERNEL.md ## Commit types` pour le mapping zone → scribe → type.

| Type | Zone | Usage | Exemple |
|------|------|-------|---------|
| `kernel:` | KERNEL | Modification contrat fondateur | `kernel: KERNEL.md — zones typées` |
| `feat:` | KERNEL agents/ | Nouvelle capacité, nouvel agent | `feat: architecture-scribe — pipeline ADR` |
| `fix:` | KERNEL agents/ | Correction comportement ou bug | `fix: brain-bot — filter open claims only` |
| `bsi:` | BRAIN-INDEX | Open/close claim, signal | `bsi: open claim sess-XXX` |
| `scribe:` | INSTANCE + profil/ | brain update (focus, projets, profil) | `scribe: focus.md — Sprint 2 ✅` |
| `metabolism:` | progression/ | Métriques session | `metabolism: sess-XXX — health 1.07` |
| `todo:` | todo/ | Intentions fermées/ouvertes | `todo: VITAL contexts/ ✅, preAlpha todos` |
| `toolkit:` | toolkit/ | Pattern validé en prod | `toolkit: api-error — status typed` |
| `config:` | INSTANCE | PATHS, compose, machine config | `config: PATHS.md — machine laptop` |

---

## Règles

**1. Un commit = une intention**
Ne jamais mélanger types dans un commit. `feat:` + `fix:` = deux commits.

**2. Message : action concrète, pas description**
```
✅  feat: session-orchestrator — lifecycle boot 4 couches + close séquencé
❌  feat: update session orchestrator file
```

**3. Scope optionnel entre parenthèses**
```
feat(agents): architecture-scribe — pipeline git-analyst → ADR
fix(bot): filter claims by open status — was showing 11 instead of 2
```

**4. `bsi:` est non négociable**
Tout open/close claim = commit `bsi:` immédiat + push. Sans push, VPS aveugle.

**5. Satellites commitent dans leur repo**
`scribe:` sur brain/ ne commit pas dans profil/. Chaque scribe = son repo.

**6. Preuve d'écriture = git blame**
Le commit message doit permettre à `architecture-scribe` de détecter si une décision architecturale a été prise. Être explicite sur le "pourquoi" dans le message.

---

## Ordre de commit canonique (fin de session)

```
1. bsi: close claim <sess-id>        ← toujours en dernier sur brain/
2. metabolism: <sess-id>              ← progression/ satellite
3. todo: <résumé>                     ← todo/ satellite
4. scribe: focus.md + projets/        ← brain/ (avant bsi close)
```

Voir `profil/scribe-system.md` pour l'ordre complet multi-satellites.

---

## Trigger de chargement

```
Propriétaire : tous les scribes
Trigger      : invocation d'un scribe → charger avant d'écrire
Section      : Sources au démarrage (scribes) — conditionnel (agents métier si commit requis)
```

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-15 | Création — types, règles, ordre canonique, mapping KERNEL.md zones |
