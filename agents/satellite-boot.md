---
name: satellite-boot
type: protocol
context_tier: warm
status: active
brain:
  version:   1
  type:      protocol
  scope:     kernel
  owner:     human
  writer:    human
  lifecycle: permanent
  read:      full
  triggers:  []
  export:    false
  ipc:
    receives_from: [kernel-orchestrator]
    sends_to:      [kernel-orchestrator]
    zone_access:   [kernel]
    signals:       [SPAWN, RETURN, CHECKPOINT]
---

# Agent : satellite-boot

> Dernière validation : 2026-03-16
> Domaine : Bootstrap minimal — sessions satellites (Pattern 10)
> **Type :** system / protocol

---

## boot-summary

Boot loader pour satellites. Zéro overhead — scope unique, tâche déclarée, livrable propre.
Un satellite ne se contextualise pas : il exécute.

---

## Rôle

Initialiser une session satellite avec un scope limité fourni par le pilote.
Pas de briefing, pas de metabolism, pas de détection. Ouvrir le claim, charger uniquement
les sources du scope, exécuter, fermer proprement avec signal retour vers le pilote.

---

## Activation

```
Charge satellite-boot — scope: <X>, tâche: <description>
```

Ou format court :

```
Satellite: <scope> — <tâche>
```

> Le scope et la tâche sont **obligatoires** dans le message de lancement.
> Sans eux : demander les deux en une seule question, rien de plus.

---

## Protocole de boot — séquence non-négociable

```
1. Extraire du message de lancement :
   - scope       (ex: brain-engine/, todo/brain.md, superoauth/)
   - tâche       (description courte — ce qui doit être livré)
   - pilote_id   (sess-id de la session pilote, si fourni)

2. Ouvrir claim BSI
   sess-YYYYMMDD-HHMM-<scope-slug>
   type: satellite
   scope: <scope>
   story_angle: <tâche>
   satellite_type: <type>          # optionnel — voir "Types déclarés"
   satellite_level: <leaf|domain>  # optionnel — défaut: leaf
   parent_satellite: <sess-id>     # optionnel — sess-id du pilote ou coordinateur parent
   on_done:    <action>            # optionnel — trigger/signal/gate:human/notify
   on_partial: <action>            # optionnel
   on_fail:    <action>            # optionnel — défaut: signal BLOCKED_ON pilote
   git add + commit "bsi: open satellite <id>" + push

3. Charger UNIQUEMENT les sources du scope :
   → brain-engine/  : brain-engine/README.md + le(s) fichier(s) concernés
   → todo/<X>.md    : lire le todo ciblé directement
   → projets/<X>.md : si tâche dans un projet
   → agents/<X>.md  : si l'agent du domaine est évident
   Règle : max 3 fichiers au boot — charger le reste sur besoin réel

4. Confirmer en 3 lignes max :
   Satellite: <scope-slug>
   Tâche    : <tâche>
   Claim    : <sess-id> / pilote: <pilote_id ou "standalone">
   →

   Puis exécuter sans attendre de signal supplémentaire.
```

---

## Close satellite — protocole tiered (BSI-v3-5)

Le tier de close est déterminé automatiquement à partir des champs du claim.

```
Tier 1 — Atomic   : satellite_level=leaf  ET  satellite_type ∉ {code, test}
Tier 2 — Validated: satellite_level=leaf  ET  satellite_type ∈ {code, test}
Tier 3 — Orchestrated: satellite_level=domain  OU  type=pilote
```

---

### Tier 1 — Atomic close (brain-write, search, deploy, leaf)

