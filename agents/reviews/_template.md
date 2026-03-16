# Review agent : <NOM-AGENT> — v<N>

> ⚠️ Ce fichier concerne la QUALITÉ DE L'AGENT, pas les tests du code applicatif.
> Tests code → voir `projet/src/__tests__/` et Jest/Vitest.

---

## Contexte de la review

| Info | Valeur |
|------|--------|
| Agent reviewé | `<nom-agent>` |
| Version | v<N> |
| Date | <date> |
| Projet testé | <projet> |
| Cas soumis | <description courte du problème soumis à l'agent> |

---

## Output brut de l'agent

```
[Coller ici l'output complet de l'agent]
```

---

## Évaluation

### ✅ Ce qui a bien fonctionné
-

### ❌ Ce qui manquait ou était incorrect
-

### ⚠️ Anti-hallucination respectée ?
- [ ] A dit "Information manquante" quand nécessaire
- [ ] N'a pas inventé de commandes/chemins/métriques
- [ ] Niveau de confiance explicite si incertain

### 📐 Périmètre respecté ?
- [ ] N'a pas débordé sur d'autres domaines
- [ ] A bien délégué ce qui ne le concernait pas

---

## Gaps identifiés → à corriger dans l'agent

| Gap | Correction proposée | Priorité |
|-----|--------------------|----|
| | | haute/moyenne/basse |

---

## Action

- [ ] Gaps reportés dans `agents/<nom-agent>.md` changelog
- [ ] Recruiter invoqué pour améliorer l'agent
- [ ] v<N+1> planifiée
