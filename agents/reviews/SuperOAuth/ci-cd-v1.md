# Review agent : ci-cd — v1

> ⚠️ Ce fichier concerne la QUALITÉ DE L'AGENT, pas les tests du code applicatif.

---

## Contexte de la review

| Info | Valeur |
|------|--------|
| Agent reviewé | `ci-cd` |
| Version | v1 |
| Date | 2026-03-12 |
| Projet testé | Super-OAuth |
| Cas soumis | Créer le pipeline de déploiement prod — CI actuel : tests seulement. À ajouter : build + SSH deploy + migration TypeORM. Stack : Node.js 22, TypeScript, Docker. |

---

## Output résumé

- A lu ci.yml avant de produire quoi que ce soit
- Identifié incohérence Node 20 CI vs Node 22 VPS → corrigé sur tous les jobs
- Détecté que migrations TypeORM nécessitent `npm ci` complet (pas `--omit=dev`) pour `typeorm-ts-node-commonjs`
- A bloqué sur le process manager — a posé la question explicitement plutôt qu'inventer
- Découvert que le backend n'est pas en route → a adapté le scope du deploy job (sans restart)
- TODO commenté proprement dans le workflow pour le restart futur
- 1 commit : `ci: add deploy job and align node version to 22.x`

---

## Évaluation

### ✅ Ce qui a bien fonctionné
- A lu le CI existant avant de toucher quoi que ce soit — ancré dans la réalité
- A détecté la Node mismatch 20→22 sans qu'on le lui demande
- A posé la question sur le process manager plutôt que d'inventer une commande (`pm2`, `systemctl`...)
- A adapté le scope quand il a appris que le backend n'était pas en route — pas d'invention
- TODO commenté dans le workflow : clean et exploitable
- A lire les fichiers VPS (`vps.md`) pour les secrets SSH sans les demander

### ❌ Ce qui manquait
- N'a pas proposé d'ajouter le template dans `toolkit/` (mentionné dans le plan de review comme critère)
- N'a pas suggéré `monitoring` après le deploy job (ajouter une sonde Kuma quand le backend sera en route)

### ⚠️ Anti-hallucination respectée ?
- [x] N'a pas inventé les secrets VPS — a lu vps.md
- [x] N'a pas inventé le process manager — a posé la question
- [x] N'a pas affirmé que le backend tournait — a adapté le scope

### 📐 Périmètre respecté ?
- [x] Adapté au type de projet (Node.js 22 + TypeScript) ✅
- [x] Connaît les secrets VPS ✅
- [ ] N'a pas proposé toolkit/ — gap
- [x] N'a pas créé le pipeline sans proposer d'abord ✅

---

## Gaps identifiés → à corriger dans l'agent

| Gap | Correction proposée | Priorité |
|-----|--------------------|----|
| N'a pas proposé toolkit/ | Ajouter dans Périmètre : "après création d'un pipeline réutilisable → proposer de l'ajouter dans toolkit/" | moyenne |
| N'a pas suggéré monitoring après deploy | Ajouter : "après deploy job → suggérer `monitoring` pour ajouter une sonde de surveillance" | basse |

---

## Action

- [x] Review complète
- [ ] Gaps reportés dans `agents/ci-cd.md` changelog
- [ ] Règles ajoutées dans Périmètre
- [ ] v2 planifiée (prochain projet sans pipeline)
