# ADR-006 — Vision produit : brain as a service — matrice instanciable

> Date : 2026-03-15
> Statut : vision — implémentation post v1.0.0
> Décidé par : session brainstorm coach sess-20260315-0100-vision-kernel

---

## Contexte

Le brain est une matrice de fichiers structurés qui instancie une intelligence contextuelle dans n'importe quel LLM. Le LLM est interchangeable — il est le moteur, pas le produit. Le produit est la matrice.

Trois insights émergés en session :
1. Le typage fort des agents (zones, protection, RFC contexts) rend la matrice défendable
2. BYOK existe déjà dans le brain (MYSECRETS, brain-compose.yml feature_set)
3. La première instance publique = fenêtre d'avance avant que d'autres reproduisent

---

## Décision

Construire `brain.tetardtek.com` — service web self-hosted — comme premier point d'entrée public. L'utilisateur apporte sa clé API (BYOK). Le brain fournit la matrice. La subscription contrôle les zones accessibles.

**Ne pas open-sourcer avant d'être sur les radars.** Apparaître d'abord, décider ensuite.

---

## Architecture produit

```
brain.tetardtek.com
  ├── Interface web (session browser)
  ├── BYOK — utilisateur fournit sa clé API LLM
  ├── Matrice servie depuis infra tetardtek (zones contrôlées)
  ├── BSI géré côté serveur (multi-tenant)
  └── Subscription → feature_set → zones débloquées
```

### Tiers d'accès (granulaire par zone)

| Tier | Zones accessibles | Ce que ça donne |
|------|------------------|-----------------|
| **Free** | Agent de base + personnalité + quelques tricks | Assez pour voir la valeur |
| **Pro** | + profil/ + progression/ | Mémoire personnelle, coach, capital |
| **Stack** | + agents par stack (React, Node, Docker...) | Expertise domaine |
| **Protocol** | + contexts/protocol.md (RFC) | Agents mail, OAuth, sécurité RFC |
| **Enterprise** | Tout + multi-sessions BSI + supervisor | Workflows parallèles |

### Modèle économique

```
Utilisateur  →  apporte sa clé API LLM (BYOK)
tetardtek    →  fournit la matrice + les zones + les updates kernel
              →  facture la valeur ajoutée, pas le compute
```

---

## Ce qui existe déjà (prérequis couverts)

| Composant | État |
|-----------|------|
| KERNEL.md zones + protection | ✅ v0.6.0 |
| feature_set dans brain-compose.yml | ✅ |
| BYOK pattern (MYSECRETS) | ✅ |
| metabolism/ usage tracking | ✅ |
| BSI claims + sessions | ✅ |
| VPS + SSL + Apache + Docker | ✅ |
| brain-template exportable | ✅ v0.6.0 |

---

## Ce qui manque (prérequis à construire)

| Composant | Priorité |
|-----------|----------|
| Interface web (session browser) | Prérequis #1 |
| Multi-tenant BSI (isolation par user) | Prérequis #2 |
| Auth token signé cryptographiquement | Prérequis #3 |
| brain-template v1.0.0 (interface contractuelle stable) | Gate de lancement |
| Billing intégration (subscription → feature_set) | Post-lancement |

---

## Le moat défendable

La matrice se copie. La longueur d'avance vient de :
1. **Distribution** — premier sur brain.tetardtek.com
2. **Mémoire des décisions** — 6 ADRs, les "pourquoi" ne se copient pas
3. **Écosystème** — toolkit/ patterns validés en prod, toolkit-scribe, progression/
4. **Instanciable** — pas de dépendance à un seul LLM provider

---

## Risque principal

D'autres voient le code source et reproduisent. Mitigation : apparaître sur les radars avant de rendre le code accessible. La fenêtre d'avance = distribution + réputation établie.

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Open source immédiat | Perd la fenêtre d'avance avant distribution établie |
| API propriétaire (pas BYOK) | Coût compute à absorber + dépendance fournisseur |
| CLI only (pas web) | Friction trop élevée pour adoption grand public |

---

## Conséquences

**Positives :** modèle économique viable, BYOK = zéro coût compute, zones = granularité billing naturelle, brain-template = produit exportable.

**Négatives / trade-offs :** multi-tenant BSI = complexité infra. Accepté — c'est l'investissement technique pour le moat.

---

## Références

- `KERNEL.md` — zones et protection = base du modèle de licence
- `brain-compose.yml ## feature_set` — mécanisme d'accès existant
- `profil/metabolism-spec.md` — usage tracking = base billing
- Session brainstorm coach 2026-03-15
