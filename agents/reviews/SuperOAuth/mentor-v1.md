# Review agent : mentor — v1

> ⚠️ Ce fichier concerne la QUALITÉ DE L'AGENT, pas les tests du code applicatif.

---

## Contexte de la review

| Info | Valeur |
|------|--------|
| Agent reviewé | `mentor` |
| Version | v1 |
| Date | 2026-03-12 |
| Projet testé | Super-OAuth |
| Cas soumis | L'orchestrator vient de proposer un plan (security → code-review → testing → debug → ci-cd → déploiement). Expliquer pourquoi security passe avant code-review. Vérifier la compréhension avant de continuer. |

---

## Output brut de l'agent

```
Agent mentor chargé. Mode EXPLAIN activé.

Pourquoi security passe avant code-review ?

La décision repose sur un principe simple : tu ne peux pas bien reviewer du code dont tu ignores les failles.

Le code-review sans security audit, c'est incomplet.
Un reviewer qui lit ton code va chercher : la lisibilité, les patterns, la structure, les bugs évidents.
Mais il ne va pas systématiquement chercher : les JWT mal validés, les secrets hardcodés, les endpoints
non authentifiés, les injections. Ce sont des catégories différentes de problèmes. Le reviewer a besoin
de savoir où sont les zones à risque pour les inspecter avec la bonne attention.

Concrètement sur Super-OAuth.
Super-OAuth gère de l'authentification — c'est exactement le domaine où une faille non détectée en amont
peut passer sous le radar d'une review classique. Si l'agent security identifie d'abord "ce middleware ne
vérifie pas l'expiry du token dans ce cas-là", le reviewer sait qu'il doit inspecter cette zone en profondeur.
Sans ça, il risque de valider le code structurellement correct mais fonctionnellement vulnérable.

L'analogie construction : avant de faire inspecter la qualité d'un bâtiment (code-review), tu fais d'abord
l'étude de sol et les normes parasismiques (security). Si tu découvres après la review que les fondations ne
tiennent pas, tu refais tout.

Résumé de la logique de l'ordre :
security     → identifier les risques réels
code-review  → valider le code en ayant ces risques en tête
testing      → vérifier que les corrections tiennent
debug        → traiter ce que les tests révèlent
ci-cd        → automatiser un pipeline sur du code sain
déploiement  → mettre en prod ce qui est vérifié à chaque couche

Chaque étape dépend de la précédente. C'est un entonnoir de confiance.

Question pour vérifier ta compréhension :
Si l'ordre était inversé — code-review d'abord, security ensuite — qu'est-ce qui pourrait concrètement
mal se passer sur un projet comme Super-OAuth ?

---

[Réponse utilisateur]
Si on fait code-review d'abord, on risque de valider du code qui a des failles, et après le security audit
il faut tout revoir. C'est du travail en double.

---

C'est exact. Et tu peux aller un cran plus loin : ce n'est pas juste du travail en double, c'est
potentiellement du travail contradictoire.

La review a validé une implémentation. L'audit security dit ensuite que cette implémentation est vulnérable.
Tu te retrouves avec deux verdicts opposés sur le même code — et tu dois décider lequel prime. Ça crée de
la confusion et parfois des résistances ("mais le reviewer a dit que c'était bon...").

Ta compréhension est correcte. Le principe sous-jacent s'appelle le shift-left en sécurité : détecter les
problèmes le plus tôt possible dans le pipeline, parce que le coût d'une correction augmente à chaque étape
franchie.

Tu as bien saisi la logique de l'ordre. On peut avancer.

Prochaine action concrète : lancer l'agent security sur Super-OAuth, ou tu veux d'abord un point sur ce
que cet agent va chercher spécifiquement ?
```

---

## Évaluation

### ✅ Ce qui a bien fonctionné
- Mode EXPLAIN activé correctement dès le départ
- Explication structurée : principe → concret Super-OAuth → analogie → tableau résumé
- Analogie construction pertinente et mémorisable
- Shift-left introduit avec définition inline — calibrage correct pour un junior
- A validé la réponse sans sur-féliciter ("c'est exact")
- A enrichi la réponse partielle avec le vrai point manquant (verdicts contradictoires) — pédagogiquement solide
- S'est arrêté à 1 question de quiz (périmètre : max 2) ✅
- Pas de condescendance dans la correction ✅

### ❌ Ce qui manquait
- La question finale "Prochaine action concrète : lancer l'agent security..." déborde sur le territoire de l'orchestrator. Mentor valide la compréhension — il ne dirige pas le workflow. "On peut avancer" suffit. Proposer la prochaine action = scope drift.

### ⚠️ Anti-hallucination respectée ?
- [x] Shift-left : concept réel, bien utilisé ✅
- [x] Ancré dans Super-OAuth (JWT, middleware, token expiry) ✅
- [x] N'a pas inventé de détails techniques non vérifiés ✅

### 📐 Périmètre respecté ?
- [x] Mode EXPLAIN → QUIZ enchaîné correctement ✅
- [x] Max 2 questions respecté (1 seule posée) ✅
- [x] Correction sans condescendance ✅
- [ ] Proposition de prochaine action → scope drift vers orchestrator ❌

---

## Gaps identifiés → à corriger dans l'agent

| Gap | Correction proposée | Priorité |
|-----|--------------------|----------|
| Proposition de prochaine action en fin de session | Ajouter règle : mentor ne propose pas la prochaine action technique — il ferme avec "tu as bien saisi, on peut avancer" et laisse l'utilisateur décider. La direction du workflow appartient à l'orchestrator ou à l'utilisateur. | haute |

---

## Action

- [x] Review complète
- [x] Gaps reportés dans `agents/mentor.md` changelog
- [x] Recruiter invoqué pour améliorer l'agent
- [ ] v2 planifiée
