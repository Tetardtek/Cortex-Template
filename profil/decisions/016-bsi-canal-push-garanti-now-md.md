---
name: 016-bsi-canal-push-garanti-now-md
type: decision
context_tier: warm
---

# ADR-016 — BSI : canal de push garanti via brain/now.md

> Date : 2026-03-17
> Statut : actif
> Décidé par : brainstorm session brain

---

## Contexte

Le BSI (Brain Session Index) a été conçu comme outil de synchronisation de sessions parallèles via des claims git-committés. À l'usage, plusieurs problèmes ont émergé :

1. **Jamais vraiment mandatory** — des sessions entières tournaient sans claim, sans que personne s'en rende compte
2. **Temporal inference bug** — les timestamps des claims amenaient Claude à inférer l'heure de la journée et suggérer d'arrêter de travailler, fragmentant la journée en sessions multiples inutiles
3. **Pull probabiliste, pas push garanti** — après migration vers MCP, `brain_boot()` trouve le contexte via RAG sémantique, mais seulement si la query matche. Un claim important peut passer invisible
4. **Git = mauvais outil pour l'async** — un commit est une opération lourde et synchrone. Pour de l'état async temps réel, git est le mauvais primitif

**Ce que le BSI faisait vraiment bien**, malgré tout : permettre à Claude d'absorber l'état courant sans que l'utilisateur ait à réexpliquer "où on en était". C'était un canal de push context async.

---

## Décision

Le canal de push garanti est assuré par **`brain/now.md`**, un fichier unique écrit par Claude en fin de session via `brain_write()`, lu en **slot prioritaire** dans `brain_boot()` — avant le RAG, lecture directe, toujours présent.

**Migration BSI → MCP :**

| BSI claim type | Remplacé par |
|----------------|-------------|
| Sprint actif | `brain_workflows()` |
| Décision prise | `brain_decisions()` + ADRs formels |
| Focus du moment | `brain_focus()` |
| Contexte général | `brain_boot()` RAG |
| État live session | `brain/now.md` (nouveau) |

---

## Contenu de brain/now.md

```markdown
# Now — <date>

## Étape courante
<sprint + step + ce qui était en cours>

## Services actifs (connus)
<ports, pm2, ce qui tournait>

## Prochain action immédiate
<une ligne, la prochaine chose à faire>

## Contexte implicite
<variables importantes qui ne sont pas dans focus.md>
```

Écrit par Claude en fin de session. Overwrite systématique (`current`). Non archivé — l'historique est dans git.

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Session snapshot stocké | Stale avec le temps — invalide après quelques jours sans session |
| Continuer BSI git | Git = sync lourd, pas adapté à l'async multimodal |
| RAG seul (brain_boot actuel) | Pull probabiliste — un push important peut ne pas remonter |
| brain_state() auto-généré | Dérive l'environnement mais pas l'intention ni l'étape courante |

---

## Conséquences

**Positives :**
- Push garanti : Claude lit `now.md` à chaque boot, sans exception
- Zéro temporal inference — now.md ne contient pas de timestamp d'activité
- Léger : un seul fichier, overwrite systématique
- Compatible avec le modèle multimodal — toutes les sessions lisent la même source

**Négatives / trade-offs assumés :**
- Dépend de Claude pour l'écriture — si la session se termine abruptement, now.md n'est pas mis à jour
- Contenu subjectif (ce que Claude "pensait" de l'état) — pas dérivé du système réel (c'est brain_state() qui couvre ça)

---

## Références

- Fichiers concernés : `brain-engine/mcp_server.py` (brain_boot + brain_write), `brain/now.md` (à créer)
- ADR-015 : architecture deux niveaux L1/L2
- ADR-017 : brain_state() environnement dérivé Layer 2
- Sessions où la décision a émergé : session brain 2026-03-17 — modèle d'utilisation brain