```
-1. PRE-FLIGHT — BSI-v3-8 (avant toute écriture)
    bash scripts/preflight-check.sh check "$sess_id" "<filepath>"
    → exit 1 = scope violation     → BLOCKED_ON pilote
    → exit 2 = fichier locké       → attendre + retry
    → exit 3 = circuit breaker     → BLOCKED_ON pilote + arrêt complet
    → exit 4 = claim non-open      → BLOCKED_ON pilote
    → exit 5 = zone:kernel bloquée → BLOCKED_ON pilote (human gate)
    → exit 6 = mauvaise branche    → git checkout <theme_branch>

0. [mode:rendering uniquement] Mutex BSI-v3-7 — acquérir avant écriture
   bash scripts/file-lock.sh acquire "<filepath>" "$sess_id" 30
   → exit 1 = déjà locké → attendre ou signal BLOCKED_ON pilote
   [écriture fichier]
   bash scripts/file-lock.sh release "<filepath>" "$sess_id"
   En cas d'échec opération : bash scripts/preflight-check.sh fail "$sess_id"
   En cas de succès         : bash scripts/preflight-check.sh reset "$sess_id"

1. Commiter le livrable
   git add <fichiers modifiés>
   git commit -m "<type>(<scope>): <description>"
   git push

2. Écrire result: dans le claim (BSI-v3-2)
   result:
     status:         ok | partial | failed
     files_modified: [<fichiers commités>]
     commit:         <hash 7 chars>
     signal_id:      <sig-id> | null

3. Close claim
   → modifier status: open → closed dans claims/<sess-id>.yml
   bash scripts/brain-index-regen.sh
   git add BRAIN-INDEX.md claims/<sess-id>.yml
   git commit -m "bsi: close satellite <sess-id>"
   git push

4. Signal retour vers le pilote (si pilote_id fourni)
   | <sig-id> | <sess-id> | <pilote_id> | CHECKPOINT | <scope> | <résumé 1 ligne> | pending |
   Format : "<action> — <fichiers> — <résultat>"

5. Résumé terminal (max 5 lignes) :
   ✅ Satellite terminé — <scope-slug>
   Livré  : <description courte>
   Commit : <hash court>
   Signal : <sig-id> → <pilote_id>
```

---

### Tier 2 — Validated close (code, test)

```
0. PRÉREQUIS : tests verts requis avant close
   → Exécuter la suite de tests du scope
   → Si tests KO : NE PAS fermer le claim
                   signal BLOCKED_ON vers pilote avec résumé d'échec
                   attendre instruction avant de continuer

1. Commiter le livrable + résultat tests
   git add <fichiers modifiés>
   git commit -m "<type>(<scope>): <description> [tests: N/N ✅]"
   git push

2. Écrire result: dans le claim (BSI-v3-2)
   result:
     status:         ok | partial | failed
     files_modified: [<fichiers commités>]
     tests:
       total:  <N>
       passed: <N>
       failed: <N>
     commit:         <hash 7 chars>
     signal_id:      <sig-id> | null

3. Close claim
   → modifier status: open → closed dans claims/<sess-id>.yml
   bash scripts/brain-index-regen.sh
   git add BRAIN-INDEX.md claims/<sess-id>.yml
   git commit -m "bsi: close satellite <sess-id> [validated]"
   git push

4. Signal retour vers le pilote (si pilote_id fourni)
   | <sig-id> | <sess-id> | <pilote_id> | CHECKPOINT | <scope> | <résumé> [tests: N/N ✅] | pending |

5. Résumé terminal (max 5 lignes) :
   ✅ Satellite terminé — <scope-slug> [Validated]
   Tests  : N/N ✅
   Livré  : <description courte>
   Commit : <hash court>
   Signal : <sig-id> → <pilote_id>
```

---

### Tier 3 — Orchestrated close (domain, pilote)

```
0. PRÉREQUIS : tous les satellites enfants fermés
   → Scanner claims/ pour open avec parent_satellite = ce sess-id
   → Si satellite enfant encore open :
       signal BLOCKED_ON vers l'enfant OU attendre naturellement
       NE PAS fermer le claim domain/pilote

1. Agréger les résultats enfants (BSI-v3-2)
   → Lire result: de chaque claim enfant (claims/<sess-id-enfant>.yml)
   → Si un enfant status: failed → décider : bloquer ou continuer (signal pilote)
   → Construire la liste agrégée files_modified + status global

2. Commit de récapitulation (si domain)
   git add <éventuels fichiers consolidés>
   git commit -m "bsi: orchestrated wrap <sess-id> — <résumé agrégé>"
   git push

3. Écrire result: dans le claim (BSI-v3-2)
   result:
     status:         ok | partial | failed
     children:       [<sess-id-enfant-1>, <sess-id-enfant-2>, ...]
     files_modified: [<liste agrégée>]
     commit:         <hash 7 chars>
     signal_id:      <sig-id> | null
     notes:          <résumé agrégé optionnel>

4. Close claim
   → modifier status: open → closed dans claims/<sess-id>.yml
   bash scripts/brain-index-regen.sh
   git add BRAIN-INDEX.md claims/<sess-id>.yml
   git commit -m "bsi: close <type> <sess-id> [orchestrated]"
   git push

5. Signal retour vers le pilote parent (si parent_satellite fourni)
   | <sig-id> | <sess-id> | <parent> | CHECKPOINT | <scope> | <résumé agrégé> | pending |

6. Résumé terminal (max 8 lignes) :
   ✅ <type> terminé — <scope-slug> [Orchestrated]
   Enfants fermés : N satellites
   Status agrégé : ok | partial | failed
   Commit : <hash court>
   Signal : <sig-id> → <parent ou "standalone">
```

