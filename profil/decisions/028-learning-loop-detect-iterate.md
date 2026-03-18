---
scope: kernel
name: ADR-028
title: "Learning loop — detect → collect → propose → approve → update"
status: accepted
date: 2026-03-18
deciders: [<owner>]
---

# ADR-028 — Learning loop : detect → collect → propose → approve → update

## La boucle complète

```
ambient run  →  RETURN collecté  →  pattern-scribe détecte
                                           ↓
                                    pattern nouveau ?
                                     oui ↓      non ↓
                              log pattern    incrément compteur
                                     ↓
                              seuil atteint ?
                                     ↓ oui
                              propose update (ADR / workflow / agent)
                                     ↓
                              humain approve / reject
                                     ↓ approve
                              brain_write() → update
                                     ↓
                              BACT enregistre la progression
```

---

## Ce qui ferme la boucle ouverte

Avant cet ADR :
- `pattern-scribe` détectait → loggait → **s'arrêtait**
- Humain devait lire le log et agir manuellement

Après cet ADR :
- `pattern-scribe` détecte → log → **propose** si seuil atteint
- Humain approuve ou rejette — le brain exécute

---

## Sources d'entrée de la boucle

| Source | Ce qu'elle apporte |
|--------|-------------------|
| `workspace/pattern-log.md` | Patterns inter-sessions détectés |
| `ambient/runs/*.yml` | Run records workflow (ADR-027) |
| BSI claims (fermés) | Historique décisions de session |
| `now.md` chain | Contexte bridge entre sessions |

---

## Seuils de déclenchement

```yaml
thresholds:
  pattern_occurrences: 3      # même pattern 3x → propose correction
  escalate_same_cause: 2      # même ESCALATE 2x → propose règle ambient
  error_same_workflow: 2      # même ERROR 2x → propose fix workflow spec
  bact_milestone: 10          # 10 cycles appris → coach L2 unlock signal
```

---

## Format de proposition

Quand le seuil est atteint, le brain génère une proposition :

```yaml
proposal:
  id: prop-20260318-001
  trigger: pattern_occurrences
  pattern: "deploy instance-0x échoue si port 443 pas encore ouvert"
  observed: 3x dans runs/deploy-batch-*.yml
  proposes:
    type: workflow_update
    file: workflows/deploy-batch.yml
    change: "ajouter step check-port-443 avant spawn deploy"
  requires: human_approval
  expires_at: ISO8601  # 72h — si pas de réponse → archive
```

---

## Approbation humaine

```
brain-ui    →  panneau "Proposals"  →  approve / reject / modify
Telegram    →  notification résumée →  /approve prop-001 | /reject prop-001
Claude      →  en début de session  →  "1 proposition en attente — tu veux la voir ?"
```

**Règle** : jamais d'update automatique sans approbation.
L'autonomie croît par accumulation de confiance, pas par défaut.

---

## Connexion BACT

Chaque approbation humaine = un cycle d'apprentissage enregistré dans BACT :

```yaml
bact_entry:
  date: ISO8601
  type: workflow_improvement
  pattern: "..."
  approved_by: human
  applied_to: workflows/deploy-batch.yml
  outcome: null  # rempli après le prochain run
```

Après le prochain run :
```yaml
  outcome: success  # le fix a fonctionné
  # → confiance += 1 sur ce type de décision
```

Accumulation de confiance → certains patterns futurs peuvent passer
en auto-approve si confiance suffisante + pattern identique déjà résolu.

---

## La vision long terme capturée

> Chaque run = un exemple d'entraînement.
> Chaque ESCALATE résolu = une règle apprise.
> Chaque approbation = de la confiance accumulée dans BACT.
>
> Sur le long terme : le brain sait que tu as un VPS, qu'il tourne sur tel port,
> que tel pattern d'erreur se résout comme ça. Les ESCALATEs deviennent rares.
> Tu restes décisionnaire final — mais uniquement sur ce qui est vraiment nouveau.

---

## Bootstrap protocol — comment on arrive à l'autonomie

L'autonomie ne se déclare pas. Elle se gagne par itérations supervisées.

```
Itération 1 — ensemble
  Humain + brain côte à côte sur le premier run.
  Humain repère les gaps, le scope drift, les décisions mal calibrées.
  Brain apprend la tolérance exacte — pas plus, pas moins.

Itération 2 — supervisée
  Brain exécute. Humain observe sans intervenir sauf ESCALATE réel.
  Validation que les corrections de l'itération 1 ont tenu.
  Ajustements fins si nécessaire.

Itération 3+ — autonome
  Brain tourne seul. Humain = décisionnaire final uniquement.
  Les ESCALATEs sont rares — le brain a vu le pattern avant.
```

**Règle de passage** : on ne passe à l'itération suivante que si l'itération courante
n'a produit aucun scope drift non détecté. Un drift non détecté = retour à l'itération 1.

**Ce que "ensemble" signifie en pratique** :
- Humain lit les run records après chaque step
- Signale les écarts de scope immédiatement
- Approuve ou rejette chaque proposition générée
- Le brain ne "suppose" pas — il demande si ambigu

**Ce qui change à l'itération 3** :
- Le brain a un historique suffisant sur ce workflow précis
- Les propositions de ce type passent en auto-approve (confiance BACT)
- L'humain reçoit un résumé, pas une demande d'approbation step-by-step

---

## Ce que cet ADR ne définit pas

- Stockage BACT (format base, vecteurs, ou simple YAML) → à décider à l'implémentation
- Interface Cosmos "Proposals panel" → produit
- Seuil d'auto-approve (confiance suffisante) → à calibrer empiriquement

---

## Changelog

| Date | Note |
|------|------|
| 2026-03-18 | Création — boucle complète detect→propose→approve→update, seuils, format proposition, connexion BACT, vision long terme gravée |
