# Feedback tech-lead — sprint <NOM>

> Écrit par : `integrator`
> Lu par : `tech-lead` au boot du sprint suivant
> Alimente : KPIs Tier 2 (précision contention, blocage pertinent, couverture risques, overflow accuracy)

---

## Contention map

| Fichier | Prédit par tech-lead | Réellement partagé |
|---------|---------------------|-------------------|
| `<fichier>` | ✅ / ❌ | ✅ / ❌ |

```
Précision : X prédits / Y réels → <Z>%
Manqués   : <fichiers non prédits découverts au merge>
```

---

## Gates émis

| Type | Émis | Justifiés | Faux positifs |
|------|------|-----------|---------------|
| STOP ❌ | N | N | N |
| ⚠️  | N | N | ignorés : N |

---

## Risques

```
Prédits en gate  : <liste>
Découverts après : <liste non prédits — apparus en intégration>
Couverture       : X prédits / Y total → <Z>%
```

---

## Overflows

| Overflow accordé | Légitime a posteriori |
|------------------|-----------------------|
| `<agent> → <fichier>` | ✅ / ❌ — <raison> |

```
Accuracy : X légitimes / Y accordés → <Z>%
```

---

## Ordre commit

```
Recommandé : <séquence tech-lead>
Réel       : <séquence exécutée>
Conflits   : <N>
```

---

## Verdict global

```
Patch tech-lead requis : oui / non
Section(s) à patcher   : <contention logic | gate calibration | risque coverage | overflow criteria>
```
