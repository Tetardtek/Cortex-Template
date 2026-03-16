# Review agent : monitoring — v1

> ⚠️ Ce fichier concerne la QUALITÉ DE L'AGENT, pas les tests du code applicatif.

---

## Contexte de la review

| Info | Valeur |
|------|--------|
| Agent reviewé | `monitoring` |
| Version | v1 |
| Date | 2026-03-12 |
| Projet testé | Infra VPS |
| Cas soumis | Audit couverture Uptime Kuma — identifier les gaps entre ce qui est surveillé et l'infra réelle |

## Référence manuelle (avant test)

Manquants identifiés avant de lancer l'agent :
- Stalwart container + `mail.tetardtek.com` + ports SMTP 587 / IMAPS 993
- Gitea container + `git.tetardtek.com`
- Adminer container + `db.tetardtek.com`

---

## Output résumé

- A lu monitoring.md + vps.md + focus.md avant d'auditer
- Tous les gaps manuels identifiés ✅ (Gitea, Stalwart, Adminer, ports mail)
- Bonus : SSL Certificate expiry sur 5 domaines critiques — non planté
- Bonus : Super-OAuth /api/health à préparer post-pm2
- A posé "Information manquante" pour Stalwart (absent de vps.md) — mais inline contradiction (gap #1)
- A demandé confirmation avant de modifier monitoring.md

---

## Évaluation

### ✅ Ce qui a bien fonctionné
- Ancré dans les vrais fichiers — aucune invention de containers ou services
- Priorisation critique/important/niveau 2 cohérente
- Détecté les gaps manuels + 2 bonus non plantés (SSL expiry, /health Super-OAuth)
- A demandé avant d'appliquer les modifications
- Format tables claires + résumé numéroté ordonné

### ❌ Ce qui manquait
- Anti-hallucination partielle : ports Stalwart listés dans le corps sans `[HYPOTHÈSE]`, note "Information manquante" reléguée en bas — contradiction
- Pas de suggestion d'agents complémentaires (pattern transversal — `vps` était évident ici)

### ⚠️ Anti-hallucination respectée ?
- [x] A lu les bonnes sources avant d'affirmer ✅
- [~] Ports Stalwart listés sans étiquette hypothèse dans le corps ⚠️
- [x] "Information manquante" présent — mais mal placé (note finale au lieu d'inline)

### 📐 Périmètre respecté ?
- [x] Connaît l'infra réelle ✅
- [x] Détecte les gaps entre surveillé et existant ✅
- [x] Propose des sondes concrètes ✅
- [x] N'a pas débordé sur la config infra ✅

---

## Gaps identifiés → à corriger dans l'agent

| Gap | Correction proposée | Priorité |
|-----|--------------------|----|
| Ports non documentés listés sans `[HYPOTHÈSE]` inline | Règle : si port absent de vps.md → `[HYPOTHÈSE — à confirmer]` inline, pas en note finale | haute |
| Pas de suggestion agents complémentaires | Ajouter section Composition : `vps` + `debug` + `ci-cd` | moyenne |

---

## Note agent-review

`agent-review` a détecté les mêmes gaps + un extra (Gap #3 — /api/health assumé).
Format grille + étiquetage CONFIRMÉ/HYPOTHÈSE — efficace.
Premier test en conditions réelles : concluant.

---

## Action

- [x] Review complète
- [x] Gaps reportés dans `agents/monitoring.md` changelog
- [x] Patch appliqué par agent-review (anti-hallucination inline + Composition vps enrichie)
- [ ] v2 planifiée (prochain audit Kuma — après ajout des sondes manquantes)
