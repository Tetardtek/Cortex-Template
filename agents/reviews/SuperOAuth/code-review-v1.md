# Review agent : code-review — v1

> ⚠️ Ce fichier concerne la QUALITÉ DE L'AGENT, pas les tests du code applicatif.
> Tests code → voir `projet/src/__tests__/` et Jest/Vitest.

---

## Contexte de la review

| Info | Valeur |
|------|--------|
| Agent reviewé | `code-review` |
| Version | v1 |
| Date | 2026-03-12 |
| Projet testé | Super-OAuth |
| Cas soumis | Review de `src/application/use-cases/refresh-token.use-case.ts` — use case DDD, logique fingerprint + propagation session (code écrit par l'agent `security` lors de la session précédente) |

---

## Output résumé

- 🔴 Bypass fingerprint si dto.deviceFingerprint absent — `if (session.fp && dto.fp)` skippe silencieusement si le client n'envoie pas le champ
- 🔴 Migration silencieuse du fingerprint après mismatch — attaquant peut faire "migrer" le fingerprint vers son device en quelques refreshes
- 🟡 Non-atomicité delete+create — si create échoue, l'utilisateur est déconnecté sans raison
- 🟡 Incohérence commit "enforce" vs soft check effectif
- 🟢 Erreurs génériques `new Error(...)` → classes domaine custom recommandées

---

## Output brut de l'agent

```
Agent code-review chargé. Le fichier fait 94 lignes → rapport structuré.

---
Code Review — refresh-token.use-case.ts

---
🔴 Critique

[L.34-43] Bypass complet du fingerprint si dto.deviceFingerprint est absent

if (session.deviceFingerprint && dto.deviceFingerprint) {

La condition requiert les deux valeurs. Si un client envoie une requête sans deviceFingerprint (champ absent ou null), la vérification est
silencieusement skippée — même si la session a un fingerprint stocké. Un attaquant avec un refresh token volé n'a qu'à ne pas envoyer ce champ pour
passer sans log, sans rejet.

Comportement attendu : si session.deviceFingerprint existe, le client doit en fournir un. L'absence devrait être traitée comme une anomalie, pas comme
une dispense.

// Version corrigée (même en soft check)
if (session.deviceFingerprint) {
  if (!dto.deviceFingerprint || session.deviceFingerprint !== dto.deviceFingerprint) {
    logger.warn('Device fingerprint mismatch or missing on token refresh', { ... });
    // throw ici quand tu passes en hard reject
  }
}

---
[L.68 + L.34-43] Migration silencieuse du fingerprint après mismatch

const fingerprint = dto.deviceFingerprint ?? session.deviceFingerprint;
await this.sessionRepository.create(user.id, newRefreshToken, expiresAt, {
  ...(fingerprint && { deviceFingerprint: fingerprint }),
});

Si un mismatch est détecté au soft check (L.35), on continue quand même ET on stocke dto.deviceFingerprint comme nouveau fingerprint de la session. En
quelques refreshes successifs, un attaquant peut faire "migrer" le fingerprint vers son propre device — la session lui appartient progressivement, sans
aucun rejet.

La correction : en cas de mismatch (même soft check), conserver le fingerprint de la session originale, ne jamais le remplacer par la valeur entrante
suspecte.

// En cas de mismatch : on garde l'original
const fingerprint = (session.deviceFingerprint && dto.deviceFingerprint &&
  session.deviceFingerprint !== dto.deviceFingerprint)
    ? session.deviceFingerprint   // conserver l'original malgré le mismatch
    : (dto.deviceFingerprint ?? session.deviceFingerprint);

---
🟡 Warning

[L.65-71] Non-atomicité delete + create — risque de déconnexion silencieuse

await this.sessionRepository.deleteByRefreshToken(dto.refreshToken); // L.65
// ... calcul ...
await this.sessionRepository.create(...);                             // L.69

Si create échoue (DB timeout, contrainte, etc.), le vieux token est déjà supprimé. L'utilisateur se retrouve sans session valide et doit se reconnecter
— sans raison visible de son côté.

Pourquoi c'est important : en token rotation, la fenêtre entre delete et create est un point de défaillance classique. La solution robuste est une
transaction DB encapsulant les deux opérations. Si le repository ne supporte pas les transactions, inverser l'ordre (create d'abord, delete ensuite)
réduit le risque : en cas d'échec du delete, les deux tokens coexistent temporairement, mais l'utilisateur n'est pas déconnecté. Niveau de confiance:
élevé sur le risque, moyen sur la bonne approche selon ton schéma DB.

---
[L.34, L.62] Commit message incohérent avec la logique

Le dernier commit s'intitule feat(auth): enforce device fingerprint validation on token refresh. Le mot "enforce" implique un hard reject — mais la
logique est un soft check avec un TODO. Ce n'est pas un bug de code, mais une dette de cohérence : soit le commit message est trompeur, soit la feature
est incomplète. À clarifier avant merge ou review PR.

---
🟢 Suggestion

[L.21, L.28, L.52, L.57] Erreurs génériques → erreurs domaine custom

throw new Error('Invalid refresh token');
throw new Error('Refresh token has expired');
throw new Error('User not found');
throw new Error('Account is deactivated');

new Error(...) générique oblige la couche infra (controller/middleware) à parser le message string pour mapper le bon code HTTP — fragile et couplé. En
DDD, on préfère des classes d'erreur domaine :

// domain/errors/auth.errors.ts
export class InvalidRefreshTokenError extends Error { ... }
export class ExpiredRefreshTokenError extends Error { ... }

Le controller peut alors faire un instanceof propre pour renvoyer 401, 403, etc. C'est un refacto mineur, mais il améliore la lisibilité de la couche
HTTP et évite les bugs silencieux si un message change.
```

---

## Évaluation

### ✅ Ce qui a bien fonctionné
- A annoncé le format choisi dès le début ("94 lignes → rapport structuré") — adaptatif
- A trouvé 2 failles critiques que l'agent `security` avait manquées dans le code qu'il venait lui-même d'écrire — cross-validation utile
- Explication du *pourquoi* pour chaque finding : vecteur d'attaque concret, pas juste "c'est mal"
- Anti-hallucination active : "Niveau de confiance: élevé sur le risque, moyen sur la bonne approche selon ton schéma DB"
- Tableau de synthèse en fin de rapport — lisibilité
- A demandé avant d'appliquer les corrections ("Veux-tu que j'applique directement ?")
- A noté l'incohérence commit "enforce" vs soft check — dette de cohérence réelle

### ❌ Ce qui manquait
- N'a pas suggéré d'invoquer l'agent `testing` après les corrections (même gap que `security`)
- N'a pas suggéré l'agent `security` pour les 2 findings 🔴 — ils sont dans le domaine partagé qualité/sécu, mais une mention explicite de coordination aurait été propre
- La suggestion domain errors (🟢) aurait pu pointer vers l'agent `refacto` pour le chantier complet

### ⚠️ Anti-hallucination respectée ?
- [x] A dit "Information manquante" quand nécessaire — a précisé le niveau de confiance moyen sur l'approche transaction
- [x] N'a pas inventé de commandes/chemins/métriques — tout ancré sur des numéros de ligne réels
- [x] Niveau de confiance explicite si incertain — présent sur le finding non-atomicité

### 📐 Périmètre respecté ?
- [x] Format adapté (rapport structuré pour 94 lignes) ✅
- [x] A expliqué le *pourquoi* de chaque finding ✅
- [x] N'a pas débordé sur les perfs ou l'infra
- [x] A demandé avant d'appliquer les corrections

---

## Gaps identifiés → à corriger dans l'agent

| Gap | Correction proposée | Priorité |
|-----|--------------------|----|
| N'a pas suggéré `testing` après les corrections | Ajouter dans périmètre : "après tout fix, suggérer `testing`" | moyenne |
| N'a pas suggéré `security` pour les findings critiques | Ajouter : "si finding 🔴 avec vecteur d'attaque → mentionner coordination avec `security`" | basse |
| N'a pas pointé `refacto` pour la suggestion domaine errors | Ajouter : "pour suggestions de refacto structurel → mentionner `refacto`" | basse |

---

## Action

- [x] Review complète
- [x] Gaps reportés dans `agents/code-review.md` changelog
- [x] Règles ajoutées directement dans Périmètre (Recruiter non nécessaire — corrections simples)
- [ ] v2 planifiée (prochain audit réel)
