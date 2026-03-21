# Multi-instance — Guide pratique

> Comment lancer plusieurs instances Claude Code simultanément sans conflit.

---

## Ce que "simultané" veut dire

Chaque instance est une **fenêtre Claude Code indépendante**, ouverte en même temps.
Elles partagent le même repo git — mais le protocole BSI garantit qu'elles ne s'écrasent pas.

```
Fenêtre 1 (coach/discussion)    → lit, propose, décide
Fenêtre 2 (travail terrain)     → écrit du code dans superoauth/
Fenêtre 3 (brain maintenance)   → met à jour agents/, wiki/

Les 3 tournent en même temps. Zéro conflit si le protocole est respecté.
```

---

## Protocole de lancement d'une nouvelle instance

### 1. Ouvrir le claim (avant d'écrire quoi que ce soit)

```yaml
# claims/sess-YYYYMMDD-HHMM-<slug>.yml
sess_id:          sess-20260317-1000-superoauth-auth
type:             satellite
scope:            superoauth/src/auth/    ← périmètre exclusif de cette instance
agent:            satellite-boot
status:           open
opened_at:        "2026-03-17T10:00"
story_angle:      "Refacto module auth — JWT + session"
satellite_type:   code
satellite_level:  leaf
parent_satellite: <sess-id-du-pilote>
on_done:          notify → pilote
on_fail:          signal → BLOCKED_ON pilote
```

Commiter + pusher immédiatement :
```bash
git add claims/sess-*.yml
bash scripts/brain-index-regen.sh
git add BRAIN-INDEX.md
git commit -m "bsi: open satellite sess-20260317-1000-superoauth-auth"
git push
```

→ Les autres instances voient le claim dans `brain-status.sh` et `BRAIN-INDEX.md`.

---

### 2. Avant chaque écriture — pre-flight

```bash
bash scripts/preflight-check.sh check "$SESS_ID" "<filepath>"
```

Les 6 checks (automatiques) :
| # | Check | Bloque si… |
|---|-------|------------|
| 1 | Claim open | claim fermé, en pause, ou gate:human actif |
| 1b | Parent ok | pilote parent en pause ou failed |
| 2 | Scope | fichier hors scope déclaré |
| 3 | Zone:kernel | instance non-kernel tente d'écrire agents/scripts/etc. |
| 4 | Lock | autre instance a un lock actif sur ce fichier |
| 5 | Circuit breaker | trop d'échecs consécutifs (défaut : 3) |
| 6 | Branch | mauvaise branche git vs theme_branch déclaré |

---

### 3. Mutex pour les fichiers partagés (mode rendering / multi-instances)

Si deux instances peuvent vouloir écrire le même fichier :

```bash
# Avant d'écrire
bash scripts/file-lock.sh acquire "<filepath>" "$SESS_ID" 30
# → exit 1 = déjà locké → attendre ou signal BLOCKED_ON

# [écriture]

# Après avoir écrit
bash scripts/file-lock.sh release "<filepath>" "$SESS_ID"

# Enregistrer le résultat pour le circuit breaker
bash scripts/preflight-check.sh reset "$SESS_ID"   # succès
bash scripts/preflight-check.sh fail  "$SESS_ID"   # échec
```

---

### 4. Voir ce que font les autres instances

```bash
bash scripts/brain-status.sh          # vue complète
bash scripts/brain-status.sh claims   # qui travaille où
bash scripts/brain-status.sh locks    # fichiers verrouillés
bash scripts/brain-status.sh signals  # signaux en attente
```

---

### 5. Pause d'urgence (arrêter tout)

```bash
# Depuis n'importe quelle instance ou le pilote
bash scripts/human-gate-ack.sh pause "<sess-pilote>" "raison"
# → tous les satellites enfants sont stoppés en cascade
# → pre-flight bloquera toute écriture

# Reprendre
bash scripts/human-gate-ack.sh resume "<sess-pilote>"
```

---

### 6. Close propre

```bash
# Ajouter result: dans le claim
# Puis :
bash scripts/brain-index-regen.sh
git add BRAIN-INDEX.md claims/<sess-id>.yml
git commit -m "bsi: close satellite <sess-id>"
git push
```

---

## Règles de non-collision

| Règle | Mécanisme |
|-------|-----------|
| Deux instances ne partagent pas le même scope | BRAIN-INDEX + pre-flight CHECK 2 |
| Pas d'écriture kernel sans mandat kernel | pre-flight CHECK 3 (soft lock) |
| Pas d'écriture simultanée sur le même fichier | file-lock.sh (BSI-v3-7) |
| Un satellite mort ne bloque pas les autres | TTL sur les locks (défaut 60min) |
| Un pilote paused stoppe ses enfants | cascade human-gate-ack.sh (BSI-v3-5) |
| 3 échecs consécutifs = arrêt forcé | circuit breaker pre-flight CHECK 5 |

---

## Cas d'usage typiques

### Coach + travail terrain simultanés

```
Instance 1 : scope brain/   → discussion, décisions, lecture
Instance 2 : scope superoauth/ → code, tests, deploy
```
Pas de conflit possible : scopes disjoints.

### Deux satellites sur le même projet

```
Instance A : scope superoauth/src/auth/     → JWT refacto
Instance B : scope superoauth/src/api/      → endpoints REST
```
Scopes disjoints → pas de lock nécessaire.
Si un fichier est partagé (ex: types.ts) → file-lock.sh obligatoire.

### Mode rendering (instance autonome projet)

```yaml
mode: rendering
scope: superoauth/      ← seul périmètre autorisé
```
- zone:kernel → BLOCKED_ON immédiat (pre-flight CHECK 3)
- circuit_breaker : 3 fails → arrêt + signal pilote
- mutex sur chaque fichier écrit (file-lock.sh)

### BaaS — client vs owner

```
kerneluser: true  → owner — accès complet, peut forger le kernel
kerneluser: false → client — rendering mode, zone:project uniquement
```

---

## Référence rapide

```bash
# Voir l'état global
bash scripts/brain-status.sh

# Lancer le pre-flight avant d'écrire
bash scripts/preflight-check.sh check "$SESS_ID" "$FILE"

# Locker un fichier
bash scripts/file-lock.sh acquire "$FILE" "$SESS_ID" 30

# Pause d'urgence
bash scripts/human-gate-ack.sh pause "$SESS_PILOTE" "raison"

# Gate:human planifié
bash scripts/human-gate-ack.sh gate "$SESS_ID" "deploy ok ?"
bash scripts/human-gate-ack.sh approve "$SESS_ID"
```
