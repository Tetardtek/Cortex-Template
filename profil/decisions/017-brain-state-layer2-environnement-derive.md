---
name: 017-brain-state-layer2-environnement-derive
type: decision
context_tier: warm
---

# ADR-017 — brain_state() : environnement fondamental dérivé, Layer 2

> Date : 2026-03-17
> Statut : actif
> Décidé par : brainstorm session brain

---

## Contexte

À chaque recontextualisation après compactage, Claude redemande des informations fondamentales sur l'environnement de l'utilisateur : quels services tournent, quels ports, quelle machine, quel état infra. Ces "variables implicites" ne sont ni dans focus.md (direction) ni dans les ADRs (décisions) ni dans now.md (étape courante).

Un snapshot stocké ne résout pas le problème — il devient stale avec le temps. Si brain-mcp est fixé 3 jours après qu'un snapshot a capturé "brain-mcp 401 en cours", le snapshot est désormais incorrect et nuisible.

La solution : **dériver l'état depuis les sources vivantes à chaque appel**, jamais stocker.

---

## Décision

`brain_state()` est un outil MCP qui **dérive** l'environnement fondamental à la demande depuis des sources stables :

- `pm2 jlist` → services actifs (live)
- `git log -1 --oneline` → version brain courante
- Variables d'environnement connues → ports configurés
- Retourne un bloc markdown structuré, jamais mis en cache

**Layer 2 uniquement** — gate `_is_localhost()` sur l'endpoint `/state` de brain-engine. L'inventaire de l'infrastructure ne sort pas du périmètre local.

**Appelé en premier dans `brain_boot()`**, avant les queries RAG — l'environnement frame le reste du contexte.

---

## Contenu retourné

```markdown
## Environnement fondamental

**Machine** : <hostname>
**Brain version** : <git log -1 --oneline>

**Services (pm2)**
| Nom | Status | Port |
|-----|--------|------|
| brain-engine | online | 7700 |
| brain-mcp | online | 7701 |
| brain-key-server | online | 7432 |

**Infra**
- Apache proxy : /mcp/ → :7701, /api/ → :7700
- MCP configuré : oui/non
```

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Snapshot stocké | Stale — invalide sans prévenir après quelques jours |
| Variables en mémoire Claude | Perdues au compactage |
| Fichier infra.md manuel | Manuel = dérive, pm2 status > fichier statique |
| Pas d'outil dédié | Continue de générer des questions répétitives sur l'environnement |

---

## Conséquences

**Positives :**
- Zéro staleness — toujours frais, dérivé au moment de l'appel
- Élimine les questions "quel port ? quel service tourne ?" après compactage
- Layer 2 gate : l'inventaire infra reste local
- Composable : brain_boot() l'appelle en premier, tout le reste s'appuie dessus

**Négatives / trade-offs assumés :**
- Dépend de pm2 — si pm2 est down, l'état est incomplet
- Layer 2 seulement — pas accessible depuis une session distante (voulu)

---

## Références

- Fichiers concernés : `brain-engine/server.py` (GET /state), `brain-engine/mcp_server.py` (brain_state tool)
- ADR-016 : now.md canal de push garanti
- ADR-018 : migration Rust iterative
- Sessions où la décision a émergé : session brain 2026-03-17