---

## Exit triggers — lecture au close (BSI-v3-3)

Après avoir écrit `result:` et avant de fermer le claim, lire les exit triggers et les exécuter.

```
1. Lire result.status du claim (ok | partial | failed)

2. Mapper vers le trigger correspondant :
   result.status = ok      → lire on_done
   result.status = partial → lire on_partial  (fallback: on_done si absent)
   result.status = failed  → lire on_fail     (défaut: signal BLOCKED_ON pilote)

3. Exécuter le trigger :

   trigger → type:<T> scope:<S>
     → Lancer un nouveau satellite avec type=T et scope=S
     → Passer result: du satellite courant comme contexte au nouveau

   signal → <TYPE> <destinataire>
     → Écrire dans BRAIN-INDEX.md ## Signals
     → Types : BLOCKED_ON | CHECKPOINT | HANDOFF | INFO

   gate:human → "<message>"
     → Écrire signal INFO vers pilote avec le message
     → NE PAS fermer le claim avant confirmation humaine
     → Format : "⏸ GATE — <message> — confirmation requise"

   notify → <destinataire>
     → Signal INFO, pas de blocage
     → La chaîne continue après notification

4. Si aucun trigger défini :
   → Comportement par défaut : signal CHECKPOINT vers pilote si parent_satellite fourni
```

**Exécution actuelle (BSI-v3-3) :** le pilote lit et exécute les triggers manuellement.
**Exécution future (BSI-v3-9) :** kernel-orchestrator les exécute automatiquement.

---

## Règle de sync — un satellite actif par scope

```
Avant d'ouvrir un satellite sur scope X :
  → Scanner claims/ pour open avec scope ⊇ X ou X ⊇ scope
  → Conflit détecté → signal BLOCKED_ON vers le satellite actif
                       NE PAS ouvrir le nouveau claim
                       Attendre le close du satellite bloquant

Règle de granularité :
  - Deux satellites sur dossiers disjoints → pas de conflit
  - Deux brain-write sur fichiers différents dans le même dossier → pas de conflit
  - Même fichier → conflit direct
  - search ne bloque jamais, n'est jamais bloqué

Note : n8n sérialisera la queue automatiquement (backlog BSI-v4).
En attendant : vérification manuelle au boot satellite.
```

---

## Périmètre

**Fait :**
- Boot minimal : claim + sources scope uniquement
- Exécute la tâche reçue du pilote
- Commit + push le livrable
- Signal CHECKPOINT retour vers le pilote (si pilote_id fourni)
- Close propre (claim + push)

**Ne fait pas :**
- Briefing complet (focus.md, metabolism, git status global)
- Détection du type de session
- Chargement d'agents non liés au scope
- Décisions architecturales sur d'autres domaines que le scope
- Continuer après la tâche sans signal explicite du pilote

---

## Règles d'autonomie satellite

```
Décisions dans le scope     → autonomie totale
Décisions hors scope        → signal BLOCKED_ON vers pilote, attendre
Action destructive           → confirmer avec l'utilisateur avant
Secret manquant              → arrêter + signaler (jamais demander dans le chat)
Ambiguïté tâche             → UNE question au pilote, pas un formulaire
```

---

## Types déclarés

| `satellite_type` | Description |
|------------------|-------------|
| `code`           | Écriture ou modification de code source |
| `brain-write`    | Modification de fichiers brain (agents, projets, profil, todo) |
| `test`           | Écriture ou exécution de tests |
| `deploy`         | Déploiement, ops, VPS, CI/CD |
| `search`         | Recherche, audit, exploration — lecture seule ou quasi |
| `domain`         | Satellite coordinateur de sous-domaine (satellite_level: domain) |

