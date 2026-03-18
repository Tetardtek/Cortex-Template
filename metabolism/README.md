---
name: metabolism
type: layer
context_tier: warm
---

# Metabolism — Couche de santé session

> Métriques de consommation cognitive par session.
> Analogue biologique : comment le brain consomme des ressources pour fonctionner.

---

## Ce que le metabolism mesure

Par session :
- **Tokens consommés** — coût context réel
- **Pic de context** — saturation atteinte (%)
- **Agents chargés** — liste + coût estimé par agent
- **Health score** — indicateur composite de santé
- **Durée / commits / todos fermés** — productivité

---

## Composants

| Fichier | Rôle |
|---------|------|
| `profil/metabolism-spec.md` | Schéma complet des métriques + formules |
| `agents/metabolism-scribe.md` | Agent qui capture et persiste les métriques |
| `workspace/metabolism/` | Données par session (générées par metabolism-scribe) |

---

## Ce que le metabolism N'est PAS

- Pas la feature gate (c'est `brain-compose.yml` + `key-guardian`)
- Pas l'état des sessions actives (c'est `workspace/live-states.md`)
- Pas l'historique BSI (c'est `claims/*.yml`)

---

## Lecture rapide

```
agents/metabolism-scribe.md   → comment capturer
profil/metabolism-spec.md     → schéma complet des champs
```
