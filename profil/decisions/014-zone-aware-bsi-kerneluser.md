---
name: adr-014-zone-aware-bsi-kerneluser
type: reference
context_tier: cold
---

# ADR-014 — Zone-aware BSI claims + modèle kerneluser

> Date : 2026-03-16
> Statut : actif
> Décidé par : session product-strategist sess-20260316-2115

---

## Contexte

Le schéma BSI (v1.4) déclare `scope` (ex: `agents/`, `todo/brain.md`) mais ne distingue pas
la sensibilité de la zone cible. Un satellite `brain-write` sur `agents/` (kernel) et un satellite
`brain-write` sur `todo/` (instance) sont traités identiquement — même claim, mêmes règles.

Problème : le brain a déjà une hiérarchie de zones documentée dans `product-vision.md`
(zones 0-3) et `architecture.md` (kernel / instance / personnel). Cette hiérarchie
n'est pas connectée au protocole BSI. Résultat : la protection du kernel est implicite
et non-auditée.

Question soulevée : si le brain peut s'auto-éditer (satellites brain-write), qui a le droit
de toucher le kernel ? Tension entre "maître à bord" et "pas brider le système".

---

## Décision

**1. Ajouter `zone` comme champ calculé (inféré) dans le claim BSI.**

`zone` n'est pas écrit manuellement — il est inféré du `scope` au moment de l'ouverture du claim.
Cela évite toute friction sur l'usage courant tout en rendant la sensibilité auditable.

**2. `kerneluser` est un flag implicite owner dans `brain-compose.yml`, pas un champ claim.**

Le propriétaire du brain est toujours kerneluser. Le flag ne restreint pas l'owner —
il protège contre les futurs utilisateurs externes (SaaS, multi-user) qui ne peuvent pas
déclencher de satellite kernel-write sans délégation explicite.

**Règle fondamentale :**

```
Le brain peut s'auto-éditer librement — sous délégation owner.
Un satellite zone:kernel est autorisé si lancé par le propriétaire.
Un satellite zone:kernel lancé par un user externe = BLOCKED, autorisation requise.
```

---

## Mapping zone → scope

```
zone: kernel
  agents/                    → agents kernel (protégés, lifecycle permanent)
  profil/                    → specs, invariants, ADR
  KERNEL.md                  → loi des zones
  brain-constitution.md      → philosophie, invariants Layer 0
  brain-compose.yml          → feature flags, tiers
  scripts/                   → rituels, BSI, sync

zone: project
  todo/                      → intentions, sessions à planifier
  projets/                   → stack, état, contraintes projets
  workspace/                 → sessions actives
  handoffs/                  → contexte inter-sessions
  infrastructure/            → configs infra (sensible mais pas kernel)
  <repo-projet>/             → SuperOAuth, OriginsDigital, etc.

zone: personal
  profil/capital.md          → ressources, finances
  profil/objectifs.md        → buts personnels
  progression/               → journal, skills, milestones
  MYSECRETS                  → credentials absolus
```

---

## Champ `zone` dans le claim (inféré, non écrit)

```yaml
# Champ calculé — non écrit dans le claim
# Inféré automatiquement depuis `scope` selon le mapping ci-dessus
# zone: kernel | project | personal
```

| zone | Règle de close | Audit requis |
|------|---------------|-------------|
| `kernel` | Tier 3 Orchestrated si domain/pilote, sinon normal | Oui — git blame BRAIN-INDEX.md |
| `project` | Selon close_tier standard | Non |
| `personal` | Tier 2 Validated minimum — jamais sans confirmation | Oui — jamais auto |

---

## Modèle kerneluser

```
kerneluser = propriétaire du brain = celui qui a forké le kernel

Dans brain-compose.yml :
  kerneluser: true   → ce brain appartient à son owner (défaut : true sur tout brain perso)
  kerneluser: false  → instance invitée, user externe (futur SaaS)

Règles :
  kerneluser: true  → peut lancer des satellites zone:kernel sans restriction
  kerneluser: false → satellite zone:kernel → BLOCKED, délégation owner requise
```

**Pourquoi `kerneluser: true` est le défaut :**
Chaque brain forké est souverain. L'owner est toujours kerneluser sur son propre brain.
La restriction ne s'active que dans le contexte multi-user futur.

---

## Hiérarchie satellite — kernel vs project

```
Pilote (owner, kerneluser: true)
  ├── Satellite zone:kernel  → modifie agents/, profil/, scripts/
  │     Autorisé : owner délègue explicitement (launch = délégation)
  │     Interdit  : user externe sans délégation
  │
  └── Satellite zone:project → modifie todo/, projets/, workspace/
        Autorisé : tout utilisateur du brain
        Interdit  : zone:personal sans confirmation explicite
```

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| `zone` écrit manuellement dans le claim | Friction inutile — inférable mécaniquement depuis `scope` |
| Token BSI séparé (BRAIN_TOKEN_KERNEL) | Redondant avec le modèle de tokens existant dans product-vision — ajouter de la complexité sans valeur |
| Blocage total des satellites zone:kernel | Bride le système — contredit la philosophie "brain peut s'auto-éditer" |
| kerneluser = champ claim | Trop verbeux, trop répétitif — c'est une propriété du brain, pas d'une session |

---

## Conséquences

**Positives :**
- Le brain peut s'auto-éditer (satellites kernel) librement sous délégation owner — zéro friction sur usage solo
- La sensibilité des zones est auditable via `zone` inféré dans les claims
- Protection forward-compatible pour le multi-user SaaS futur — sans changer l'usage actuel
- Cohérence avec zones 0-3 (`product-vision.md`) et 3 couches (`architecture.md`)

**Négatives / trade-offs assumés :**
- `zone` inféré = logique de mapping à maintenir quand le brain évolue structurellement
- `kerneluser: false` n'est pas encore implémenté — c'est une spec forward, pas une feature active

---

## Actions requises

```
1. [x] ADR-014 rédigé (cette session)
2. [x] bsi-schema.md v1.5 — zone documenté comme champ calculé
3. [ ] brain-compose.yml — ajouter champ kerneluser: true (session dédiée kernel)
4. [ ] satellite-boot.md — ajouter vérification zone au boot satellite (BSI-v3-6)
5. [ ] KERNEL.md — documenter la règle de délégation zone:kernel
```

---

## Références

- `agents/bsi-schema.md` — schema claim
- `agents/satellite-boot.md` — protocole satellite
- `profil/product-vision.md` — zones 0-3, tokens, modèle distribution
- `profil/architecture.md` — 3 couches kernel/instance/personnel
- `profil/decisions/001-bsi-locking-optimiste.md` — origine BSI
