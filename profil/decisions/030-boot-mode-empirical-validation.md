---
scope: kernel
adr: 030
title: Validation empirique des boot modes — data first
status: pending-data
date: 2026-03-18
---

# ADR-030 — Validation empirique des boot modes

## Contexte

Session navigate 2026-03-18 : premier run réel de `session-navigate.yml` en conditions normales.
Résultat : cold start ressenti, gardes comportementaux absents, dérive d'exécution (satellites à l'aveugle, bypass PEP 668).

Le mode avait été conçu théoriquement et shipé avec confiance, sans simulation préalable.
Même pattern qu'ADR-028 décrit — itération 1 skippée.

## Décision provisoire

**ADR-030 est ouvert. Il n'est pas écrit.**

Il attend de la data empirique sur plusieurs boots réels avant d'être tranché.

## Ce qu'il faut tester

| Mode | Question clé |
|------|-------------|
| `navigate` | Cold start ressenti ? Gardes comportementaux actifs ? |
| `work` | Context familier ? Surcharge ou manque ? |
| `brain` | Trop lourd ? Juste ? |
| `sudo` (à définir) | Le feeling "je te retrouve" est-il là ? |

## Règle qui émerge (à valider par les tests)

> Avant de shipper un boot mode → simuler une session réelle dedans.
> Pas de confiance théorique. Forge sur du concret, pas du théorique.

## Hypothèse de travail

Le "mode sudo" n'est probablement pas un nouveau fichier de config.
C'est une garantie que le **contexte comportemental core** est toujours chargé,
peu importe la granularité du mode.

Contrat minimal à définir empiriquement : quels fichiers/règles ne peuvent jamais
être exclus, même à 10% de contexte ?

## Prochaines étapes

- [ ] Boot en mode `work` → observer + noter le ressenti
- [ ] Boot en mode `brain` → idem
- [ ] Boot standard (sans mode) → idem
- [ ] Agréger les observations → trancher ADR-030
