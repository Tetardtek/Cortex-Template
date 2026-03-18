# Patterns d'orchestration — Brain

> **Type :** Contexte — propriétaire : `orchestrator-scribe`
> Mis à jour en fin de session quand un pattern récurrent est identifié.

---

## Pattern 1 — Sessions parallèles sur une machine (session-as-identity)

**Problème :** plusieurs agents travaillent en parallèle sur la même machine → même `brain_name@machine` → orchestrator-scribe ne peut pas distinguer qui cibler.

**Solution :** le slug du session ID EST l'identité de routage. Pas besoin de forker un brain par rôle.

```
Format : sess-YYYYMMDD-HHMM-<role>@machine

Exemples :
  sess-20260314-0900-build@desktop    → produit du code
  sess-20260314-0901-review@desktop   → review en parallèle
  sess-20260314-0902-test@desktop     → tests en parallèle
  sess-20260314-0910-audit@laptop     → audit depuis le laptop
```

**Procédure :**

```
1. Ouvrir chaque session avec un rôle dans le slug :
   scribe, ouvre un claim sur agents/ — rôle : build
   → ID généré : sess-20260314-0900-build@desktop

2. Envoyer un signal ciblé (pas broadcast) :
   De  : sess-20260314-0900-build@desktop
   Pour : sess-20260314-0901-review@desktop   ← message direct
   Type : READY_FOR_REVIEW
   Concerné : agents/security.md

3. La session review reçoit au démarrage :
   → watchdog filtre Pour == son sess-id@machine
   → "Signal reçu de build : READY_FOR_REVIEW sur agents/security.md"
```

**Règle de routage :**

| Format `Pour` | Comportement |
|---------------|-------------|
| `brain_name@machine` | Broadcast — toutes sessions actives de ce brain |
| `sess-YYYYMMDD-HHMM-<role>@machine` | Message direct — une session précise |

**Anti-pattern :**
- ❌ Ne pas forker un nouveau brain pour chaque rôle → explosion de configs
- ❌ Ne pas cibler `brain_name@machine` quand on veut une session précise → broadcast non désiré
- ✅ Un brain par machine, N sessions nommées par rôle

---

## Pattern 2 — Cycle coworking inter-machines

**Problème :** une session produit du travail sur desktop, une autre doit le reviewer sur laptop sans communication manuelle.

**Solution :** signal READY_FOR_REVIEW dans BRAIN-INDEX.md → watchdog détecte au démarrage de la session review.

```
prod@desktop  →  travaille sur <fichier>
               →  ferme claim
               →  signal READY_FOR_REVIEW → template-test@laptop (ou sess-id précis)

template-test@laptop  →  démarre, watchdog lit BRAIN-INDEX.md ## Signals
                       →  détecte signal pending adressé à son instance
                       →  "Signal reçu : READY_FOR_REVIEW sur <fichier>"
                       →  ouvre claim review
                       →  audite → écrit dans reviews/<fichier>.md
                       →  ferme claim
                       →  signal REVIEWED → prod@desktop

prod@desktop  →  watchdog lit REVIEWED
               →  lit reviews/<fichier>.md
               →  intègre ou ignore → continue
```

**Quand l'utiliser :**
- Review de code sensible (sécurité, auth, archi)
- Validation d'un agent forgé avant de l'intégrer dans brain-template
- Tout workflow "produit → valide → intègre"

---

## Pattern 3 — HANDOFF — session longue découpée

**Problème :** session longue à couper (fin de journée, changement de machine) sans perdre le contexte.

**Solution :** signal HANDOFF avec payload précis → la session cible reprend exactement au bon endroit.

```
sess-20260314-1800-build@desktop  →  point d'arrêt naturel atteint
                                   →  signal HANDOFF → prod@laptop
                                   →  payload : "reprendre agents/security.md à ## Périmètre"

prod@laptop  →  watchdog détecte HANDOFF
              →  charge agents/security.md, position ## Périmètre
              →  continue sans perte de contexte
```

**Payload HANDOFF — format recommandé :**
```
"reprendre <fichier> à <## Section> — contexte : <1 ligne résumé>"
```

---

## Pattern 4 — Audit avant prod (triple-session)

**Problème :** feature sensible → besoin de review code + security + tests avant merge.

**Solution :** session build produit → 3 sessions d'audit en parallèle → résultats consolidés.

```
sess-YYYYMMDD-HHMM-build@desktop  →  feature terminée
  →  signal READY_FOR_REVIEW → sess-HHMM-review@desktop   (code quality)
  →  signal READY_FOR_REVIEW → sess-HHMM-security@desktop (OWASP, auth)
  →  signal READY_FOR_REVIEW → sess-HHMM-test@laptop       (coverage)

Chaque session audite, écrit dans reviews/
  →  signal REVIEWED → build@desktop

build@desktop reçoit 3× REVIEWED → consolide → merge
```

