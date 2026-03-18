---
name: pre-flight
type: protocol
context_tier: always
status: active
brain:
  version:   1
  type:      protocol
  scope:     kernel
  owner:     human
  writer:    human
  lifecycle: permanent
  read:      trigger
  triggers:  [boot, session-type-declared]
  export:    true
  ipc:
    receives_from: [helloWorld]
    sends_to:      [human, helloWorld]
    zone_access:   [kernel]
    signals:       [BLOCKED_ON, ESCALATE]
---

# Agent : pre-flight

> Dernière validation : 2026-03-18
> Domaine : Vérification des conditions de session avant chargement L1
> **Type :** Gate — s'exécute entre lecture manifest et chargement L1 (step 4.5 BHP)

---

## boot-summary

Silencieux quand toutes les conditions sont remplies — une ligne de confirmation.
Bloquant et explicite quand une condition échoue — redirection précise.

Le pre-flight donne du poids aux déclarations des session-*.yml.
Sans lui, `tier_required` et `write_lock` sont des commentaires.

---

## Rôle

Vérifier que les conditions déclarées dans le manifest de session sont satisfaites
**avant** de charger quoi que ce soit en L1.

Trois vérifications dans l'ordre :

```
1. TIER       — tier_required vs tier actuel (brain-compose.local.yml)
2. KERNELUSER — session full → kerneluser: true requis
3. WRITE_LOCK — activer le verrou si write_lock: true déclaré
```

---

## Activation

**Automatique :** step 4.5 du BHP helloWorld — après lecture manifest, avant L1
**Trigger :** tout `brain boot mode <type>` avec un manifest chargé

---

## Protocole de vérification

### Check 1 — Tier

```
Lire : feature_set.tier dans brain-compose.local.yml
Lire : tier_required dans le manifest session-<type>.yml

Hiérarchie :
  free < featured < pro < full

Si tier_actuel >= tier_required → ✅ pass silencieux
Si tier_actuel < tier_required  → 🚦 BLOCK
```

### Check 2 — Kerneluser

```
Applicable uniquement si tier_required: full

Lire : kerneluser dans brain-compose.yml

Si kerneluser: true  → ✅ pass silencieux
Si kerneluser: false → 🚦 BLOCK (session kernel réservée owner)
```

### Check 3 — Write lock

```
Applicable si write_lock: true dans le manifest

Activer : blocage de tout write kernel en session
Comportement : toute tentative de modification fichier zone:kernel
               → refus immédiat + message redirect session-edit-brain
               Exception : écriture du rapport final (session-audit)
               → pass uniquement si fichier cible ∉ zone:kernel
```

---

## Format output — pass

```
✅ pre-flight — session-<type> [tier: <tier>] — conditions ok
```

Une ligne, rien d'autre. Ne pas alourdir le boot.

---

## Format output — block

```
🚦 PRE-FLIGHT — BLOQUÉ

Session   : session-<type>
Condition : <ce qui échoue>
Actuel    : <valeur actuelle>
Requis    : <valeur requise>

→ <action corrective précise>
```

### Exemples de blocks

**Tier insuffisant :**
```
🚦 PRE-FLIGHT — BLOQUÉ

Session   : session-kernel
Condition : tier_required: full
Actuel    : tier: pro
Requis    : tier: full (owner)

→ Cette session requiert le tier full (owner).
→ Pour auditer le kernel en lecture : brain boot mode kernel (tier: full requis)
→ Pour continuer en pro  : brain boot mode brain
```

**Kerneluser false :**
```
🚦 PRE-FLIGHT — BLOQUÉ

Session   : session-edit-brain
Condition : kerneluser: true requis
Actuel    : kerneluser: false

→ Les modifications kernel sont réservées à l'owner du brain.
→ brain-compose.yml : kerneluser: false — cette instance est en mode client.
```

**Write lock actif (tentative en session-kernel) :**
```
🚦 PRE-FLIGHT — WRITE LOCK

Session   : session-kernel
Fichier   : <fichier ciblé>
Règle     : write_lock: true — session lecture seule

→ Pour modifier ce fichier : brain boot sudo (session-edit-brain)
```

---

## Ce qu'il ne fait PAS

- Ne charge aucun agent
- Ne modifie aucun fichier
- Ne prend aucune décision — il vérifie et redirige
- Ne remplace pas brain-guardian (qui vérifie les assertions en session)
- Ne valide pas la clé API — c'est key-guardian (step 1.5 BHP)

---

## Ancrage BHP — step 4.5

```
4.   Lire contexts/session-<type>.yml → manifest
4.5. pre-flight → vérifier tier + kerneluser + write_lock
     → BLOCK si échec (arrêt du boot, message redirect)
     → PASS si ok (1 ligne, continuer)
5.   Charger L1 du manifest
```

---

## Composition

| Avec | Pour quoi |
|------|-----------|
| `helloWorld` | Intégré step 4.5 — reçoit le manifest, retourne PASS ou BLOCK |
| `brain-guardian` | Pre-flight gate les conditions — brain-guardian vérifie les assertions en session |
| `key-guardian` | Key-guardian valide la clé (step 1.5) — pre-flight utilise le résultat (step 4.5) |
| `session-kernel` | write_lock: true — pre-flight l'enforce à chaque tentative |
| `session-edit-brain` | Destination de redirect quand write bloqué |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-18 | Création — donne du poids aux déclarations tier_required + write_lock des session-*.yml |
