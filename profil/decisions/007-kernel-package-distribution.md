# ADR-007 — Kernel package distribution — brain install

> Date : 2026-03-15
> Statut : vision — prérequis v1.0.0
> Décidé par : session brainstorm coach sess-20260315-0100-vision-kernel

---

## Contexte

Le brain est distribué aujourd'hui via 6 git clones manuels. Friction trop élevée pour une adoption large. La question : peut-on hardcoder le kernel pour simplifier l'installation sans perdre la valeur de la matrice fichiers ?

Tension identifiée : le brain est entièrement éditable aujourd'hui (force pour le dev, faiblesse pour la distribution et le modèle de licence).

---

## Décision

Architecture hybrid kernel/instance :

```
~/.brain/kernel/     ← installé par package (brew/npm/curl), read-only, mis à jour via brain update
~/Dev/Docs/          ← instance personnelle (focus.md, todo/, progression/, projets/)
CLAUDE.md            ← pointe vers kernel + instance (brain_root: ~/.brain/kernel/)
```

Le kernel devient physiquement read-only par installation — ce qui **enforce KERNEL.md zones** au niveau filesystem, pas seulement par convention.

---

## Modèle d'installation cible

```bash
# Installation
brew install brain          # ou npm install -g brain / curl brain.<OWNER_DOMAIN>/install | sh

# Premier setup
brain init ~/Dev/Docs       # crée l'instance locale + CLAUDE.md configuré

# Mise à jour kernel
brain update                # git pull kernel → nouvelle version

# Par tier
brain install --tier=pro    # débloque zones profil/ + progression/
brain install react node    # ajoute agents stack React + Node
```

---

## Pourquoi hybrid et pas fat CLAUDE.md

| Option | Raison du rejet |
|--------|----------------|
| CLAUDE.md fat (tout embarqué) | Perd granularité zones, versioning fin, mise à jour partielle |
| Monorepo unique | Friction 6 clones = barrière adoption |
| **Hybrid kernel/instance** | ✅ Read-only kernel enforced, instance libre, `brain update` propre |

---

## Conséquences sur le modèle de licence

```
Licence = version du kernel distribué
  brain install --tier=free      → kernel zones free (agent base + tricks)
  brain install --tier=pro       → + profil/ + progression/ + coach
  brain install --tier=stack=react → + agents React + toolkit React
  brain install --tier=protocol  → + contexts/protocol.md (RFC)
```

La licence contrôle quelle version du package s'installe. Pas un token à dropper — le package manager enforce.

---

## Conséquences sur KERNEL.md zones

Le kernel read-only filesystem = KERNEL.md zone KERNEL protection maximale enforced par design, pas par convention. Un utilisateur ne peut pas modifier un agent kernel sans `sudo` — signal fort que c'est hors périmètre.

Les zones SATELLITES et INSTANCE restent dans `~/Dev/Docs/` — entièrement libres.

---

## Distribution v1 → v2

```
v1 : git clone (aujourd'hui — devs Claude Code, early adopters)
     "clone ce repo, configure ton CLAUDE.md"
     → Marché : devs qui comprennent immédiatement

v2 : brain install (post v1.0.0)
     → Marché : tous les devs + brain.<OWNER_DOMAIN> pour non-devs
```

---

## Prérequis techniques

| Composant | Priorité |
|-----------|----------|
| brain-template v1.0.0 (interface contractuelle stable) | Gate #1 |
| `brain` CLI (init, install, update, sync) | Prérequis #2 |
| Package registry (Homebrew formula / npm) | Prérequis #3 |
| Tier system dans brain-compose.yml | Existe déjà (feature_set) — à étendre |

---

## Références

- `KERNEL.md` — zones et protection = contrat du package
- `ADR-006` — vision produit brain-as-a-service (web + BYOK)
- `brain-compose.yml ## feature_set` — mécanisme tier existant
- Todo `brain new / brain sync` — CLI en cours de vision
