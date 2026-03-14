# commands.md — Contexte commandes CLI sécurisées

> **Type :** Contexte — propriétaire : `vps`, `debug`, `ci-cd`
> Rédigé : 2026-03-14
> Résout : "commandes destructives exécutées sans dry-run, flags dangereux non identifiés, prod impacté"

---

## Problème résolu

Certaines commandes CLI sont irréversibles ou ont un impact prod immédiat. Sans protocole, un agent propose `rm -rf`, `docker system prune`, ou `git push --force` sans avertissement. Ce contexte donne les règles de comportement et les patterns de sécurité pour toute suggestion de commande.

---

## Règles fondamentales

### 1. Dry-run avant exécution

Toute commande destructive doit avoir un équivalent dry-run proposé en premier :

| Commande réelle | Dry-run |
|----------------|---------|
| `rsync src/ dest/` | `rsync -n src/ dest/` |
| `find . -name "*.log" -delete` | `find . -name "*.log"` (sans -delete) |
| `sed -i 's/old/new/' file` | `sed 's/old/new/' file` (sans -i) |
| `docker system prune` | `docker system df` d'abord |
| `git clean -fd` | `git clean -n` |
| `certbot renew` | `certbot renew --dry-run` |

### 2. Flags dangereux — annotation obligatoire

Toute commande avec un flag destructif ou irréversible est annotée `⚠️ DESTRUCTIF` ou `⚠️ IRRÉVERSIBLE` :

```bash
rm -rf /path/         # ⚠️ DESTRUCTIF — irréversible, pas de corbeille
git push --force      # ⚠️ IRRÉVERSIBLE — écrase l'historique distant
git reset --hard      # ⚠️ DESTRUCTIF — perd les modifications non commitées
docker system prune -a  # ⚠️ DESTRUCTIF — supprime toutes les images inutilisées
DROP TABLE users;     # ⚠️ IRRÉVERSIBLE — données perdues
```

### 3. Confirmation avant commande prod

Avant toute commande sur un système de production :
```
⚠️ Commande prod — confirme avant d'exécuter :
  Commande : <commande complète>
  Impact   : <ce qui sera modifié ou supprimé>
  Réversible : oui / non
```

---

## Patterns sécurisés par domaine

### Git
```bash
# Toujours préférer
git push origin <branch>           # branche explicite
git revert <commit>                # réversible — crée un commit inverse

# Avec confirmation obligatoire
git push --force-with-lease        # moins destructif que --force (vérifie upstream)
git reset --soft HEAD~1            # récupérable (staging intact)

# Jamais sans confirmation
git push --force                   # ⚠️ IRRÉVERSIBLE
git reset --hard                   # ⚠️ DESTRUCTIF
git clean -fd                      # ⚠️ DESTRUCTIF
```

### Docker
```bash
# Toujours lire avant d'agir
docker ps -a                       # containers existants
docker images                      # images présentes
docker system df                   # espace utilisé

# Dry-run equivalent
docker system prune --dry-run      # (si dispo) ou df d'abord

# Avec confirmation
docker stop <container>            # arrêt — reversible
docker rm <container>              # ⚠️ supprime le container (données volumes ok)
docker rmi <image>                 # supprime l'image
docker system prune -a             # ⚠️ DESTRUCTIF — toutes images non utilisées
```

### MySQL
```bash
# Backup AVANT toute modification
mysqldump -u root -p <db> > backup-$(date +%Y%m%d-%H%M).sql

# Transactions pour DDL risqués
START TRANSACTION;
  ALTER TABLE ...;
  -- vérifier avant COMMIT
ROLLBACK;  -- ou COMMIT si ok

# Jamais sans backup
DROP TABLE ...    # ⚠️ IRRÉVERSIBLE
TRUNCATE TABLE .. # ⚠️ IRRÉVERSIBLE
DELETE FROM ...   # ⚠️ sans WHERE = table vidée
```

### Fichiers système
```bash
# Préférer cp avant modification
cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

# Tester avant reload
nginx -t                           # validation config
apache2ctl configtest

# Jamais sans backup
rm -rf /var/www/<app>/             # ⚠️ DESTRUCTIF
```

---

## Ordre de validation pour les commandes VPS

```
1. Lire l'état actuel (status, logs, df)
2. Proposer la commande + dry-run si disponible
3. Annoter les flags dangereux
4. Attendre confirmation si commande prod/destructive
5. Exécuter
6. Vérifier l'état après (status, logs)
```

---

## Trigger de chargement

```
Propriétaire : vps, debug, ci-cd
Trigger      : session deploy, debug infra, ou toute commande shell sur VPS
Section      : Sources au démarrage (vps, ci-cd) — Sources conditionnelles (debug si infra détectée)
```

---

## Maintenance

```
Propriétaire : vps (mise à jour si nouveau pattern CLI validé)
Mise à jour  : en fin de session si un nouveau flag dangereux ou pattern sécurisé identifié
Jamais modifié par : agents non-infra
```

---

## Cycle de vie

| État | Condition | Action |
|------|-----------|--------|
| **Actif** | Sessions VPS/deploy fréquentes | Enrichi après chaque pattern validé |
| **Stable** | Stack stable | Consulté, rarement modifié |
| **Archivé** | N/A | Non applicable |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-14 | Création — règles dry-run, flags dangereux annotés, patterns git/docker/mysql/fichiers |
