---
name: ADR-011
type: decision
context_tier: cold
---

# ADR-011 — North Star : autonomie du brain indépendante de Claude

> Date : 2026-03-15
> Statut : actif
> Décidé par : brainstorm coach sess-20260315-1942-memory-coach

---

## Contexte

Brain V1.0.0 a été déclaré stable le 2026-03-15 avec : kernel lockée, BSI, multi-machine, constitution.
Un fondement manquait dans la déclaration : la direction vers laquelle le brain est conçu pour aller.

V1 est 100% Claude-dépendant. Sans une session Claude active, le brain est un dossier markdown bien organisé.
Cette dépendance n'est pas un bug — elle est le point de départ. Mais elle ne peut pas être le point d'arrivée.

---

## Décision

**Le brain est conçu pour réduire sa dépendance à Claude au fil du temps.**

Claude est le moteur de démarrage. L'autonomie est la direction.
Tout ce qui est réversible et sans effet externe doit pouvoir tourner sans intervention humaine ni session Claude.

Deux invariants découlent de cette décision :

```
INVARIANT AUTONOMIE :
  Réversible + sans effet externe  →  le brain exécute seul
  Irréversible OU affecte l'extérieur  →  escalade humaine obligatoire

INVARIANT AUTO-AMÉLIORATION :
  Le brain ne s'endommage jamais lui-même
  Toute action autonome le laisse dans un état meilleur ou égal
  Un agent autonome ne peut pas : supprimer une source, modifier un invariant,
  écraser un contexte sans backup
```

---

## Alternatives considérées

| Option | Raison du rejet |
|--------|----------------|
| Rester V1 sans north star déclaré | V2 risque de dériver vers "plus de features Claude" sans direction |
| North star en vision seulement (workspace/) | Trop faible — pas un invariant, peut être ignoré |
| Attendre V2 pour le déclarer | Le fondement manquant dans V1 oriente mal toutes les décisions intermédiaires |

---

## Conséquences

**Positives :**
- V2 a une mission claire : décroissance de la dépendance
- BE-1 (SQLite + cron) devient fondation, pas feature
- Chaque décision d'architecture peut être évaluée : "est-ce que ça rapproche de l'autonomie ?"
- Les agents autonomes ont un cadre légal dans la constitution

**Négatives / trade-offs assumés :**
- Ajouter une section 9 à brain-constitution.md = procédure formelle (ADR + commit kernel)
- L'autonomie complète est un horizon lointain — le déclarer crée une attente à gérer

---

## Références

- `wiki/concepts.md` — North Star documenté
- `workspace/brain-engine/vision.md` — North Star en tête de vision
- `brain-constitution.md` — section 9 à créer (patch v1.1.0)
- Session source : sess-20260315-1942-memory-coach
