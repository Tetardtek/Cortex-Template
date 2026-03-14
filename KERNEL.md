# KERNEL.md — Loi des zones

> **Type :** Invariant absolu — chargé Couche 0 par helloWorld, avant tout agent.
> Dernière révision : 2026-03-14
> Propriétaire : kernel (aucun agent ne modifie ce fichier seul — décision humaine requise)

---

## Principe fondateur

Le brain est une **matrice à zones typées avec protection graduée**.
Chaque zone a une nature, une protection, et des scribes propriétaires.
Un agent qui sait dans quelle zone il opère sait automatiquement ce qu'il peut écrire — et ce qu'il ne peut pas.

**Règle d'or — non négociable :**
> Une feature grandit dans un satellite → elle peut être promue dans le kernel.
> Le kernel ne dérive jamais vers un satellite. Le flux est unidirectionnel.

---

## Les zones

### ZONE KERNEL — Protection maximale

```
Fichiers : KERNEL.md, CLAUDE.md, PATHS.md, brain-compose.yml, BRAIN-INDEX.md
           agents/   profil/
```

| Règle | Détail |
|-------|--------|
| **Protection** | Aucun agent ne modifie sans décision humaine explicite |
| **Versioning** | Chaque modification significative = tag semver |
| **Export** | brain-template = kernel sans couche instance/personnelle |
| **Commit type** | `kernel:` (contrat), `feat:` (nouvelle capacité), `bsi:` (claims/signals) |
| **Scribe** | `scribe` (agents/, profil/ état), `orchestrator-scribe` (BRAIN-INDEX.md) |

**Sous-zone PROFIL — l'âme**
```
profil/   →  Invariant (collaboration, kernel-zones, architecture) : jamais surchargé
              Contexte (session-types, agent-types, contexts/) : évolue sur signal validé
              Référence (bsi-spec, scribe-system) : mis à jour sur changement de spec
```
Le profil modèle la **personnalité** du brain. Un Invariant profil = valeur aussi dure que le kernel.

---

### ZONE SATELLITES — Vie libre, promotion possible

```
Repos : toolkit/   progression/   todo/   reviews/
        handoffs/  workspace/
```

| Règle | Détail |
|-------|--------|
| **Protection** | Chaque satellite a son scribe propriétaire — les autres ne touchent pas |
| **Versioning** | Rythme propre à chaque satellite |
| **Promotion** | Pattern validé dans toolkit/ → peut entrer dans profil/ ou agents/ via recruiter |
| **Commit type** | `scribe:` `todo:` `metabolism:` `toolkit:` selon le satellite |
| **Scribes** | toolkit-scribe, progression/metabolism-scribe, todo-scribe, coach-scribe |

---

### ZONE INSTANCE — Configuration machine

```
Fichiers : focus.md, projets/*, PATHS.md (valeurs réelles), brain-compose.local.yml
```

| Règle | Détail |
|-------|--------|
| **Protection** | Personnel à une machine — jamais dans brain-template |
| **Commit type** | `scribe:` (focus, projets), `config:` (PATHS, compose) |
| **Scribe** | `scribe` (focus, projets) |

---

### ZONE WORK — Externe

```
Repos projets : GitHub, Gitea projets clients/perso
```

| Règle | Détail |
|-------|--------|
| **Protection** | Aucune protection kernel — vit sa propre vie |
| **Interaction** | Le brain documente, ne possède pas |

---

## Commit types — propriété et zone

| Type | Zone | Scribe propriétaire | Déclencheur |
|------|------|--------------------|-|
| `kernel:` | KERNEL | Décision humaine | Modification contrat fondateur |
| `feat:` | KERNEL agents/ | recruiter + humain | Nouvel agent forgé, capacité ajoutée |
| `fix:` | KERNEL agents/ | debug / agent-review | Correction comportement |
| `bsi:` | KERNEL BRAIN-INDEX | orchestrator-scribe | Open/close claim, signal |
| `integrator:` | WORK (repos projets) | integrator | Commit d'absorption multi-agents, push sprint |
| `scribe:` | INSTANCE + KERNEL profil/ | scribe | brain update (focus, projets, profil) |
| `metabolism:` | SATELLITES progression/ | metabolism-scribe | Fin de session — métriques |
| `todo:` | SATELLITES todo/ | todo-scribe | Intentions fermées/ouvertes |
| `toolkit:` | SATELLITES toolkit/ | toolkit-scribe | Pattern validé en prod |
| `config:` | INSTANCE | config-scribe | PATHS, compose, machine config |

**Règle scribe :**
> Un agent métier ne commit jamais directement.
> Il signal → le scribe compétent écrit → dans sa zone uniquement.

**Exceptions explicites (comme `helloWorld` pour `bsi:`) :**
> `integrator` → commit direct en zone WORK uniquement (repos projets, hors brain/)
>                Pour brain/handoffs/ → signal à `orchestrator-scribe`
> `tech-lead`  → aucune écriture directe — cosigne les messages de commit uniquement

---

## Session type → zone access

| Type session | Zones accessibles | Zones interdites |
|-------------|------------------|-----------------|
| `brain` | KERNEL (agents/, profil/) | WORK |
| `work` | KERNEL (lecture) + INSTANCE + SATELLITES | — |
| `deploy` | KERNEL (lecture) + INSTANCE | progression/ |
| `debug` | Toutes (lecture) + zone du bug | — |
| `audit` | Toutes (lecture seule) | Écriture directe |
| `coach` | SATELLITES progression/ | KERNEL (écriture) |
| `brainstorm` | Toutes (lecture) + todo/ | KERNEL (écriture) |

---

## Protection graduée — niveaux

| Niveau | Fichiers | Peut modifier | Trigger |
|--------|----------|---------------|---------|
| **Absolu** | KERNEL.md, CLAUDE.md, bsi-spec.md | Humain uniquement | Décision architecturale majeure |
| **Fort** | profil/ Invariant, agents/ system | Humain + confirmation | Session brain avec signal explicite |
| **Standard** | agents/ metier, profil/ Contexte | Scribe sur signal | Fin de session significative |
| **Libre** | Satellites, INSTANCE | Scribe propriétaire | En session, sur livrable |

---

## Règles d'inviolabilité

1. **KERNEL.md lui-même** — jamais modifié par un agent seul. Toujours décision humaine.
2. **Profil Invariant** — jamais surchargé par une session de travail. Signal explicite requis.
3. **Un scribe = un territoire** — toolkit-scribe ne touche pas progression/. Jamais.
4. **Flux unidirectionnel** — satellite → kernel possible (promotion). Kernel → satellite = contamination.
5. **Session audit** — lecture seule sur toutes les zones. Jamais d'écriture directe.

---

## Chargement

```
helloWorld Couche 0 — invariant [toujours, avant tout agent] :
  KERNEL.md          ← cette loi
  PATHS.md           ← chemins machine
  profil/collaboration.md  ← règles de travail
```

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-14 | Création — zones typées, protection graduée, commit ownership, session→zone access |
