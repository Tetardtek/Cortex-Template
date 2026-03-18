---
id: ADR-034
title: Séparation infra — local (owner) / VPS (brain-template)
status: accepted
date: 2026-03-18
deciders: [human, coach]
tags: [infra, distribution, brain-template, dev-loop, vps]
scope: kernel
---

# ADR-034 — Séparation infra : local (owner) / VPS (brain-template)

## Contexte

Jusqu'au 2026-03-18, le brain-ui local pointait sur le VPS (`brain.<OWNER_DOMAIN>`)
via le proxy Vite. Conséquences :

- En dev, le Cosmos montrait les embeddings du VPS — pas les changements locaux
- Le dev loop était cassé : modifier embed.py local → invisible en local
- Le VPS exposait le brain personnel du owner (ADRs privés, projets perso, bact)
- Un utilisateur qui visite le VPS voit le brain du owner, pas un produit

La distribution de brain-template (ADR-031) impose une séparation claire :
un utilisateur qui découvre le produit ne doit pas tomber sur le brain privé du créateur.

---

## Décision

### Deux instances, deux rôles

```
Local (prod-laptop)
  → brain owner, privé
  → brain-engine port 7700, BRAIN_TIER=owner
  → brain-ui Vite port 5173, proxy → localhost:7700
  → brain.db local (re-embed cron 6h + on-demand)
  → jamais exposé publiquement

VPS (brain.<OWNER_DOMAIN>)
  → brain-template, démo produit
  → ce que le monde voit en premier
  → kernel ouvert, agents de référence, zéro données owner
  → brain-engine + brain-ui déployés depuis brain-template
```

### Dev loop validé

```
1. Modifier le brain local (agents, embed, brain-ui)
2. Tester sur localhost:5173/ui/  →  brain-engine local  →  brain.db local
3. Valider (dry-run, --stats, Cosmos local)
4. Commit + push
5. Déployer sur VPS uniquement si validé
```

Même principe que le swarm-ready gate (ADR-032) : au moins un run validé
en local avant de toucher le prod.

### Conséquences immédiates (2026-03-18)

- `vite.config.ts` proxy → `http://localhost:7700` + rewrite `/api → ''` + `ws: true`
- `scripts/dev-start.sh` — démarre brain-engine + Vite en un seul Ctrl+C
- `BRAIN_TIER=owner` en dev (pas de token requis, tier explicite)
- `numpy` + `umap-learn` installés localement (UMAP local opérationnel)

---

## Zone filter comme prérequis de distribution

ADR-033a est le fondement de sécurité qui rend cette séparation viable :

```
profil/bact/         → JAMAIS indexé  → owner invisible au VPS
profil/decisions/    → scope kernel   → archi partageable, décisions perso non
personal             → JAMAIS         → souveraineté par instance
```

Sans ADR-033a, exposer le brain-engine sur le VPS = exposer le bact owner.
Avec ADR-033a, chaque instance est souveraine sur son privé — le MCP est safe
par construction.

---

## Chemin vers brain-template sur VPS

```
1. ADR-033a live (zone filter)            ✅ 2026-03-18
2. ADR-034 (séparation infra)             ✅ 2026-03-18
3. Déployer brain-template sur VPS        → prochaine étape
4. VPS = démo kernel propre               → zéro données owner
5. brain-key-server valide les tiers      → free / pro / owner par clé
```

---

## Note — Cosmos temps réel (future)

Deux modes d'embedding identifiés :

```
Mode actuel  → cron 6h + on-demand (re-embed manuel)  ← validé
Mode futur   → file watcher (inotify) → re-embed sur write  ← ADR-035 territory
```

Le temps réel est orthogonal à cette décision — déclenché sur besoin concret.

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Proxy Vite → VPS en dev | Dev loop cassé, Cosmos montre le VPS pas le local |
| Un seul brain sur VPS | Mélange données owner + produit — confidentialité rompue |
| brain-template = copie du brain owner | Expose données privées à la distribution |

---

## Conséquences

**Positives :**
- Dev loop complet local — chaque changement visible immédiatement
- VPS propre pour la démo — ce que le monde voit = le produit, pas le owner
- Confidentialité garantie par construction (ADR-033a)
- La boucle dev local → validate → VPS prod est celle qui sera documentée pour les futurs contributeurs

**Négatives / trade-offs assumés :**
- Deux environnements à maintenir (local + VPS)
- `scripts/dev-start.sh` requis pour démarrer l'env dev (acceptable)
- numpy/umap-learn à installer localement (one-time, documenté)

---

## Références

- ADR-031 — Distribution model brain-template
- ADR-033a — Embedding zone filter (prérequis sécurité)
- ADR-032 — Mode d'exécution (swarm-ready gate — même logique local→prod)
- `scripts/dev-start.sh` — démarrage env dev local
- `brain-ui/vite.config.ts` — proxy config dev
- Session 2026-03-18 — validation empirique complète du dev loop
