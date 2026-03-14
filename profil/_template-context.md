# <Nom> — <Description courte>

> **Type :** Contexte — propriétaire : `<agent-propriétaire>`
> Rédigé : <DATE>
> Résout : "<problème ou todo dont ce contexte est la réponse>"

---

## Problème résolu

<Pourquoi ce contexte existe. Le problème concret que l'agent propriétaire rencontrait sans lui.>

> Un contexte sans problème résolu documenté n'a pas de raison d'exister.
> Si tu ne peux pas remplir cette section — reconsidère si un contexte est vraiment nécessaire.

---

## <Section principale — patterns / spec / décisions>

> Structure libre selon le domaine. Exemples :
> - `## Pattern 1 — <nom>` pour les contextes patterns (ex: orchestration-patterns)
> - `## Spécification` pour les contextes spec (ex: bsi-spec)
> - `## Règles` pour les contextes de comportement (ex: bootstrap-spec)

---

## Trigger de chargement

> Quand et par qui ce fichier est chargé.

```
Propriétaire : <agent>
Trigger      : <condition précise — "quand X est détecté" ou "au démarrage de <agent>">
Section dans l'agent : Sources conditionnelles ou Sources au démarrage
```

---

## Maintenance

> Qui met à jour ce fichier, quand, et comment.

```
Propriétaire : <agent>
Mise à jour  : <signal — "en fin de session si nouveau pattern", "sur décision architecturale", etc.>
Jamais modifié par : <agents non propriétaires>
```

> Règle d'inviolabilité si ce contexte est un Invariant : voir `brain/profil/file-types.md`.
> Pour un Contexte standard : seul le propriétaire met à jour, jamais directement depuis une autre session.

---

## Cycle de vie

| État | Condition | Action |
|------|-----------|--------|
| **Actif** | L'agent propriétaire est actif, le domaine évolue | Mis à jour en fin de session si nouveau pattern |
| **Stable** | Le domaine est stable — peu de nouveaux patterns | Consulté, rarement modifié |
| **Archivé** | L'agent propriétaire est retraité | Lecture seule — ne plus mettre à jour |

---

## Changelog

| Date | Changement |
|------|------------|
| <DATE> | Création |
