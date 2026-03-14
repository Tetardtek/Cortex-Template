# Philosophie du système d'agents

> Écrit : 2026-03-12 — à relire avant de créer ou modifier un agent

---

## Pourquoi ce système existe

Éviter de réexpliquer le même contexte à chaque session.
Un agent chargé arrive avec sa connaissance métier complète — zéro ré-onboarding.

---

## Principes fondateurs

**1. Ancré dans la réalité**
Chaque agent lit des fichiers brain/toolkit qui existent vraiment.
Aucun pattern inventé — si ce n'est pas dans les sources, ce n'est pas dans l'agent.

**2. Un agent = une responsabilité**
Trois domaines → trois agents en composition, pas un agent monstre.
La complexité minimale pour le besoin réel actuel — pas pour les besoins hypothétiques.

**3. Coordinateur pur vs agent métier**
L'orchestrator ne produit rien. Le mentor n'exécute rien. Le scribe ne code pas.
Chaque agent connaît sa limite et la respecte.

**4. Anti-hallucination non négociable**
Fait non vérifié → "Information manquante".
Incertitude → niveau de confiance explicite.
Jamais inventer : commandes, ports, chemins, métriques.

**5. CLAUDE.md = bootstrap, brain = connaissance**
CLAUDE.md pointe. Le brain contient.
Si tu clones le brain sur une nouvelle machine, l'environnement se reconstruit.

---

## Décisions de design importantes

| Décision | Pourquoi |
|----------|----------|
| Optimizers en trio (backend/db/frontend) | Un domaine = un spécialiste. Composables ensemble ("Riri Fifi Loulou") |
| Testing unifié (Jest + Vitest) | Même stratégie, outils proches — split = overhead sans valeur |
| Debug unifié | Méthodologie universelle > spécialisation domaine |
| Orchestrator coordinateur pur | S'il agit, il sort de son rôle et devient imprévisible |
| Scribe en fin de session | Le brain qui dérive = connaissance perdue |
| Mentor 3 modes | Pédagogie adaptative > agent spécialisé par type de question |

---

## Ce que ce système n'est pas

- Un remplacement au travail réel — les agents guident, tu décides et tu fais
- Une garantie de qualité — un agent non testé est un agent théorique
- Figé — chaque review en conditions réelles l'améliore

---

## Boucle d'amélioration

```
Forger → Tester → Capturer (reviews/) → Améliorer (recruiter) → Re-tester
```

Le système s'améliore par l'usage. Pas par la théorie.
