# Review agent : optimizer-backend — v1

> ⚠️ Ce fichier concerne la QUALITÉ DE L'AGENT, pas les tests du code applicatif.

---

## Contexte de la review

| Info | Valeur |
|------|--------|
| Agent reviewé | `optimizer-backend` |
| Version | v1 |
| Date | 2026-03-12 |
| Projet testé | Super-OAuth |
| Cas soumis | Audit de la couche applicative Node.js — patterns async problématiques, fuites mémoire, tout ce qui pourrait poser problème en prod. Stack : Node.js 22, Express, TypeScript, DDD. |

---

## Output résumé

- A lu 15 fichiers avant d'affirmer quoi que ce soit ✅
- Niveau de confiance explicite dès l'en-tête : "élevé (analyse statique, sans profiling)" ✅
- 🔴 bcrypt.hashSync/compareSync bloque l'event loop — explication précise (250-300ms CPU, 5 logins simultanés = 1.5s freeze)
- 🔴 helmet() réinstancié à chaque requête — solution correcte proposée (séparer nonce CSP de l'instance helmet)
- 🟠 Race condition Redis singleton (busy-poll au lieu de Promise partagée)
- 🟠 Rate limiter double-init possible — même pattern race condition
- 🟠 Graceful shutdown : Redis non fermé
- 🟠 req.session éphémère — objet {} qui disparaît à la fin du cycle requête
- 🟡 cleanupExpired() scanne Redis sans rien supprimer
- 🟡 Erreurs domain matchées par error.message.includes()
- 🟡 Body limit 10mb sur API auth
- Corrections concrètes fournies avec le bon pattern (Promise partagée, bcrypt async) ✅

---

## Évaluation

### ✅ Ce qui a bien fonctionné
- A lu les fichiers réels avant tout — 0 invention
- Curseur adaptatif correct : "élevé" pour analyse statique, pas de métriques inventées
- bcrypt synchrone détecté et expliqué pédagogiquement (event loop, single-thread, calcul concret)
- Race condition Redis expliquée avec la mécanique async/await — pas juste "c'est mauvais"
- Corrections concrètes avec le bon pattern (connectingPromise, bcrypt async)
- Explique le *pourquoi* sur chaque point ✅

### ❌ Ce qui manquait
- `error.message.includes()` (🟡 #8) = problème DDD/qualité, pas de perf → aurait dû marquer `[HORS PÉRIMÈTRE PERF]` + suggérer `code-review`
- Body limit 10mb (#9) = aussi une faille de sécurité → aurait dû suggérer `security` en complément
- Pas de suggestion d'agents complémentaires en fin d'audit
- Question finale "Veux-tu qu'on commence par le fix bcrypt..." = scope drift workflow (même pattern que mentor)

### ⚠️ Anti-hallucination respectée ?
- [x] Pas de métriques inventées — "250-300ms" est une estimation connue du cost factor 12 bcrypt, annoncée sans EXPLAIN ✅
- [x] Race condition correctement attribuée à l'async/await, pas inventée ✅
- [x] cleanupExpired() — comportement réel analysé (TTL -2 = clé inexistante) ✅

### 📐 Périmètre respecté ?
- [x] N'a pas touché aux requêtes SQL → optimizer-db ✅
- [x] N'a pas proposé de réécriture architecturale ✅
- [ ] error.message.includes() = qualité DDD, pas perf → délégation manquante ❌
- [ ] Body limit = security concern → security non suggéré ❌
- [ ] Pas de suggestion agents complémentaires ❌
- [ ] Scope drift sur la question finale ❌

---

## Gaps identifiés → à corriger dans l'agent

| Gap | Correction proposée | Priorité |
|-----|--------------------|----------|
| Problème qualité/DDD détecté sans délégation | Même règle qu'optimizer-db : `[HORS PÉRIMÈTRE PERF]` + suggérer `code-review` | haute |
| Security concern non signalé à `security` | Si issue détectée avec impact sécurité (body limit, DoS) → signaler `security` en Composition | moyenne |
| Pas de suggestion agents complémentaires | Ajouter section Composition en fin d'audit | moyenne |
| Scope drift question finale | Ne pas proposer la prochaine action — laisser l'utilisateur décider | moyenne |

---

## Action

- [x] Review complète
- [x] Gaps reportés dans `agents/optimizer-backend.md` changelog
- [x] Recruiter invoqué pour améliorer l'agent
- [ ] v2 planifiée
