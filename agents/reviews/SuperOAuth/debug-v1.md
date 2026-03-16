# Review agent : debug — v1

> ⚠️ Ce fichier concerne la QUALITÉ DE L'AGENT, pas les tests du code applicatif.
> Tests code → voir `projet/src/__tests__/` et Jest/Vitest.

---

## Contexte de la review

| Info | Valeur |
|------|--------|
| Agent reviewé | `debug` |
| Version | v1 |
| Date | 2026-03-12 |
| Projet testé | Super-OAuth |
| Cas soumis | Stack trace reconstituée — `ER_BAD_FIELD_ERROR: Unknown column 'session.deviceFingerprint'` après git pull sur main |

---

## Output résumé

- Détecté immédiatement que `findByRefreshToken` ligne 34 ne correspond pas au fichier réel → anti-hallucination active
- Cause racine identifiée : migration `AddDeviceFingerprintToSessions` jamais exécutée
- Bug secondaire trouvé en bonus : `session.repository.ts` out-of-sync avec `ISessionRepository` (findByRefreshToken ne retourne pas deviceFingerprint, create() ignore metadata)
- Hypothèses ordonnées par probabilité
- Étapes de vérification concrètes (SHOW COLUMNS, SELECT migrations)
- A demandé confirmation avant de proposer le fix

---

## Output brut de l'agent

```
Cause identifiée. Voici l'analyse.

---
Diagnostic

1. REPRODUIRE — conditions exactes
Toute requête qui touche la table sessions via TypeORM → erreur immédiate.
Le trigger visible ici est RefreshTokenUseCase.execute → findByRefreshToken.

2. ISOLER — couche concernée
Couche infrastructure / base de données. TypeORM génère un SELECT incluant
la colonne device_fingerprint (déclarée dans l'entité) mais MySQL ne connaît
pas cette colonne.

3. HYPOTHÈSES ordonnées

Hypothèse 1 (cause racine) : Migration jamais exécutée — probabilité très élevée
La migration 1700000000000-AddDeviceFingerprintToSessions.ts existe dans le
repo. L'entité SessionEntity déclare ce champ. Mais si la migration n'a pas
été jouée contre la DB, MySQL ne connaît pas la colonne.

Hypothèse 2 (bug secondaire, indépendant) : Implémentation out-of-sync avec l'interface
session.repository.ts :
- findByRefreshToken retourne { userId, expiresAt } sans deviceFingerprint
- create() ne prend pas le paramètre metadata
→ fingerprint jamais persisté ni retourné, silencieusement incorrect.

4. VÉRIFIER — dans l'ordre
SHOW COLUMNS FROM sessions;
SELECT * FROM migrations;

Est-ce que tu confirmes que la colonne manque ?
Je prépare ensuite la commande de migration et le correctif du repository.
```

---

## Évaluation

### ✅ Ce qui a bien fonctionné
- A détecté l'incohérence stack trace vs fichier réel AVANT d'analyser — réflexe anti-hallucination fort
- Méthode 5 étapes suivie dans l'ordre (reproduire → isoler → hypothèses → vérifier → corriger)
- Hypothèses ordonnées par probabilité, pas en liste plate
- A trouvé un bug secondaire réel non planté (repository out-of-sync avec interface)
- A demandé vérification avant de proposer le fix — n'a pas corrigé sans confirmation
- Vérifications SQL concrètes et exécutables

### ❌ Ce qui manquait
- N'a pas proposé la commande de fix (`npm run migration:run`) dans les étapes de vérification — il l'a gardée pour "après confirmation"
- N'a pas suggéré `testing` après le fix éventuel
- N'a pas mentionné `code-review` pour le bug secondaire repository (out-of-sync avec interface)

### ⚠️ Anti-hallucination respectée ?
- [x] A signalé l'incohérence ligne 34 vs fichier réel immédiatement
- [x] N'a pas inventé de commandes — tout ancré dans les vrais fichiers lus
- [x] A distingué "cause racine" / "bug secondaire indépendant" clairement

### 📐 Périmètre respecté ?
- [x] Méthode 5 étapes respectée ✅
- [x] Hypothèses ordonnées par probabilité ✅
- [x] N'a pas corrigé sans isoler la cause ✅
- [ ] N'a pas délégué le bug secondaire vers `code-review` — aurait dû le signaler

---

## Gaps identifiés → à corriger dans l'agent

| Gap | Correction proposée | Priorité |
|-----|--------------------|----|
| N'a pas suggéré `testing` après le fix | Ajouter : "après fix, suggérer `testing` pour couvrir le comportement corrigé" | moyenne |
| N'a pas délégué bug secondaire vers `code-review` | Ajouter : "si bug secondaire hors scope debug détecté → signaler et proposer `code-review`" | basse |

---

## Note importante

Le bug secondaire (repository out-of-sync) était **réel** — corrigé dans la même session.
2 commits sur main : `fix(migration)` + `fix(session)`.

**Nuance sur le gap "testing" :** quand on lui a demandé explicitement, il a proposé 5 étapes de vérification incluant `npm test`. Le gap réel est "ne le propose pas spontanément après le fix" — pas "ne le sait pas faire".

---

## Action

- [x] Review complète
- [x] Gaps reportés dans `agents/debug.md` changelog
- [x] Règles ajoutées dans Périmètre
- [ ] v2 planifiée (prochain vrai bug prod)
