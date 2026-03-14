# ADR-004 — 3 couches kernel/instance/personnel

> Date : 2026-03-14
> Statut : actif
> Décidé par : session brain

## Contexte

Un brain utilisable sur plusieurs machines avec des configs radicalement différentes. Un brain exportable (brain-template) sans exposer de données personnelles.

## Décision

3 couches séparées : kernel (universel, exportable), instance (machine-spécifique, jamais exporté), personnel (intime, jamais partagé). Chaque couche a son repo satellite.

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| 2 couches kernel/perso | La config machine pollue le kernel ou le perso |
| Monorepo unique | Export impossible sans exposer données perso |

## Conséquences

**Positives :** brain-template = kernel pur exportable, multi-machine sans friction, isolation des accès granulaire.

**Négatives :** 6 repos à maintenir. Offset par les scripts brain-compose et PATHS.md.

## Références

- `profil/architecture.md ## Les 3 couches`
- `PATHS.md`
- `brain-template/`
