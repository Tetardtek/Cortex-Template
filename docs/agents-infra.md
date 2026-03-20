# Agents Infra & Deploy

> Les specialistes qui deploient, surveillent et maintiennent ton infrastructure.

---

## Deploy & Serveur

### vps

> 🟠 **pro**

Expert de ton VPS — deploie un nouveau service de A a Z :

```
1. Copier le template vhost Apache
2. Activer les modules (proxy, rewrite, headers)
3. Activer le vhost + configtest
4. Pointer le DNS
5. Generer le certificat SSL (Let's Encrypt)
```

Regle non negociable : `apache2ctl configtest` avant chaque reload — un typo = tous les services tombent.

Agit seul sur les actions non destructives. Demande confirmation avant de supprimer un vhost, modifier un container en prod, ou ouvrir un port.

---

### ci-cd

> 🟠 **pro**

Concoit et debug les pipelines CI/CD. Adaptatif par projet :

- **Site statique** → `git pull` uniquement
- **Node.js sans Docker** → `git pull` + `npm ci` + `npm run build`
- **Node.js avec Docker** → `git pull` + `docker compose up -d --build`
- **Config Apache changee** → + `apache2ctl configtest && systemctl reload`

Plateforme : GitHub Actions pour les projets publics, Gitea CI pour le prive.

---

### pm2

> 🟠 **pro**

Process manager Node.js en prod. Gere le cycle de vie des applications (start, restart, logs, monitoring). Intervient quand un process tombe ou consomme trop.

---

### migration

> 🟠 **pro**

Gere les migrations TypeORM — creation, modification, deploiement safe. Verifie que les migrations passent sans perte de donnees et que le rollback est possible.

---

## Surveillance

### monitoring

> 🟠 **pro**

Observabilite — configure les sondes Uptime Kuma, lit les logs VPS, detecte les anomalies. Suggere une sonde apres chaque nouveau deploiement.

---

### mail

> 🟠 **pro**

Specialiste Stalwart (serveur mail). Gere la config SMTP/IMAP, les enregistrements DNS (SPF, DKIM, DMARC), et le diagnostic des problemes de delivrabilite.

VPS gere le serveur, mail gere le protocole.

---

## Qui delegue a qui

- `vps` → `mail` (Stalwart) · `ci-cd` (pipeline)
- `ci-cd` → `vps` (config serveur) · `monitoring` (sonde post-deploy)
- `pm2` → `vps` (si probleme container)
- `migration` → `debug` (si migration echoue)
- `monitoring` → `vps` (diagnostic infra)
- `mail` → `vps` (serveur) · `security` (SPF/DKIM)
