# protocol.md — Contexte mode RFC

> **Type :** Contexte — propriétaire : `metier/protocol` (mail, security)
> Rédigé : 2026-03-14
> Résout : "agents métier qui opèrent sur des RFC dérivent vers des approximations — mode protocol impose la rigueur"

---

## Problème résolu

Un agent `metier` standard peut répondre avec un niveau de confiance moyen sur un sujet RFC. En mail ou OAuth, une approximation = prod cassé ou faille exploitable. Ce contexte active des règles de comportement plus strictes dès qu'un agent opère sur un protocole formel.

---

## Règles mode protocol

### Avant toute affirmation technique

1. **Vérifier la source** — citer la RFC ou la spec formelle (ex: "RFC 6376 §3.5")
2. **Si incertain** → dire explicitement "je dois vérifier" plutôt qu'approximer
3. **Niveau de confiance affiché** sur chaque décision : `[confiance: élevée / RFC 5321 §4.1]`

### Déviation du standard

Toute déviation d'une RFC documentée explicitement :
```
⚠️ Déviation RFC XXXX §X.X — justification : <raison>
   Risque : <impact si la déviation pose problème>
   Alternative conforme : <option standard>
```

### Anti-hallucination renforcé

- Jamais inventer un flag CLI, un header SMTP, un paramètre OAuth — vérifier
- Si la RFC évolue (ex : TLS 1.3 remplace TLS 1.2) → citer la version active
- "Ça devrait marcher" n'est pas acceptable — "RFC X dit Y, donc Z"

---

## Références RFC par domaine

### Mail
| Protocole | RFC | Résumé |
|-----------|-----|--------|
| SMTP | RFC 5321 | Protocole de transfert |
| Message format | RFC 5322 | En-têtes, corps |
| DKIM | RFC 6376 | Signature cryptographique |
| DMARC | RFC 7489 | Politique d'alignement SPF/DKIM |
| SPF | RFC 7208 | Validation IP expéditeur |
| IMAP | RFC 9051 | Protocole accès boîte |

### Auth / Sécurité
| Protocole | RFC | Résumé |
|-----------|-----|--------|
| OAuth 2.0 | RFC 6749 | Délégation d'autorisation |
| JWT | RFC 7519 | JSON Web Token |
| PKCE | RFC 7636 | Extension OAuth pour clients publics |
| TLS 1.3 | RFC 8446 | Transport sécurisé (version active) |

---

## Trigger de chargement

```
Propriétaire : mail, security
Trigger      : dès que le domaine mail ou OAuth/JWT est détecté dans la session
Section      : Sources au démarrage (conditionnel — si type metier/protocol confirmé)
```

---

## Maintenance

```
Propriétaire : agent-review (audits), mail, security
Mise à jour  : quand une RFC est obsolète ou qu'un nouveau protocole est ajouté au brain
Jamais modifié par : agents non-protocol
```

---

## Cycle de vie

| État | Condition | Action |
|------|-----------|--------|
| **Actif** | Sessions mail ou OAuth actives | Mis à jour si RFC change |
| **Stable** | Peu de sessions protocol | Consulté, rarement modifié |
| **Archivé** | N/A | Non applicable — les RFC ne disparaissent pas |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-14 | Création — règles RFC, anti-hallucination renforcé, références mail + auth |
