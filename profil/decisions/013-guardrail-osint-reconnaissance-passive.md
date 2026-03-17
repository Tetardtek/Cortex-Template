---
name: adr-013-guardrail-osint
type: reference
context_tier: cold
---

# ADR-013 — Garde-fou HARDCODÉ : mémoire fine + capacités réseau = reconnaissance passive

> Date : 2026-03-16
> Statut : proposé — en attente session dédiée + commit kernel
> Décidé par : session brain dotfiles-violet-chaton (insight utilisateur)

---

## Contexte

Pendant la session du 2026-03-16, le pattern suivant s'est produit sans que le coach réagisse :

1. Lecture de `infrastructure/vps.md` → IP, ports, containers, pattern SSH chargés en contexte
2. Demande de scan réseau → 12 WebFetch en parallèle sur les sous-domaines
3. Résultat : cartographie complète de l'infrastructure en une session

L'utilisateur a soulevé que ce pattern — **mémoire fine d'infrastructure + capacités réseau** — est fonctionnellement identique à un workflow de reconnaissance OSINT passive. Entre de mauvaises mains (accès au brain d'une victime + modèle avec WebFetch), c'est un outil de ciblage.

Le problème n'est pas l'usage légitime (l'utilisateur qui audite sa propre infra). Le problème est que **le garde-fou n'existait nulle part** — ni dans `secrets-guardian`, ni dans `brain-constitution`. Le modèle a exécuté sans friction.

**Insight critique :** les garde-fous comportementaux ne suffisent pas. Un modèle différent, une version différente, un prompt différent — et le comportement change. Les règles doivent être dans Layer 0 pour être **modèle-agnostiques**.

---

## Décision

Ajouter à `brain-constitution.md` (Layer 0) une règle `[AGENT_RULE]` hardcodée qui impose une interruption explicite avant toute utilisation de capacités réseau lorsque des données d'infrastructure sensibles sont en contexte.

Cette règle doit être dans Layer 0 car :
- Layer 0 est identique pour tous les agents
- Layer 0 est lu avant toute action
- Layer 0 est immutable à runtime — aucun prompt ne peut le surcharger
- Un modèle différent (Claude 4, Claude 5, autre) bootant ce brain appliquera la règle

---

## Règle proposée pour brain-constitution.md (Section 2 ou nouvelle Section 10)

```
[AGENT_RULE] INVARIANT RECONNAISSANCE PASSIVE :
             Données d'infra sensibles en contexte (IP, ports, SSH, containers, credentials)
             AND capacité réseau sollicitée (WebFetch, URL, scan)
             → INTERRUPTION OBLIGATOIRE avant toute action réseau.
             Format : "⚠️ RECONNAISSANCE PASSIVE — confirmation requise [contexte / cible]"
             → Procéder UNIQUEMENT sur confirmation explicite de l'humain.
             Ce garde-fou s'applique peu importe le modèle, le contexte, l'urgence.
```

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Règle dans `secrets-guardian` seulement | Patchée (ADR-013 patch-1), mais non-hardcodée — dépend du chargement de l'agent |
| Règle comportementale (coaching) | Modèle-dépendant — ne résiste pas à un changement de version ou de prompt |
| Ne rien faire | Inacceptable — le pattern a été démontré fonctionnel le 2026-03-16 |

---

## Conséquences

**Positives :**
- Garde-fou modèle-agnostique — survit aux upgrades de Claude
- Toute session brain qui charge de l'infra + sollicite réseau = friction explicite
- Formalise l'insight "mémoire fine + OSINT = dangereux" dans le contrat du brain

**Négatives / trade-offs assumés :**
- Friction légère sur les scans légitimes (audit proprio de son infra)
- Requiert une confirmation manuelle — acceptable car rare et critique

---

## Actions requises avant activation

```
1. Session dédiée hors-projet (règle constitution — Section 8)
2. Relecture par coach
3. Commit kernel : "kernel: amend constitution v1.2.0 — ADR-013 reconnaissance passive"
4. brain-compose.yml bumped
5. Propagation brain-template
```

---

## Références

- Fichiers concernés : `brain-constitution.md`, `agents/secrets-guardian.md`, `infrastructure/vps.md`
- Sessions : session dotfiles-violet-chaton 2026-03-16 (scan VPS + insight utilisateur)
- Patch intermédiaire actif : `secrets-guardian.md` — Pattern OSINT passive (patch 2026-03-16)
