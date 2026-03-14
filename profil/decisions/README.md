# decisions/ — Architecture Decision Records

> **Type :** Invariant — mémoire des choix architecturaux datés
> Format : ADR (Architecture Decision Record)
> Propriétaire : architecture-scribe (à forger) + décision humaine
>
> Jamais modifié rétroactivement. Uniquement enrichi.
> Un ADR décrit : contexte → décision → conséquences.

---

## Index

| ID | Date | Décision | Statut |
|----|------|----------|--------|
| 001 | 2026-03-14 | Locking optimiste BSI — claims + TTL vs mutex strict | actif |
| 002 | 2026-03-14 | Session-as-identity — slug session IS le rôle, pas de fork par rôle | actif |
| 003 | 2026-03-14 | Scribe Pattern — non-contamination, un scribe = un territoire | actif |
| 004 | 2026-03-14 | 3 couches kernel/instance/personnel — séparation exportabilité | actif |
| 005 | 2026-03-14 | Zones typées + protection graduée — KERNEL.md comme loi active | actif |

---

> Format fichier : `NNN-slug-court.md`
> Template : voir `_template-adr.md`
