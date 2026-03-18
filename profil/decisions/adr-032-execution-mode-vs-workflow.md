---
scope: kernel
name: adr-032-execution-mode-vs-workflow
type: adr
context_tier: cold
---

# ADR-032 — Séparation workflow / mode d'exécution — fondation swarm-ready

> Date : 2026-03-18
> Statut : actif
> Décidé par : brainstorm coach + humain (sess-20260318-1808-agent-audit)

---

## Contexte

En préparant les premiers swarms d'agents, deux questions ont émergé :
- Où déclarer les contrats d'interface entre agents (input/output) ?
- Qu'est-ce que "swarm-ready" signifie concrètement ?

L'option A proposait de mettre le mode d'exécution dans le fichier workflow.
L'option B propose de séparer le QUOI (workflow) du COMMENT (mode d'exécution).

---

## Décision

Le **workflow** déclare QUOI faire (séquence de steps, agents, gates).
Le **mode d'exécution** déclare COMMENT l'humain est impliqué — propriété de la session, pas du workflow.

```yaml
# Dans la session (overlay)
workflow: superoauth-tier3
execution_mode: assisted   # manual | assisted | swarm
```

Le même workflow peut être exécuté en mode manual, assisté ou swarm selon la confiance acquise.
Le workflow ne change pas — la confiance évolue.

---

## Les 3 modes d'exécution

| Mode | Humain | Condition |
|------|--------|-----------|
| `manual` | Lit chaque BSI claim, envoie à l'agent, valide avant next | Découverte — premier run d'un workflow |
| `assisted` | Brain orchestre + signale, humain a la vue de l'intérieur, intervient si besoin | Construction de confiance — le mode le plus formateur |
| `swarm` | Gate à l'entrée du workflow + validation du livrable final | Confiance acquise sur ce workflow |

Le mode `assisted` est le plus précieux cognitivement : l'humain voit ce que le brain voit, construit la confiance sur ce que le brain peut faire seul.

---

## Définition formelle de swarm-ready

Un workflow est **swarm-ready** quand :
1. Il a été exécuté en mode `manual` (découverte) ✅
2. Il a été exécuté en mode `assisted` (confiance construite) ✅
3. Les agents impliqués ont des périmètres validés en conditions réelles ✅
4. Le livrable final est structuré et consommable sans reformat humain ✅

→ `swarm-ready` est une déclaration de confiance sur un **workflow**, pas sur un agent isolé.

---

## Ce que ça implique

**Agents :** ne déclarent pas leur mode d'exécution. Restent atomiques.
**Workflows :** déclarent les steps, agents, gates. Ne déclarent pas le mode.
**Sessions :** overlayent le mode d'exécution sur le workflow.
**BACT :** recevra un pattern `agentic.yml` — template de workflow swarm-capable avec contrats I/O par step.

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Mode déclaré dans le workflow | Rigidifie — le même workflow ne pourrait pas évoluer de manual → swarm sans réécriture |
| Contrats I/O dans le fichier agent | Casse la granularité atomique — un agent utilisé dans 2 workflows différents aurait 2 "profils" |
| Nouveau répertoire `swarms/` | Doublon avec `workflows/` — la distinction est dans le mode, pas dans la structure |

---

## Conséquences

- `workflows/_template.yml` → à enrichir avec contrats I/O optionnels par step
- `contexts/session-*.yml` → à enrichir avec `execution_mode:` optionnel quand workflow déclaré
- Les workflows existants (`superoauth-tier3`, `brain-engine`, etc.) → rétrospectivement classés mode `manual` (découverte)
- `bact/patterns/agentic.yml` → à créer (pattern swarm workflow)

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-18 | Création — brainstorm coach, décision structurante swarm-ready |
