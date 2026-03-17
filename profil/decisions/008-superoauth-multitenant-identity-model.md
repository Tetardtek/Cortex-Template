---
name: 008-superoauth-multitenant-identity-model
type: adr
context_tier: cold
---

---
id: ADR-008
title: SuperOAuth — Modèle d'identité multi-tenant
date: 2026-03-15
status: accepted
décideur: tetardtek
agents: tech-lead, security, coach
---

## Contexte

SuperOAuth est actuellement mono-tenant (OriginsDigital = seul client). La vision est de le transformer en SaaS multi-tenant vendable (modèle Auth0/Clerk). Les décisions d'identité prises maintenant sont irréversibles une fois qu'il y a des données réelles.

## Décisions tranchées

### 1. Scope UNIQUE sur linked_accounts

**Décision :** `UNIQUE(tenantId, provider, providerId)` — isolation complète par tenant.

**Pourquoi :** Un même compte Discord peut être utilisé sur deux apps différentes (deux tenants) sans conflit. Les utilisateurs sont scopés par service fourni. Alternative rejetée : UNIQUE global → un Discord ne peut être que sur un seul tenant → bloquant pour le SaaS.

**Conséquence :** Migration TypeORM requise. L'index actuel `UNIQUE(provider, providerId)` doit devenir `UNIQUE(tenantId, provider, providerId)`.

---

### 2. Email non vérifié en DB

**Décision :** Stocker `email + emailVerified=false`. Ne pas auto-linker. Bloquer le register classique si conflit → proposer le login à la place.

**Pourquoi :** Stocker `null` coupe l'ancre email définitivement. Stocker l'email avec le flag permet de retrouver le compte plus tard (link manuel depuis settings) et d'offrir un meilleur UX ("ce compte existe déjà, connecte-toi").

**Conséquence :** La route de register classique doit vérifier `emailVerified` avant de refuser — si email existe mais non vérifié → réponse spécifique `EMAIL_UNVERIFIED_EXISTS` au lieu de `EMAIL_ALREADY_TAKEN`.

---

### 3. Staleness users.email

**Décision :** Mettre à jour `users.email` si le provider retourne un email vérifié ET que ce provider était la source originale de `users.email`. Ne jamais écraser un email posé par une inscription classique.

**Pourquoi :** Évite les doublons quand un utilisateur change son email chez Discord. Protège l'email classique (posé volontairement par l'utilisateur) contre un écrasement involontaire par un provider.

**Conséquence :** Lors du callback OAuth, tracer l'origine de `users.email` (colonne `emailSource: 'classic' | 'provider:<name>'`).

---

## Architecture par tiers — plan produit

| Tier | Scope | Pattern clé | Repo |
|------|-------|-------------|------|
| 0 | Mono-tenant, 4 providers | UNIQUE(provider, providerId) global | superoauth-tier0 |
| 1 | Multi-tenant basic | tenantId + UNIQUE(tenantId, provider, providerId) | superoauth-tier1 |
| 2 | Identity features | Linking settings, merge, email verified gate, webhooks | superoauth-tier2 |
| 3 | Enterprise | Per-tenant providers, audit logs, custom JWT claims | superoauth-tier3 |

Chaque tier = sprint dédié = repo de démo autonome = reference implementation.

## Vision long terme — autonomous build

Le brain accumule les patterns (toolkit) et les décisions (ADRs). L'objectif est que des équipes d'agents spécialisées par tier puissent builder chaque tier depuis un brief sans intervention humaine sur le code.

Équipes cibles :
- Tier 1 : migration + security + tech-lead
- Tier 2 : + auth-specialist + testing
- Tier 3 : + enterprise-patterns + doc + optimizer-db

**Prérequis pour l'autonomie :** briefs de tier précis en todo/, toolkit suffisamment riche, orchestrator capable de décomposer un brief en sprint.

## Conséquences acceptées

- Migration Tier 0 → Tier 1 casse la compatibilité DB (acceptable : 0 utilisateurs réels)
- `emailSource` ajoute une colonne — migration légère mais requise
- Le délinkage n'est pas nécessaire avec l'isolation par tenant
