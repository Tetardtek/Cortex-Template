# Review agent : pm2 — v1

> ⚠️ Ce fichier concerne la QUALITÉ DE L'AGENT, pas les tests du code applicatif.
> Tests code → voir `projet/src/__tests__/` et Jest/Vitest.

---

## Contexte de la review

| Info | Valeur |
|------|--------|
| Agent reviewé | `pm2` |
| Version | v1 |
| Date | 2026-03-13 |
| Projet testé | Super-OAuth |
| Cas soumis | Configurer ecosystem.config.js + déploiement prod (reload 0-downtime + startup + save) |

---

## Output brut de l'agent

L'agent a fourni (depuis pm2.md au démarrage) :
- Un ecosystem.config.js template avec `instances: 1`, `exec_mode` non spécifié (fork par défaut)
- Un pattern CI/CD avec `pm2 reload super-oauth` présenté comme "0 downtime"
- La commande `npm ci --omit=dev` dans le deploy pattern CI/CD

Adapté pour Super-OAuth en session :
- `ecosystem.config.js` créé avec `instances: 2, exec_mode: 'cluster'` (correction de l'agent)
- `ci.yml` patché : `pm2 reload super-oauth --update-env` remplace le TODO
- env_production (au lieu de env) pour distinguer les environnements

---

## Évaluation

### ✅ Ce qui a bien fonctionné
- Chemin VPS correct (`/home/tetardtek/github/Super-OAuth`) — ancré dans les sources
- `watch: false` documenté avec le pourquoi
- `max_memory_restart` adapté au VPS Tetardtek
- `autorestart: true` inclus sans qu'on le demande
- Distinction `pm2 reload` vs `pm2 restart` mentionnée
- Commande `pm2 startup` + `pm2 save` correctement séquencée

### ❌ Ce qui manquait ou était incorrect

1. **0-downtime mensonger en mode fork** — L'agent dit "reload = 0 downtime" mais c'est faux avec `instances: 1` et fork mode. Un reload en fork = arrêt puis redémarrage = downtime. Le vrai 0-downtime nécessite `exec_mode: 'cluster'` + `instances >= 2`.

2. **`env` vs `env_production`** — Le template utilise `env` au lieu de `env_production`. La bonne pratique pm2 est d'utiliser des blocs nommés (`env_production`, `env_staging`) et de démarrer avec `--env production`. Avec `env`, les variables s'appliquent à tous les environnements.

3. **Duplication des variables d'env** — Le template met `PORT: 3000` dans l'ecosystem config. Si le `.env` contient déjà PORT, c'est une source de désynchronisation silencieuse. L'agent ne prévient pas de ce risque.

4. **`npm ci` vs `npm ci --omit=dev`** — Le deploy pattern CI/CD de l'agent utilise `--omit=dev`, mais le vrai `ci.yml` Super-OAuth fait juste `npm ci`. L'agent devrait aligner sur la réalité du projet ou expliciter le trade-off (taille node_modules en prod).

5. **Pas de `--update-env` sur `pm2 reload`** — Sans ce flag, pm2 ne recharge pas les variables d'environnement au reload. Critique si le `.env` a changé entre deux déploiements.

6. **Premier déploiement vs reload** — L'agent mentionne le cas mais sans la commande de détection. Comment savoir si pm2 connaît déjà le process ? Il manque la pattern de guard : `pm2 list | grep super-oauth || pm2 start ecosystem.config.js --env production`.

### ⚠️ Anti-hallucination respectée ?
- [x] A dit "Information manquante" quand nécessaire
- [x] N'a pas inventé de commandes/chemins/métriques
- [ ] Niveau de confiance explicite si incertain — absent sur la question "reload = 0 downtime" qui est présentée comme un fait alors que c'est conditionnel

### 📐 Périmètre respecté ?
- [x] N'a pas débordé sur d'autres domaines
- [x] A bien délégué ce qui ne le concernait pas (Apache, CI/CD complet)

---

## Gaps identifiés → à corriger dans l'agent

| Gap | Correction proposée | Priorité |
|-----|--------------------|----|
| `instances: 1` + fork présenté comme 0-downtime | Documenter explicitement que 0-downtime = cluster mode + instances >= 2. Mettre à jour le template. | haute |
| `env` au lieu de `env_production` | Changer le template — utiliser `env_production` + noter `pm2 start --env production` | haute |
| Pas de `--update-env` sur reload | Ajouter `pm2 reload <name> --update-env` partout où reload est mentionné | haute |
| Duplication PORT dans ecosystem | Avertir : ne mettre que `NODE_ENV` dans env_production, les secrets viennent du .env | moyenne |
| Guard premier déploiement | Ajouter pattern de détection : `pm2 list \| grep <name> \|\| pm2 start ...` | moyenne |
| `npm ci --omit=dev` vs `npm ci` | Aligner sur réalité projet ou documenter le trade-off explicitement | basse |

---

## Action

- [ ] Gaps reportés dans `agents/pm2.md` changelog
- [ ] Recruiter invoqué pour améliorer l'agent
- [ ] v2 planifiée
