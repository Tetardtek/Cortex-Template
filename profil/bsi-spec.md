# BSI — Brain Session Index

> **Type :** Contexte — propriétaire : `scribe`
> Spécification complète — version 1.0
> Rédigée : 2026-03-14
> Registre live : `brain/BRAIN-INDEX.md`

---

## Problème résolu

Plusieurs sessions brain en parallèle (machine locale + VPS + autre machine) peuvent modifier les mêmes fichiers sans se voir. Résultat : conflits git, perte d'information, incohérences.

Le BSI ne résout pas les conflits git — git le fait déjà. Il **prévient les collisions** en rendant les sessions visibles les unes des autres avant qu'elles modifient les mêmes fichiers.

---

## Stratégie : locking optimiste + TTL

**Pourquoi optimiste ?**
Le locking pessimiste (bloquer avant de lire) est trop coûteux sur un usage solo/semi-parallèle. La vraie collision est rare. On détecte et alerte — on ne bloque pas.

**Pourquoi TTL ?**
Une session crashée ou oubliée ne doit pas bloquer les autres indéfiniment. Le TTL la marque `stale` après expiration — l'humain décide de la libérer.

```
Optimiste = lire libre, déclarer son intention, détecter les overlaps
TTL       = deadline automatique, jamais auto-release sur action destructive
```

---

## Granularité multi-niveau

```
global              → tout le brain (ex: migration structurelle)
  └── dir/          → un dossier (ex: agents/, projets/)
       └── file.md  → un fichier spécifique
            └── ## Section → une section nommée dans un fichier
```

**Règle de conflit :** scope A ∩ scope B ≠ ∅ → conflit.
- Deux sessions sur le même fichier = conflit direct
- Une session sur un fichier dans un dossier déjà claimé = conflit parent/enfant
- Deux sessions sur des sections différentes du même fichier = **pas** de conflit (granularité section)

---

## Format Session ID

```
sess-YYYYMMDD-HHMM-<slug>
```

- `YYYYMMDD-HHMM` — date + heure locale d'ouverture (tri chronologique)
- `<slug>` — 4 chars alphanumériques aléatoires (évite les collisions à la même minute)

Exemples :
```
sess-20260314-0930-a3f9
sess-20260314-1045-bx2k
sess-20260315-1400-zr8p
```

---

## TTL par défaut

| Type de session | TTL |
|-----------------|-----|
| Session courte (fix, lecture) | 2h |
| Session deep work | 4h |
| Session longue (archi, migration) | 8h |
| Maximum absolu | 8h |

> Le scribe choisit le TTL selon le contexte annoncé. L'utilisateur peut demander un TTL custom.
> Au-delà de 8h : le claim passe `stale` automatiquement, même si la session est active.

---

## États d'un claim

| État | Signification | Transition |
|------|--------------|------------|
| `active` | Session en cours, scope déclaré | → `stale` (TTL expiré) ou → supprimé (fermé proprement) |
| `stale` | TTL expiré, session probablement morte | → supprimé (après contrôle humain) |

> `released` n'est pas un état visible — un claim fermé est simplement retiré de `## Claims actifs` et déplacé dans `## Historique`.

---

## Workflow scribe — lifecycle complet

### Ouvrir un claim

```
1. Générer session ID : sess-YYYYMMDD-HHMM-<slug>
2. Identifier le niveau : global / dir / file / section
3. Choisir TTL selon contexte (défaut : +2h)
4. Scanner BRAIN-INDEX.md ## Claims actifs
5. Vérifier conflit (scope A ∩ scope B ≠ ∅)
   → Conflit détecté : alerter humain, NE PAS créer le claim
   → Pas de conflit : continuer
6. Ajouter ligne dans ## Claims actifs
7. Confirmer : "Claim ouvert — [scope] / expire [TTL]"
```

### Fermer un claim

```
1. Identifier session ID (annoncé par l'utilisateur ou inféré du contexte)
2. Retirer de ## Claims actifs
3. Ajouter dans ## Historique : session, scope, ouvert, fermé, statut=completed
4. Confirmer : "Claim fermé — [session ID]"
```

### Watchdog (début de chaque session)

```
1. Lire ## Claims actifs
2. Pour chaque claim : comparer "Expire le" avec l'heure actuelle
3. Si expiré :
   → Déplacer vers ## Claims stale — contrôle requis
   → Annoter "Raison probable : TTL expiré sans fermeture"
4. Reporter : "[N] claims actifs, [M] stale détectés"
   → Si stale > 0 : demander action humaine avant de continuer
```

### Détecter un conflit

```
Nouveau claim sur scope B, claim existant sur scope A :
  - Si A == B → conflit direct
  - Si B est enfant de A (B dans le dossier A) → conflit parent/enfant
  - Si A est enfant de B → conflit parent/enfant
  - Si A et B sont des sections différentes du même fichier → pas de conflit

Action : alerter, ne pas créer. Proposer scope alternatif si possible.
```

---

## Quand ouvrir un claim

Ouvrir un claim uniquement si la session **va modifier** des fichiers brain. La lecture pure ne nécessite pas de claim.

| Intention de session | Claim ? | Niveau conseillé |
|---------------------|---------|-----------------|
| Lire uniquement | Non | — |
| Modifier 1 fichier précis | Oui | file |
| Modifier un domaine entier | Oui | dir |
| Migration / restructuration brain | Oui | global |
| Session brainstorm (pas d'écriture prévue) | Non | — |

---

## Règles absolues

1. **Jamais auto-release** sur action destructive — l'humain valide toujours
2. **Conflit détecté → alerte humain**, pas résolution silencieuse
3. **Stale ≠ libéré** — TTL expiré = stale, pas free. L'humain confirme avant suppression
4. **Scribe seul** écrit dans BRAIN-INDEX.md — jamais éditer manuellement
5. **8h maximum** — au-delà, tout claim passe stale sans exception

---

## Intégration git

Le BSI est **complémentaire à git, pas redondant.**

- Git résout les conflits après coup (merge, rebase)
- BSI prévient les collisions avant qu'elles arrivent
- `git blame BRAIN-INDEX.md` = audit trail complet des sessions

Le git log de BRAIN-INDEX.md EST le journal des sessions brain. Chaque commit scribe = entrée d'audit.

---

## Limite connue — version 1.0

Le BSI v1 est **déclaratif et manuel** — le scribe déclare un claim sur signal de l'utilisateur. Il n'y a pas de vérification automatique que la session a bien modifié uniquement le scope déclaré.

**Prochaine frontière (v2) :** vérification post-session via `git diff` — le scribe compare les fichiers modifiés au scope déclaré et signale les débordements.

---

## Changelog

| Date | Version | Changement |
|------|---------|------------|
| 2026-03-14 | 1.0 | Création — optimiste + TTL, 4 niveaux, workflow scribe complet |
