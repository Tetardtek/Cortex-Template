---
scope: kernel
id: ADR-031
title: Modèle de distribution brain — A court terme, B moyen/long terme
status: accepted
date: 2026-03-18
session: sess-20260318-1704-navigate
---

## Décision

Deux modèles de distribution validés, séquencés dans le temps.

**Modèle A — Self-hosted (court terme, maintenant)**
- Distribuer brain-template
- Les utilisateurs self-hostent leur brain-engine sur leur propre VPS
- Chacun embed ses propres fichiers → son propre brain.db → son propre MCP
- Coût infra pour Tetardtek : zéro supplémentaire
- Rôle Tetardtek : maintenir le kernel + distribuer le template

**Modèle B — Hébergé multi-tenant (moyen/long terme)**
- brain-store avec sharding par utilisateur (brain.db isolé par clé)
- brain_api_key (keys.<OWNER_DOMAIN>) = porte d'entrée facturation
- Tier enforcement + CATALOG déjà en place — infrastructure prête
- Trigger : premier utilisateur qui paie pour ne pas self-hoster

## Raison

Le Modèle B ne doit pas être construit avant d'avoir validé le Modèle A
sur de vrais utilisateurs. L'infra actuelle (VPS + brain-key-server + tier)
est déjà orientée Modèle B sans le savoir — c'est une progression naturelle.

Construire l'infra multi-tenant avant le premier client = sur-engineering garanti.

## Conséquence

- Ne pas implémenter brain-store sharding avant un use case concret
- Prioriser : kernel quality + template distributable + RAG VPS à jour
- Le fossé concurrentiel = brain.db accumulé dans le temps, pas le code
