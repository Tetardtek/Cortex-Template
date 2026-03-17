---
name: adr-010-brain-language
type: decision
context_tier: warm
---

# ADR-010 — brain-language : header YAML universel pour tous les fichiers brain

> Date : 2026-03-15
> Statut : actif
> Décidé par : session brain build-brain + coach + tech-lead

---

## Contexte

Les fichiers brain sont chargés en entier pour en lire 10 lignes utiles. Le context-broker
ne peut pas décider du chargement sans ouvrir le fichier. À ~200+ fichiers répartis sur 6
satellites, le coût de chargement non-sélectif est rédhibitoire.

Analogie : matière grise sans synapses — les neurones existent mais ne communiquent pas.

---

## Décision

Chaque fichier du système brain commence par un header YAML standardisé (`brain-language v1`).
Le context-broker scanne les headers uniquement → décision load en O(header) au lieu de O(fichier).

**Format header v1 :**

```yaml
---
brain:
  version:   1
  type:      protocol       # invariant | context | reference | personal | protocol | work
  scope:     kernel         # kernel | satellite | instance | work
  owner:     orchestrator   # autorité architecturale — valide les changements structurels
  writer:    scribe         # droits de maintenance courante — peut patcher sur découverte
  # owner ≠ writer : séparation autorité / maintenance (décidé sess-20260315-1105-brain)
  lifecycle: permanent      # session | sprint | stable | permanent
  read:      header         # header | full | trigger
  triggers:  [sprint]       # liste FERMÉE — pas de triggers libres
  export:    true           # false = personnel, strippé à l'export brain-template
---
```

**Triggers valides (liste fermée) :**
`sprint` | `use-brain` | `build-brain` | `coach` | `audit` | `deploy` | `migration` | `on-demand`

**Format masquage selon type de fichier :**
- `.md` → YAML frontmatter natif (déjà utilisé dans les agents)
- Fichiers code → commentaire natif (`# brain:` / `// brain:`)

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Index externe centralisé (registre JSON) | Single point of failure, drift index/fichier inévitable |
| Nommage par convention de fichier | Trop limité — scope/triggers/lifecycle pas encodables dans un nom |
| Tags git | Invisible au contexte LLM, hors du flow de lecture |
| Pas de header (statu quo) | O(fichier) pour décider — coût bloquant à l'échelle |

---

## Conséquences

**Positives :**
- Context-broker peut ignorer complètement les fichiers hors scope/triggers sans les ouvrir
- Indexage toolkit : `triggers: [typeorm]` → chargé uniquement quand pertinent
- BSI v2 conditionnel : si pilot validé → sessions tracées dans les headers (sans BRAIN-INDEX.md)
- Tier 2 daemon (brain-watch étendu) peut pré-calculer la source map au boot
- `export: false` permet le stripping automatique des fichiers personnels à l'export brain-template
- Tout fichier sans header = neurone sans synapse → détectable et corrigeable par agent-review

**Négatives / trade-offs assumés :**
- Migration ~200 fichiers répartis sur 6 satellites — coût one-shot significatif
- Spec irréversible une fois propagée — pilot obligatoire avant migration complète
- Tout nouveau fichier DOIT avoir un header — overhead à l'écriture

---

## Plan de migration (non négociable)

```
1. Spec ratifiée humain (ce document) ✅
2. Pilot : 10 fichiers représentatifs (2-3 par type) — ajustements spec si nécessaire
3. Validation pilot → go/no-go migration complète
4. Migration par phase (rollback possible à chaque étape) :
     Phase 1 — agents/       → plus lus, gain immédiat
     Phase 2 — profil/       → invariants + références
     Phase 3 — toolkit/      → indexage patterns
     Phase 4 — todo/         → intentions
     Phase 5 — progression/  → journal + skills + milestones
     Phase 6 — projets/      → contrats projets
5. Patch scribes — header obligatoire dans tout nouveau fichier
6. agent-review mis à jour — header = critère de review
```

**Règle pilot :** les champs nécessaires après 10 fichiers réels seront différents de ceux
imaginés aujourd'hui. Ne pas migrer 200 fichiers avant le pilot.

---

## Extension conditionnelle — BSI v2 + Tier 2 daemon

> Condition : brain-language pilot validé d'abord

Si pilot validé, chaque fichier actif en session déclare sa participation dans son header :
```yaml
brain:
  session: sess-YYYYMMDD-HHMM-slug
  instance: prod@desktop
  scope: write
  opened: 2026-03-15T14:00
```

brain-watch grep `session:` → état système sans parser BRAIN-INDEX.md.
BRAIN-INDEX.md devient un cache optionnel, régénérable depuis les headers.

---

## Références

- Fichiers concernés : tous les satellites brain (6 repos)
- Sessions où la décision a émergé : sess-20260315-1105-brain (brainstorm coach + tech-lead)
- Agents à créer : `spec-scribe`, `migration-scribe`
- Agents à patcher post-migration : scribe, todo-scribe, toolkit-scribe, orchestrator-scribe,
  coach-scribe, capital-scribe, config-scribe, git-analyst, spec-scribe, migration-scribe
