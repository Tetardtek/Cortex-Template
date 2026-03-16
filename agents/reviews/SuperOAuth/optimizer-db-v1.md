# Review agent : optimizer-db — v1

> ⚠️ Ce fichier concerne la QUALITÉ DE L'AGENT, pas les tests du code applicatif.

---

## Contexte de la review

| Info | Valeur |
|------|--------|
| Agent reviewé | `optimizer-db` |
| Version | v1 |
| Date | 2026-03-12 |
| Projet testé | Super-OAuth |
| Cas soumis | Audit des entités TypeORM — identifier les problèmes N+1, index manquants, et tout ce qui pourrait poser problème en perf avant la mise en prod. |

---

## Output résumé

- A lu les entités, repositories, services avant d'affirmer quoi que ce soit ✅
- Niveau de confiance explicite dès l'en-tête : "élevé (analyse statique, sans EXPLAIN)" ✅
- A utilisé le curseur adaptatif correctement (pas de slow query log → analyse statique)
- 🔴 Détecté : repositories stub non implémentés utilisés en prod (bug silencieux)
- 🔴 Détecté : session-new.entity.ts doublon avec conflit @Entity('sessions')
- 🟠 Détecté : filtre expiration côté JS au lieu de SQL (index expiresAt non exploité)
- 🟠 Détecté : eager loading systématique des sessions sur findUser*
- 🟡 Détecté : index boolean faible cardinalité, index redondant, refreshToken non indexé, varchar(500) pour JWT
- Niveau de confiance : moyen sur le point varchar(500) — mentionné explicitement ✅
- A proposé les corrections concrètes avec le code TypeORM correspondant ✅

---

## Évaluation

### ✅ Ce qui a bien fonctionné
- A lu les fichiers réels avant tout — analyse ancrée, 0 invention
- Curseur adaptatif utilisé correctement : "élevé" pour l'analyse statique, "moyen" sur l'estimation volumétrie
- Priorisation 🔴🟠🟡 cohérente et actionnelle
- Explique le *pourquoi* de chaque problème (pas juste "c'est mauvais")
- Corrections concrètes avec le bon opérateur TypeORM (`MoreThan`)
- A détecté des bugs réels au-delà des perf — honnêteté sur ce qui bloque vraiment

### ❌ Ce qui manquait
- Les issues 🔴 sont des **bugs**, pas des problèmes de perf. L'agent les a flaggés sans signaler qu'elles sortent de son périmètre → aurait dû écrire : "hors périmètre perf — à corriger avec `debug` ou `code-review` avant tout travail d'optimisation"
- Pas de suggestion d'agents complémentaires en fin d'audit : `code-review` pour les bugs structurels, `debug` pour le repository mock, `optimizer-backend` pour la couche applicative

### ⚠️ Anti-hallucination respectée ?
- [x] N'a pas inventé de plans d'exécution ("niveau de confiance : élevé, analyse statique") ✅
- [x] Niveau de confiance : moyen sur le varchar(500) — dépend du volume ✅
- [x] N'a pas affirmé que des requêtes étaient lentes sans EXPLAIN ✅
- [x] Toutes les références de fichiers et lignes sont réelles ✅

### 📐 Périmètre respecté ?
- [x] N'a pas touché à la config MySQL serveur → vps ✅
- [x] N'a pas proposé de modifier le schéma sans explication ✅
- [ ] Issues 🔴 = bugs hors périmètre perf → aurait dû déléguer explicitement ❌
- [ ] Pas de suggestion agents complémentaires ❌

---

## Gaps identifiés → à corriger dans l'agent

| Gap | Correction proposée | Priorité |
|-----|--------------------|----------|
| Bugs détectés hors périmètre perf sans délégation explicite | Ajouter règle : si un problème détecté n'est pas de la perf → le signaler avec `[HORS PÉRIMÈTRE PERF]` + suggérer l'agent compétent (`debug`, `code-review`) | haute |
| Pas de suggestion agents complémentaires | Ajouter section Composition en fin d'audit : `code-review` si bugs structurels, `optimizer-backend` si perf applicative identifiée | moyenne |

---

## Action

- [x] Review complète
- [x] Gaps reportés dans `agents/optimizer-db.md` changelog
- [x] Recruiter invoqué pour améliorer l'agent
- [ ] v2 planifiée
