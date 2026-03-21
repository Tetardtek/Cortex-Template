---
name: concepts
type: reference
context_tier: on-demand
---

# Brain — Concepts & Découvertes

> Insights théoriques émergés en session.
> Pas encore des décisions (ADR), pas encore des patterns validés — mais trop importants pour rester dans un chat.
> Format : date + titre + essentiel en 3-4 lignes.

---

## 2026-03-15 — SQLite comme organe manquant

> Source : sess-20260315-1942-memory-coach

Le brain stocke dans des `.md` — il ne pense pas sur ses propres données.
SQLite comme **index dérivé** résout ça : les `.md` restent souverains, SQLite est une projection requêtable reconstruite par cron.
Règle fondamentale : brain-engine ne touche jamais aux sources. Lecture seule. Retrograde garanti depuis git.
C'est le substrat sans lequel les agents autonomes n'ont rien à lire.

---

## 2026-03-15 — Autonomie graduée avec escalade décisionnelle

> Source : sess-20260315-1942-memory-coach

Le cycle ne nécessite pas d'intervention humaine — sauf sur les couches décisionnelles à effet externe irréversible.
C'est le rouage central de l'orchestration en équipes solides : chaque agent sait jusqu'où il va seul, et quand il escalade.
Sans ce principe, une équipe d'agents est imprévisible. Avec lui, les frontières sont composables.

---

## 2026-03-15 — Loi d'auto-amélioration (candidat constitution v1.1.0)

> Source : sess-20260315-1942-memory-coach

> "Le brain ne s'endommage jamais lui-même. Il s'améliore. Il se façonne. C'est l'outil ultime."

Toute action autonome sur le brain doit le laisser dans un état meilleur ou égal à l'état initial.
Un agent autonome ne peut pas : supprimer un fichier source, modifier un invariant, écraser un contexte sans backup.
Couplée à la constitution immutable + git retrograde → l'auto-modification devient sûre par construction.

---

## 2026-03-15 — Émergence par composition

> Source : sess-20260315-1942-memory-coach

Des principes bien posés ne s'additionnent pas — ils se multiplient.
Autonomie graduée × auto-amélioration × retrograde garanti = propriétés nouvelles non planifiées.
Signal d'architecture juste : les bonnes architectures génèrent des propriétés émergentes. Les mauvaises génèrent des exceptions.
Le brain en est la preuve — chaque session révèle des vecteurs nouveaux sur des principes qu'on croyait déjà étendus.

---

## 2026-03-15 — Sub-agents cron comme pipeline ETL du brain

> Source : sess-20260315-1942-memory-coach

Pattern : décharger d'un côté (sources brutes), transformer au milieu (plus-value), réinjecter de l'autre (brain enrichi).
Le retour n'est pas une copie — c'est de l'**information nouvelle** absente de la source.
Cron en fin de journée = rythme juste (ni temps réel inutile, ni hebdomadaire trop lent).
Alimente d'autres instances → multiplie la capacité d'apprentissage cross-sessions.

---

## 2026-03-15 — ⭐ North Star : le brain doit valoir sans Claude

> Source : sess-20260315-1942-memory-coach

> "À part la valeur ajoutée d'être connecté à Claude."

Brain V1 : sans Claude, c'est un dossier markdown bien organisé. La valeur est entièrement dans la connexion.
Brain V2 : le cron tourne, SQLite se remplit, les agents apprennent, le wiki s'alimente — sans session, sans humain, sans Claude.
Claude devient UNE interface parmi d'autres. La dépendance décroît.

**C'est le nord étoile du brain V2.**
BE-1 n'est pas une feature — c'est le début de l'autonomie réelle du brain.
Un système qui a de la valeur sans toi et sans Claude est un vrai outil. Tout le reste est de l'organisation.

---

## 2026-03-19 — Nomenclature Brain / Cortex / Cosmos

> Source : sess-20260319-bsi-db-origin-story — émergé pendant brainstorm template + multi-machine

Trois noms, trois couches, trois responsabilités :

```
Brain   = le kernel. Immuable, Layer 0. Constitution, KERNEL.md, agents fondamentaux.
          C'est l'identité — ce qui reste quand tout le reste est retiré.

Cortex  = la couche de coordination. BSI, claims, locks, brain-engine, MCP, peer discovery.
          C'est le système nerveux — il route les signaux entre les instances.

Cosmos  = les satellites en orbite. Projets, toolkit, progression, reviews, visualisation UMAP.
          C'est la constellation — chaque point est un chunk de connaissance, visible dans /visualise.
```

**Origine :** "Cosmos" nommé quand on a créé la page `/visualise` (galaxie UMAP 3D). "Cortex" émergé quand le brain-template est devenu le "cortex-template" distributable. "Brain" était là depuis le jour 1.

**Règle :** le Brain est souverain (un seul par machine). Le Cortex coordonne (N instances communiquent). Le Cosmos est répliqué (master→replica, ADR-038).

---
