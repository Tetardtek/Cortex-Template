# ADR-005 — Zones typées + protection graduée — KERNEL.md comme loi active

> Date : 2026-03-14
> Statut : actif
> Décidé par : session brain sess-20260315-0000-brain-template + coach

## Contexte

Le brain a grandi sans loi formalisée sur qui peut écrire quoi. Les agents peuvent dériver entre zones. Sans capstone architectural, le système vieillit mal.

## Décision

KERNEL.md à la racine = loi active chargée Couche 0. 4 zones typées (KERNEL, SATELLITES, INSTANCE, WORK) avec protection graduée. Flux unidirectionnel : satellite → kernel, jamais l'inverse. ARCHITECTURE.md archivé dans profil/ comme mémoire épisodique.

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| profil/kernel-zones.md | Trop périphérique — la loi doit être visible à la racine |
| Enrichir ARCHITECTURE.md | Confond décisions passées et lois actives |
| Pas de fichier de loi | Dérive garantie sur 20+ agents |

## Conséquences

**Positives :** tout agent au boot sait sa zone, sa protection, son commit type. Maintenabilité longue durée. Base pour le modèle de licence par zone.

**Négatives :** KERNEL.md lui-même ne peut pas être modifié sans décision humaine — friction assumée et voulue.

## Références

- `KERNEL.md`
- `profil/architecture.md`
- Session brainstorm coach 2026-03-14
