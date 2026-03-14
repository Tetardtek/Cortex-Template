# todo-context.md — Workflow et lifecycle des todos

> **Type :** Invariant — règles du système todo du brain
> Rédigé : 2026-03-15
> Propriétaire : todo-scribe
> Source de vérité pour : tout agent qui lit ou écrit dans todo/

---

## Problème résolu

Sans règle formalisée, les todos s'accumulent, ne se ferment jamais, ou se ferment silencieusement sans trace. En 20 sessions : liste ingérable, perte de contexte sur pourquoi un todo existe.

---

## Convention todo

### Statuts

| Symbole | Sens | Qui peut changer |
|---------|------|-----------------|
| `⬜` | Ouvert — à faire | todo-scribe sur signal |
| `✅` | Fermé — livré | todo-scribe sur confirmation humaine |
| `🔄` | En cours — session active dessus | session-orchestrator au boot |
| `⏸` | Suspendu — bloqué ou déprioritisé | Décision humaine |
| `❌` | Annulé — ne sera pas fait | Décision humaine + raison documentée |

### Format d'un todo

```markdown
## ⬜ <Titre court — verbe + sujet>

> Capturé : YYYY-MM-DD — <contexte de capture>
> Priorité : haute | moyenne | basse
> Dépend de : <autre todo ou prérequis si applicable>

**L'intention :**
<Pourquoi ce todo existe. Le problème qu'il résout.>

**Implémentation :**
1. <étape concrète>
2. <étape concrète>
```

---

## Lifecycle d'un todo

```
Émergé en session → capturé par todo-scribe (⬜)
    → Session dédiée → todo passe 🔄
    → Livré → todo-scribe ferme ✅ + commit todo:
    → Bloqué → ⏸ + raison documentée
    → Décision de ne pas faire → ❌ + raison
```

**Règle d'or :** un todo fermé n'est jamais supprimé — il passe ✅. L'historique est une mémoire.

---

## Règles

**1. Capture immédiate**
Un todo émergé en session = capturé avant la fin de session. Pas "je me souviendrai".

**2. Un todo = une intention atomique**
Si un todo nécessite 5 sessions → le décomposer en sous-todos liés.

**3. Titre = verbe d'action**
```
✅  ## ⬜ Forger agent architecture-scribe
❌  ## ⬜ architecture-scribe
```

**4. Priorité explicite**
Haute = bloque autre chose ou fort impact immédiat.
Moyenne = important mais pas urgent.
Basse = nice-to-have, ne pas planifier.

**5. Ne pas fermer sans livrable**
`✅` = quelque chose a été produit, commité, poussé. Pas juste "on en a parlé".

**6. Débat interdit dans todo/**
Les todos capturent des intentions, pas des discussions. Le débat va dans une session brainstorm ou un ADR.

---

## Todos et KERNEL.md zones

| Todo concerne | Zone | Commit type à la fermeture |
|--------------|------|---------------------------|
| Nouvel agent | KERNEL agents/ | `feat:` |
| Patch agent | KERNEL agents/ | `fix:` |
| Profil/spec | KERNEL profil/ | `scribe:` ou `kernel:` |
| Focus/projet | INSTANCE | `scribe:` |
| Pattern toolkit | SATELLITES | `toolkit:` |
| Vision produit | ADR → decisions/ | `kernel:` |

---

## Trigger de chargement

```
Propriétaire : todo-scribe
Trigger      : invocation todo-scribe → charger avant lecture/écriture
Section      : Sources au démarrage (todo-scribe)
```

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-15 | Création — statuts, lifecycle, règles, mapping zones |
