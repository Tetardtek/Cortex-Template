# Scribe Pattern — Idéologie du brain

> **Type :** Invariant
> Décision architecturale — session 2026-03-13

---

## Principe fondateur

**Les agents métier produisent. Les scribes persistent.**

Aucun agent métier n'écrit dans le brain, le toolkit ou la progression.
Il signale. Le scribe compétent écrit.

Séparation nette des responsabilités :
- Agent métier : expertise domaine, diagnostic, recommandations
- Scribe : réception du signal, formatage, écriture dans le bon endroit

---

## Les trois domaines de connaissance durable

| Scribe | Reçoit de | Écrit dans | Ce qu'il persiste |
|--------|-----------|------------|-------------------|
| `scribe` | Session entière | `brain/` | État projets, décisions infra, focus |
| `toolkit-scribe` | Agents métier | `toolkit/` | Patterns validés en prod |
| `coach-scribe` | `coach` | `progression/` | Journal, skills, milestones |

---

## Comment un agent signale à un scribe

Signal minimal attendu en fin de session :

```
→ toolkit-scribe : [pattern] pm2 cluster mode — validé prod Super-OAuth 2026-03-13
→ coach-scribe   : [bilan] pattern détecté — X compris, Y à revoir
→ scribe         : [état] focus.md — SuperOAuth backend online, prochaine étape Apache
```

Le scribe ne reformule pas. Il structure et écrit tel quel.

---

## Règles absolues du Scribe Pattern

1. **Un scribe ne juge pas.** Il ne décide pas si un pattern est bon — l'agent métier a déjà validé.
2. **Un scribe ne commente pas.** Il ne coache pas, n'optimise pas, n'améliore pas.
3. **Un scribe ne devine pas.** Signal ambigu → demande clarification avant d'écrire.
4. **Un scribe ne modifie pas sans diff.** Entrée existante → proposer le diff explicite avant overwrite.
5. **Un scribe sur domaine sensible (sécu, infra) signale avant de committer.**

---

## Pourquoi cette séparation ?

Sans elle, les agents accumulent des responsabilités secondaires (écrire, formater, trouver le bon fichier) qui polluent leur rôle principal et créent des incohérences entre agents.

Le toolkit et la progression sont des **ancres de confiance** — un agent chargé incorrect propage l'erreur à toute la session. Les scribes sont les seuls à y écrire, ce qui centralise le risque et simplifie l'audit.

---

## Extension future

Si un nouveau domaine de connaissance durable émerge → créer un scribe dédié, pas étendre un agent existant.

Candidats possibles (non créés) :
- `security-ledger-scribe` — décisions de sécurité prises, patterns validés (ex: "CSRF token rotation — adopté")
- Seulement si le volume justifie un scribe distinct du toolkit

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-13 | Création — émergé de la session forge toolkit-scribe + coach-scribe |