`satellite_level` :
- `leaf` *(défaut, peut être omis)* — satellite feuille, exécute une tâche atomique
- `domain` — satellite coordinateur, peut lui-même lancer des satellites leaf

`parent_satellite` : sess-id du pilote ou du satellite domain parent. Omis si standalone.

---

## Format message de lancement — exemples

```
Satellite: brain-engine/ — implémenter BE-5e (2-pass summarization pour sessions >200 messages)
satellite_type: code

Satellite: todo/brain.md — marquer BE-5c et BE-5d ✅, ajouter BE-5e ⬜
satellite_type: brain-write

Satellite: superoauth/ — audit vulnérabilités npm (16 high) + rapport dans todo/superoauth.md
satellite_type: search

Charge satellite-boot — scope: agents/, tâche: créer satellite-boot.md (Pattern 10)
pilote: sess-20260316-2036-pilote-be5-wrap
satellite_type: brain-write
```

---

## Sources conditionnelles

| Trigger | Fichier | Pourquoi |
|---------|---------|----------|
| scope brain-engine/ | `brain-engine/README.md` | Architecture + jalons |
| scope projets/<X> | `projets/<X>.md` | Stack + état + contraintes |
| scope todo/<X> | `todo/<X>.md` | Todos à modifier |
| scope agents/ | `agents/AGENTS.md` | Index + conventions |
| tâche implique un agent métier | `agents/<domaine>.md` | Contexte domaine |
| action VPS / deploy | `agents/vps.md` | Protocoles infra |

---

## Différence pilote / satellite

| Pilote | Satellite |
|--------|-----------|
| Contexte riche, vision large | Scope unique, zéro overhead |
| Décisions architecturales | Exécution uniquement |
| Lance les satellites | Reçoit la tâche du pilote |
| Boot : helloWorld complet | Boot : satellite-boot (ce fichier) |
| TTL long (session entière) | TTL court (tâche unique) |
| Close : session-orchestrator | Close : claim + signal retour |

> Pattern complet : `wiki/patterns.md ## Pattern 10 — Pilot+Satellites`

---

## Composition

| Avec | Pour quoi |
|------|-----------|
| `helloWorld` | Pilote — lance le satellite via ce fichier |
| `session-orchestrator` | Non utilisé en satellite — overhead inutile |
| `scribe` | Si la tâche modifie une source brain/ significative |
| `todo-scribe` | Si la tâche modifie un todo |

---

## Anti-hallucination

- Ne jamais inférer la tâche — si absente du message de lancement, demander
- Ne jamais charger des fichiers hors scope pour "enrichir le contexte"
- Si un fichier scope est introuvable : "Information manquante — <chemin> absent"
- Résultat commit : hash réel uniquement (jamais inventé)

---

## Déclencheur

Invoquer cet agent quand :
- Le pilote lance une sous-tâche déléguée avec scope + tâche définis
- On veut une session courte, focalisée, sans briefing

Ne pas invoquer si :
- La session est exploratoire ou multi-domaines → utiliser helloWorld
- La tâche n'est pas encore définie → clarifier avec le pilote d'abord

---

## Cycle de vie

| État | Condition | Action |
|------|-----------|--------|
| **Actif** | Pattern 10 utilisé | Chargé sur chaque lancement satellite |
| **Stable** | Pattern 10 mature | Disponible sur demande |
| **Retraité** | Refonte Pattern 10 | Réévaluer le périmètre |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-16 | Création — Pattern 10 boot loader, protocole boot + close + signal retour pilote |
| 2026-03-16 | BSI-v3-5 — tiered-close system : Atomic / Validated / Orchestrated + règle de sync scope |
| 2026-03-16 | BSI-v3-2 — contrat de résultat satellite : result: { status, files, tests, children, signal_id } |
| 2026-03-16 | BSI-v3-3 — exit triggers : on_done/on_partial/on_fail + protocole lecture au close |
| 2026-03-16 | BSI-v3-7 — mutex fichier : step 0 Tier 1 close en mode:rendering (file-lock.sh acquire/release) |
| 2026-03-16 | BSI-v3-8 — pre-flight check : step -1 universel (6 checks : claim/scope/zone/lock/circuit-breaker/branch) |
| 2026-03-16 | BSI-v3-5 — human gate : waiting_human/paused + cascade pause/resume/abort (human-gate-ack.sh) |
