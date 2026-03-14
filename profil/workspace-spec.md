# Workspace inter-sessions — Spécification

> **Type :** Contexte — propriétaire : `scribe`
> Dernière mise à jour : 2026-03-14
> Statut : v1.0 — première implémentation

---

## Origine — comment cette feature est née

Le workspace n'a pas été planifié. Il a émergé d'une observation faite pendant
le premier sprint dual-agent OriginsDigital (2026-03-14).

**Le problème observé en conditions réelles :**

```
Session backend a une question pour session frontend
  → backend écrit la question dans son output
  → humain lit
  → humain copy-paste vers frontend
  → frontend répond
  → humain copy-paste la réponse vers backend
  → backend continue
```

L'humain était le **relay** entre deux sessions qui ne pouvaient pas se parler.
Ce relay prenait du temps, introduisait des erreurs de transcription, et
empêchait toute coordination autonome.

**L'insight :**

Les sessions ont besoin d'un espace partagé — volatile pendant le sprint,
persistant comme trace après. Exactement comme de la RAM dans un ordinateur :
rapide, structurée, vidée à la fin de l'exécution (sauf archivage explicite).

**Pourquoi c'est limpide rétrospectivement :**

Le brain a déjà `handoffs/` (snapshot fin de session) et
`progression/journal/` (bilan pédagogique). Il manquait le **pendant** —
l'espace vivant où les sessions coexistent et coopèrent.

```
handoffs/           → snapshot APRÈS   (ce qui a été fait)
progression/journal → bilan APRÈS      (ce qu'on a appris)
workspace/          → vivant PENDANT   (ce qui se passe maintenant)
```

Le workspace est la troisième pièce qui complète le triptyque.

---

## Principe cardinal

> **Un agent qui travaille ne charge qu'une seule section du workspace.**
> Jamais le workspace entier.

La valeur du workspace est nulle si chaque session doit tout lire pour
trouver ce qui la concerne. Les droits de lecture ne sont pas optionnels —
ils sont la colonne vertébrale du système.

---

## Structure

```
brain/workspace/
  <projet>-<sprint>/
    README.md        → métadonnées, lifecycle, mode actif — 10 lignes max
    ram.md           → état live + questions inter-sessions (volatile)
    log.md           → décisions + audit trail (persistant)
    feedback.md      → retours post-sprint (jamais lu en sprint actif)
```

Un workspace par sprint. Pas par session, pas par projet global.
La granularité sprint est le bon niveau : assez court pour rester léger,
assez long pour capturer un arc de travail complet.

---

## Droits de lecture — par rôle

| Section | Worker | Supervisor | Coach-scribe |
|---------|--------|------------|--------------|
| `ram.md` | ✅ obligatoire | ✅ | ❌ |
| `log.md` | sur demande explicite | ✅ obligatoire | ✅ |
| `feedback.md` | ❌ jamais en sprint | ❌ jamais en sprint | ✅ après TTL |

**Règle d'or :** le worker charge `ram.md` au boot si un workspace actif existe.
Il ne charge `log.md` que si le supervisor le lui demande explicitement.
`feedback.md` n'existe pas pour lui pendant le sprint.

---

## Lifecycle — champ `archive` dans README.md

```yaml
## Lifecycle
ttl: 7d
archive: auto | keep | 30d | 90d | permanent
```

| Valeur | Comportement |
|--------|-------------|
| `auto` | TTL standard → archivé dans `handoffs/` → supprimé |
| `keep` | Suspend l'archivage — humain décide quand |
| `30d` / `90d` | Retention custom après fermeture du sprint |
| `permanent` | Jamais supprimé — devient référence documentaire |

**Qui gère le lifecycle :** `coach-scribe` — lit le champ `archive` au TTL expiry.
Si `keep` → notifie le supervisor pour décision humaine.

---

## Graduation par mode (`brain-compose.yml`)

Le contenu actif du workspace dépend du mode déclaré :

| Mode | Sections actives | Usage |
|------|-----------------|-------|
| `prod` | `ram.md` (state + questions) + `log.md` (décisions) | Sprint standard |
| `dev` | Tout | Expérimentation libre |
| `review` | `log.md` + resources ponctuels — pas de `ram` | Code review |
| `brainstorm` | `log.md` + `feedback.md` — pas de `ram` | Conception |
| `debug` | `ram.md` (state uniquement) + `log.md` | Debug focalisé |

---

## Anti-embourbage — règles dures

```
TTL workspace     = durée sprint + 7 jours (défaut)
Max ram.md        = 50 lignes actives (au-delà = stale, purger les résolus)
Max log.md        = 1 ligne par décision — pas de justification longue ici
feedback.md       = géré en session dédiée post-sprint par coach-scribe
Sections custom   = interdites — seulement README + ram + log + feedback
```

**Pourquoi pas de sections custom :** chaque section custom crée un nouveau
droit de lecture à définir, un nouveau template à maintenir, une nouvelle
règle de chargement. Le coût explose vite. Si un besoin ne rentre pas dans
les 3 sections → c'est soit un handoff, soit un signal BSI.

---

## Valeur post-sprint

Le workspace archivé répond à la question : **"pourquoi on a fait ça ?"**

```
Dans 3 mois, on revient sur OriginsDigital.
Pourquoi /auth/me retourne roles[] ?
→ workspace/originsdigital-sprint2/log.md ligne 4 :
  "2026-03-14 15:xx | Option 1 vs 2 — enrichir /auth/me | choisi : Option 1
   | raison : un seul appel, coût DB négligeable à cette échelle"
```

Pas besoin de fouiller le git log, pas besoin de se souvenir.
Le workspace archivé EST la documentation du raisonnement.

---

## Connexion aux autres systèmes

| Système | Relation |
|---------|----------|
| `BRAIN-INDEX.md ## Signals` | Coordination légère — workspace est la couche lourde |
| `handoffs/` | Snapshot final — workspace est le live |
| `progression/journal/` | Bilan pédagogique — workspace est le raw material |
| `brain-compose.yml` | Mode actif → détermine les sections actives du workspace |
| `coach-scribe` | Gère le lifecycle et alimente `feedback.md` post-sprint |

---

## Templates

Voir `brain/workspace/_template/` :
- `README.md` — métadonnées + lifecycle
- `ram.md` — état live + questions
- `log.md` — décisions + audit trail
- `feedback.md` — retours post-sprint

---

## Changelog

| Date | Version | Changement |
|------|---------|------------|
| 2026-03-14 | 1.0 | Création — émergé du sprint dual-agent OriginsDigital, triptyque pendant/après/après, 3 sections, droits de lecture, graduation modes, anti-embourbage |