---

## Pattern 5 — CHECKPOINT — arrêt naturel et reprise sans perte

**Problème :** session longue → compactage LLM, coupure réseau, pause humaine → contexte perdu, reprise hasardeuse.

**Solution :** signal `CHECKPOINT` posé dans BRAIN-INDEX.md (HANDOFF vers soi-même) — snapshot persisté dans git, indépendant du contexte LLM.

**Déclencheurs :**
- Utilisateur : `checkpoint` / `/checkpoint` / `pose un checkpoint`
- Scribe (auto) : breakpoint naturel après un item important terminé en session longue
- Fin de session sans fermeture propre prévue

**Procédure — poser un checkpoint :**

```
User : "checkpoint"

orchestrator-scribe :
1. Collecter avec scribe :
   - Tâche en cours  : <ce qu'on faisait>
   - Fichiers touchés: <git diff --name-only depuis ouverture claim>
   - Commits         : <git log --oneline --since="<ouvert le>">
   - Prochaine étape : <actionnable, précis — "reprendre X à ## Section Y">
   - Contexte non-git: <décisions, intentions pas encore commitées>

2. Poser signal CHECKPOINT dans BRAIN-INDEX.md :
   De   : sess-YYYYMMDD-HHMM-<role>@machine
   Pour : sess-YYYYMMDD-HHMM-<role>@machine  ← même session
   Type : CHECKPOINT
   Payload : résumé structuré ci-dessus

3. Confirmer : "Checkpoint posé — reprise depuis : <prochaine étape>"
4. L'utilisateur peut fermer la session proprement.
```

**Procédure — reprendre après un checkpoint :**

```
Nouvelle session démarre — watchdog scribe :
1. Lire ## Signals — filtrer CHECKPOINT de l'instance active
2. Afficher AVANT tout autre action :
   "Checkpoint détecté [date]
    Tâche en cours  : <...>
    Prochaine étape : <...>
    Commits posés   : <...>"
3. Demander : on reprend depuis ce point ?
4. Oui → marquer signal delivered → continuer depuis <prochaine étape>
5. Non → ignorer, session normale
```

**Pourquoi c'est robuste :**
- Persisté dans git → survit au compactage LLM, redémarrage machine, changement de machine
- Format structuré → le LLM relit un état propre, pas une mémoire dégradée
- `git log` dans le payload → audit trail complet de ce qui a été fait

---

## Ajout de patterns

Invoquer `orchestrator-scribe` en fin de session si un workflow récurrent a été identifié :
```
orchestrator-scribe, capture ce pattern dans orchestration-patterns.md
```

---

## Pattern 6 — HumanSupervisor — décision minimale

> Validé en prod : sess-20260314-1920-supervisor — 2026-03-14
> Contexte : sprint OriginsDigital dual-agent (back + front) supervisé depuis une fenêtre dédiée

**Principe : extraire la logique d'exécution pour ne laisser à l'humain que les bifurcations décisionnelles.**

```
Exécution déterministe   → agents autonomes (pas de remontée)
  bug connu + pattern    → fix direct
  signal BSI             → trigger automatique
  close session          → séquence scribe auto
  validation routes      → back lit le code front, pas la spec

Points de décision humaine (ce qui remonte au superviseur)
  → Priorisation        : "Sprint 2 ou fix d'abord ?"
  → Architecture        : "Ce choix a des conséquences long terme ?"
  → Arbitrage scope     : conflit entre deux sessions parallèles
  → Validation prod     : deploy = toujours humain
```

**Structure de la session supervisor :**

```
Fenêtre supervisor  →  claim BSI type supervisor
                        lit les signaux, pas le code
                        coach intervient sur les bifurcations
                        3 interventions max sur un sprint de 4h
                        ferme en dernier (après les sessions de travail)
```

**Ce que le sprint du 2026-03-14 a mesuré :**
- 3 interventions humaines sur ~4h de travail dual-agent
- Bug super_admin trouvé par le back en lisant le code front (audit externe)
- Ratio métabolisme 1.0 — équilibré build-brain / use-brain

**Règle : minimum viable human input**
```
Si une décision peut être prise sans connaître la stratégie globale → agent
Si une décision change la direction du projet ou l'architecture → humain
```

**Anti-pattern :**
- ❌ Supervisor qui relit chaque ligne de code — c'est du micro-management
- ❌ Agents qui remontent chaque étape pour validation — ça annule le gain
- ✅ Agents qui remontent uniquement les blocages ou les ambiguïtés réelles
- ✅ Supervisor qui répond en 1 phrase, pas en spec complète

**Connexion brain :**
→ `brain-compose.yml` : mode `human-supervisor` à créer (todo capturé)
→ `motor-spec.md` : motor_level définit ce qui est autonome vs ce qui remonte
→ `session-orchestrator` : close sequence = exemple d'exécution déterministe
