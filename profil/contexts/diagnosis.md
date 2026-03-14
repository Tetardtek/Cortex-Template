# diagnosis.md — Contexte mode diagnostic

> **Type :** Contexte — propriétaire : `debug`, `monitoring`
> Rédigé : 2026-03-14
> Résout : "debug multi-infra sans ordre de lecture des logs = hypothèses au hasard, diagnostic circulaire"

---

## Problème résolu

En environnement multi-services (VPS + containers + Node.js + MySQL + Apache + pm2), un bug peut venir de n'importe quelle couche. Sans ordre de lecture formalisé, le debug suit l'intuition — ce qui amène à relire les mêmes logs en boucle sans jamais identifier la cause racine.

Ce contexte impose un ordre d'investigation et un protocole d'hypothèses.

---

## Ordre de lecture des logs — multi-infra

### Couche 1 — Infrastructure (première)
```
systemctl status <service>         # est-il up ?
journalctl -u <service> -n 50      # dernières erreurs système
dmesg | tail -20                   # erreurs kernel (OOM, disk)
df -h && free -h                   # ressources (disk full = cause fréquente silencieuse)
```

### Couche 2 — Réseau / Proxy
```
# Apache / Nginx
tail -n 100 /var/log/apache2/error.log
tail -n 100 /var/log/nginx/error.log

# SSL
openssl s_client -connect <host>:443 -brief

# Ports
ss -tlnp | grep <port>
```

### Couche 3 — Application
```
# pm2
pm2 logs <app> --lines 100
pm2 show <app>                     # état mémoire, restarts

# Docker
docker logs <container> --tail 100
docker stats <container>           # mémoire / CPU
```

### Couche 4 — Base de données
```
# MySQL — dernières erreurs
tail -n 50 /var/log/mysql/error.log

# Connexions actives
SHOW PROCESSLIST;
SHOW STATUS LIKE 'Threads_connected';
```

### Couche 5 — Application code
```
# Uniquement après avoir éliminé les couches 1-4
# Logs applicatifs, stack traces, erreurs TypeScript runtime
```

---

## Protocole d'hypothèses

**Règle : une hypothèse à la fois, vérifiée avant la suivante.**

```
1. Formuler l'hypothèse : "Je pense que X est causé par Y parce que Z"
2. Identifier le log ou la commande qui confirme ou infirme Y
3. Exécuter — lire le résultat
4. Confirmer ou infirmer explicitement
5. Si infirmé → hypothèse suivante (pas de "peut-être les deux")
```

Anti-pattern à éviter :
- Proposer 3 causes simultanées sans les tester → confus, lent
- Modifier le code avant d'identifier la cause → cache le vrai problème
- "Ça vient sûrement de X" sans log qui confirme

---

## Questions de cadrage au démarrage d'un diagnostic

```
1. Quel service est affecté ? (nom précis)
2. Depuis quand ? (heure, event déclencheur)
3. C'est reproductible ? (always / intermittent / once)
4. Qu'est-ce qui a changé juste avant ? (deploy, config, restart)
5. Quel est le symptôme exact ? (message d'erreur complet ou comportement observé)
```

Ces 5 questions évitent 80% des diagnostics circulaires.

---

## Cross-services — quel serveur, quelle stack

En multi-infra (`prod@desktop` + VPS + containers) :

| Symptôme | Première couche à vérifier |
|----------|--------------------------|
| 502 Bad Gateway | Apache → pm2/container (dans cet ordre) |
| Connexion refusée | Port ouvert ? → Service up ? → Firewall ? |
| Lenteur API | pm2 logs → MySQL PROCESSLIST → Node heap |
| Auth échoue | JWT valide ? → Redis (sessions) → MySQL (user) |
| Mail non livré | SPF/DKIM → Stalwart logs → DNS |
| Deploy échoue | CI/CD logs → Docker build → VPS disk |

---

## Trigger de chargement

```
Propriétaire : debug, monitoring
Trigger      : session de type "debug" détectée, ou symptôme multi-services
Section      : Sources conditionnelles (debug — si infra détectée dans le scope)
```

---

## Maintenance

```
Propriétaire : debug (mise à jour si nouveau pattern de diagnostic validé)
Mise à jour  : en fin de session debug si une nouvelle séquence d'investigation a été utile
Jamais modifié par : agents non-debug
```

---

## Cycle de vie

| État | Condition | Action |
|------|-----------|--------|
| **Actif** | Sessions debug fréquentes | Enrichi après chaque pattern validé |
| **Stable** | Stack stable, peu de bugs infra | Consulté, rarement modifié |
| **Archivé** | N/A | Non applicable |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-14 | Création — ordre lecture 5 couches, protocole hypothèses, cross-services table, questions cadrage |
