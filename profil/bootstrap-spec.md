# Bootstrap Spec — Auto vs Explicite + Réflexes conventionnels

> Rédigé : 2026-03-14
> Résout : "Audit bootstrap — agents auto-déclenchés vs invocation explicite"
>          "Réflexes conventionnels — invocations implicites par contexte"

---

## Problème

CLAUDE.md liste tous les agents dans une table uniforme. Mais ils n'ont pas tous le même mode de déclenchement. Certains doivent réagir automatiquement à chaque message — d'autres sont invoqués explicitement sur demande. Sans cette distinction, le bootstrap est flou et les agents ne savent pas quand ils sont censés s'activer.

---

## Deux modes — définition

### Mode A — Présence permanente (vérification continue)

Ces agents observent CHAQUE message et interviennent si leurs seuils sont atteints. Ils ne sont pas "chargés" — ils sont présents.

| Agent | Seuil de déclenchement | Intervient comment |
|-------|----------------------|-------------------|
| `coach` | Toujours actif | Observe la progression, signale les patterns récurrents, guide sans bloquer |
| `interprete` | Demande ambiguë / scope croisé / intention floue | Reformule avant que Claude agisse |
| `mentor` | Explication demandée / plan complexe / risque de mauvaise compréhension | Pédagogie, validation de compréhension |
| `aside` | Message préfixé `/btw` | 2-3 lignes, capture todo si actionnable, retour session |

### Mode B — Agents 🔴 chauds (détection domaine)

Chargés automatiquement quand le domaine est détecté dans la conversation. Un seul chargement par session suffit.

```
Domaine détecté → charger l'agent → il reste actif pour la session
```

Table de détection dans `~/.claude/CLAUDE.md` section "Agents 🔴 chauds".

### Mode C — Agents 🔵 stables (invocation explicite)

Ne se déclenchent jamais automatiquement. Invoqués par l'utilisateur ou sur signal d'un agent chaud.

```
"charge l'agent X"        → lire agents/X.md immédiatement
"scribe, [action]"        → scribe agit
"orchestrator-scribe, [action]" → orchestrator-scribe agit
```

---

## Réflexes conventionnels — invocations implicites

Ces déclenchements n'ont pas besoin d'une instruction explicite. Ils sont des **réflexes du système** — Claude doit les appliquer sans qu'on le demande.

### Réflexes toujours actifs

| Signal contextuel | Réflexe attendu |
|------------------|-----------------|
| `/btw <question>` | `aside` — 2-3 lignes max, `→ on reprend.` |
| Session qui se termine naturellement | Proposer bilan scribes + checkpoint si session longue |
| `checkpoint` / `/checkpoint` | orchestrator-scribe pose signal CHECKPOINT dans BRAIN-INDEX.md |
| Tâche dans `focus.md` terminée | scribe la marque ✅ sans qu'on le demande |
| Agent forgé ou modifié | scribe vérifie AGENTS.md en fin de session |
| Gap infra identifié (port, service absent) | scribe le signale en fin de session même si non corrigé |

### Réflexes sur domaine détecté

| Signal contextuel | Réflexe attendu |
|------------------|-----------------|
| Fix sur code sensible (auth, tokens) | `security` suggère `testing` |
| Nouvelle feature en prod | `capital-scribe` signalé si milestone notable |
| Pattern validé en conditions réelles | `toolkit-scribe` proposé |
| "todo cette feature" dans un projet | `todo-scribe` vérifie + crée l'entrée si absente |
| Commit avec beaucoup de fichiers touchés | `git-analyst` proposé pour narration sémantique |

### Réflexes de coordination inter-sessions

| Signal contextuel | Réflexe attendu |
|------------------|-----------------|
| Travail terminé, autre instance doit reviewer | `orchestrator-scribe` pose READY_FOR_REVIEW |
| Session trop longue (compactage prévisible) | Proposer CHECKPOINT avant que ça arrive |
| Démarrage de session — watchdog | Scribe scanne Claims + Signals. helloWorld scanne CHECKPOINT. |

---

## Ce qui NE doit PAS être un réflexe

```
❌ Charger des agents "au cas où"
❌ Lire des fichiers brain sans raison précise
❌ Proposer un bilan scribe toutes les 5 minutes
❌ Demander confirmation pour chaque micro-décision
❌ Interrompre le travail pour signaler un gap non urgent
```

**Règle :** les réflexes sont discrets. Ils agissent ou signalent en fin d'action, pas pendant.

---

## Ordre de priorité des modes

```
1. Mode A (présence permanente) — toujours actif, en arrière-plan
2. Réflexes conventionnels — déclenchés sur signal contextuel précis
3. Mode B (🔴 chauds) — chargés sur détection domaine
4. Mode C (🔵 stables) — sur invocation explicite uniquement
```

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-14 | Création — résout "Audit bootstrap" + "Réflexes conventionnels". Trois modes distincts, table de réflexes, règle anti-bruit |
