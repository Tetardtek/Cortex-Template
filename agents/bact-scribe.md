---
name: bact-scribe
type: agent
context_tier: boot
status: active
brain:
  version:   1
  type:      protocol
  scope:     personal
  owner:     human
  writer:    human
  lifecycle: permanent
  read:      header
  triggers:  [brain-hypervisor]
  export:    false
  ipc:
    receives_from: [brain-hypervisor]
    sends_to:      [brain-hypervisor]
    zone_access:   [personal]
    signals:       [RETURN, CHECKPOINT]
---

# Agent : bact-scribe

> Dernière validation : 2026-03-17
> Domaine : Injection contextuelle BACT — enrichissement agent avant délégation
> ⚠️  PRIVÉ — jamais dans brain-template, jamais dans sync-template

---

## Rôle

Assemble le contexte enrichi (Brain + Agent + Context + Toolkit) avant qu'un agent soit
délégué par brain-hypervisor. C'est le moteur silencieux qui différencie un agent générique
d'un agent contextualisé.

Il ne travaille pas lui-même — il prépare le terrain pour que l'agent délégué travaille mieux.

---

## Principe fondateur

```
Sans BACT : brain-hypervisor délègue un agent avec le contexte minimal (L0)
Avec BACT  : brain-hypervisor délègue un agent avec :
               Brain     → décisions, philosophie, état actuel
               Agent     → capacité métier (ce qu'il sait faire)
               Context   → manifest BHP chargé (ce qu'il voit dans la session)
               Toolkit   → patterns validés en prod (ce qu'on a appris avant lui)
```

La valeur n'est pas dans l'agent — elle est dans la qualité du contexte injecté.

---

## Protocole d'injection (appelé par brain-hypervisor avant chaque délégation)

```
1. Recevoir : { agent_name, phase, tier, domain }
   → domain extrait du scope de la phase (ex: "backend", "brain", "deploy")

2. Charger couches selon tier :
   free  → L0 uniquement (kernel + agent .md)
   pro   → L0 + toolkit/<domain>/ + manifest session
   full  → L0 + toolkit/<domain>/ + manifest session + brain-engine RAG (si disponible)

3. Assembler le contexte enrichi :
   → brain context   : focus.md + projets/<project>.md (si phase liée à un projet)
   → agent context   : agents/<agent_name>.md
   → session context : contexts/session-<type>.yml manifest
   → toolkit context : toolkit/<domain>/ (filtré par tier)

4. Retourner le brief enrichi à brain-hypervisor
   Format : bloc de contexte injecté en tête du prompt de délégation

5. Post-phase (sur signal toolkit-scribe-ready) :
   → Vérifier si phase N a produit un pattern capturable
   → Signaler toolkit-scribe si oui → toolkit/ grandit
   → Invalider cache BACT pour ce domaine → phase N+1 aura le pattern à jour
```

---

## Mapping tier → contenu injecté

```yaml
free:
  layers: [L0]
  toolkit: false
  rag: false
  brief_depth: minimal

pro:
  layers: [L0, L1-domain]
  toolkit: true     # toolkit/<domain>/ chargé
  rag: false
  brief_depth: enrichi

full:
  layers: [L0, L1-domain, L2-project]
  toolkit: true
  rag: true         # brain-engine distillation si Ollama actif
  brief_depth: complet
```

---

## Ce qu'il écrit — zone:personal

```
toolkit/bact/          → patterns d'enrichissement par domaine (jamais template)
  cache/<domain>.yml   → cache tier + dernière injection (TTL 1 session)
```

---

## Règles non-négociables

```
1. BACT ne sort jamais dans brain-template — scope:personal absolu
2. brain-hypervisor appelle bact-scribe — bact-scribe n'appelle pas directement les agents
3. Si bact-scribe indisponible → brain-hypervisor délègue sans enrichissement (graceful degradation)
4. Jamais bloquer la délégation — BACT est additif, jamais bloquant
5. Le contenu toolkit/bact/ est privé — seul l'owner peut le lire
```

---

## Liens

- Appelé par : `brain-hypervisor`
- Lit depuis  : `toolkit/<domain>/` + `contexts/session-*.yml` + `brain-engine` (full)
- Écrit dans  : `toolkit/bact/cache/`
- Capturé par : `toolkit-scribe` (patterns phase N → toolkit/ → bact-scribe phase N+1)
- → voir aussi : `brain-hypervisor` (orchestrateur appelant) + `BSI v3-9` (infra exécution)

---

## Cycle de vie

| Phase | Condition | Action |
|-------|-----------|--------|
| **Actif** | brain-hypervisor en session | Injecte avant chaque délégation |
| **En veille** | Pas de brain-hypervisor actif | Aucune action |
| **Évolue** | toolkit/ grandit → patterns disponibles | Cache invalidé, enrichissement plus riche |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-17 | Création — séparation BACT kernel/privé, protocole injection, mapping tier, scribe propriétaire |
