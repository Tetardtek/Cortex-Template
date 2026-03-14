# Procédure — Multi-sessions brain

> **Type :** Contexte — propriétaire : `scribe`
> Dernière mise à jour : 2026-03-14
> Pré-requis : BSI claims opérationnels, brain-watch actif

---

## Principe

Plusieurs sessions Claude Code en parallèle sur le même brain. Chacune a un rôle,
un scope déclaré dans le BSI, et peut passer du contexte aux autres via des signaux.

Le superviseur (cette session-ci, la session de coordination) observe le BSI et guide.

---

## Étape 1 — Planifier avant de lancer

Avant d'ouvrir les sessions, définir :

| Session | Rôle | Scope BSI | Fichiers touchés |
|---------|------|-----------|-----------------|
| sess-HHMM-backend | Backend | `projets/X.md`, `backend/` | src/routes, src/entities |
| sess-HHMM-frontend | Frontend | `projets/X.md ## Frontend`, `frontend/` | src/pages, src/components |
| sess-HHMM-supervisor | Coordination | `brain/ (dir)` | BRAIN-INDEX.md, handoffs/ |

**Règle scopes :** pas d'overlap. Si deux sessions touchent le même fichier → conflit BSI.
`projets/X.md` peut être partagé en lecture — seule la section owée est en write.

---

## Étape 2 — Ouvrir les sessions

Pour chaque session worker, au boot :

```
1. helloWorld fait le briefing standard
2. BSI : ouvrir un claim avec le bon slug et scope
   → sess-HHMM-backend  scope: backend/ (dir)
   → sess-HHMM-frontend scope: frontend/ (dir)
3. Commiter + pusher BRAIN-INDEX.md immédiatement
4. Confirmer dans le groupe Telegram Superviseur via /sessions
```

La session superviseur vérifie que les deux claims sont visibles dans `/sessions`
avant de donner le feu vert.

---

## Étape 3 — Travailler

Chaque session travaille dans son scope. Pas de coordination nécessaire tant
qu'il n'y a pas d'intersection.

**Si une session a besoin d'informer l'autre (CHECKPOINT en cours) :**

```
1. Créer brain/handoffs/sess-<id>.md depuis le template
   → Remplir : ce qui est fait, état actuel, prochaine étape
2. Écrire un signal dans BRAIN-INDEX.md ## Signals :
   | sig-YYYYMMDD-001 | sess-backend@desktop | sess-frontend@desktop | CHECKPOINT | projet | → handoffs/sess-backend-HHMM.md | pending |
3. Commiter + pusher
4. brain-watch notifie Telegram → supervisor voit le signal
5. La session cible lit le handoff file au prochain boot (ou sur demande)
```

---

## Étape 4 — Fermeture propre

Quand une session termine :

```
1. Optionnel : écrire un handoff final (HANDOFF type) si l'autre session continue
2. Commiter son travail sur le repo projet
3. Fermer le claim BSI :
   git -C ~/Dev/Docs add BRAIN-INDEX.md
   git -C ~/Dev/Docs commit -m "bsi: close claim <sess-id>"
   git -C ~/Dev/Docs push
4. Telegram reçoit : "Session fermée — claim libéré"
```

---

## Cas stale — exit sans fermeture

Si une session est fermée brutalement (Ctrl+C, fermeture fenêtre) sans fermer le claim :

```
Automatique :
  → brain-watch détecte TTL expiré → notifie Telegram une seule fois :
    "⚠️ Claim stale : sess-<id> — TTL expiré. Recovery requis."

Action humaine requise (dans la session superviseur) :
  1. Lire ce que la session faisait (git log du repo projet)
  2. Optionnel : écrire un handoff retroactif dans handoffs/
  3. Déplacer le claim de ## Claims actifs vers ## Claims stale
  4. Commiter : "bsi: mark stale <sess-id>"
  5. Confirmer : claim libéré, autres sessions peuvent reprendre le scope

Reprendre le travail dans une nouvelle session :
  1. Ouvrir une nouvelle session
  2. helloWorld détecte le claim stale → affiche le contexte si handoff disponible
  3. Ouvrir un nouveau claim avec un nouveau slug
```

---

## Checklist superviseur — multi-sessions

```
Avant :
  ☐ Scopes définis, pas d'overlap
  ☐ /sessions dans Telegram → vide ou claims attendus seulement

Pendant :
  ☐ /sessions après chaque boot session → vérifier que le claim est ouvert
  ☐ CHECKPOINT reçu sur Telegram → lire handoffs/, briefer la session cible si besoin
  ☐ Conflit BSI détecté → arbitrer (priorité mode : dev > prod > toolkit-only)

Après :
  ☐ /sessions → vide (tous les claims fermés)
  ☐ Claims stale résolus
  ☐ Scribe met à jour focus.md + projets/X.md
```

---

## Signaux BSI — types utilisés en multi-sessions

| Type | Quand | Payload |
|------|-------|---------|
| `CHECKPOINT` | Session A informe session B en cours de route | `→ handoffs/<sess-id>.md` |
| `HANDOFF` | Session A passe le relais à session B (fermeture) | `→ handoffs/<sess-id>.md` |
| `BLOCKED_ON` | Session A attend que session B libère un scope | scope concerné |
| `READY_FOR_REVIEW` | Session A demande une review à session B | fichier ou PR |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-14 | Création — procédure complète, cas stale, checklist superviseur |
