# Agents Code & Qualite

> Les specialistes qui analysent, reviewent, testent et optimisent ton code.

---

## Review & Securite

### code-review

> 🟠 **pro**

Analyse tout code soumis selon 7 priorites, de la plus critique a la moins urgente :

1. **Securite** — injections, secrets exposes, tokens mal geres
2. **Edge cases** — entrees inattendues, etats limites
3. **Performance** — boucles inutiles, N+1, fuites memoire
4. **Async & erreurs** — promesses, try/catch, rejets non geres
5. **Typage** — pas de `any` sauvage
6. **Clean code** — lisible, maintenable
7. **Obsolescence** — patterns deprecies

Format adaptatif : inline sur un snippet court, rapport structure sur un fichier long.

Si un finding est critique → delegue a `security`. Apres review → suggere `testing`.

---

### security

> 🟠 **pro**

Audite la securite applicative selon 8 priorites :

1. Secrets exposes
2. Auth & tokens (JWT, OAuth2, refresh)
3. Injections (SQL, shell)
4. CSRF / CORS
5. XSS
6. Rate limiting
7. Headers securite
8. Exposition de donnees

Couvre la couche applicative. Pour la couche infra (Apache, SSL, ports) → delegue a `vps`.

---

## Tests

### testing

> 🟠 **pro**

Ecrit les tests et definit la strategie de coverage. Adaptatif :

- **Nouveau code** → TDD : tests d'abord, implementation ensuite
- **Code existant non couvert** → Retroactif : tests sur le comportement constate
- **Refacto prevue** → TDD : les tests guident la refacto

Strategie par couche : tests unitaires purs sur le domaine, mocks sur l'application, integration vraie sur l'infra et les routes.

---

### refacto

> 🟠 **pro**

Restructure le code sans perdre une seule ligne de logique metier. Methode en 5 etapes :

```
1. DIAGNOSTIC   — identifier le probleme
2. PLAN         — lister les etapes (moins risquee → plus risquee)
3. VALIDATION   — confirmer avec toi avant d'agir
4. EXECUTION    — une etape a la fois, tests verts a chaque fois
5. VERIFICATION — comportement identique avant/apres
```

3 niveaux de risque : code local (faible) → module (moyen) → architecture (eleve).

Pas de tests existants ? → `testing` les ecrit avant la refacto.

---

## Performance — le trio

> 🟠 **pro** — les 3 agents travaillent en trio ou separement

### optimizer-backend

Perf Node.js — detecte les `await` dans les `forEach`, les fuites memoire, les boucles qui bloquent l'event loop. Suggere `Promise.all`, streams, workers.

### optimizer-db

Perf MySQL — detecte les N+1 (TypeORM), les index manquants, les requetes lentes. Utilise `EXPLAIN` et `slow_query_log`.

### optimizer-frontend

Perf React — detecte les re-renders inutiles, les imports lourds, le lazy loading manquant. Utilise React DevTools Profiler et bundle analyzer.

**Invoquer les 3** pour un audit perf full-stack.

---

## Qui delegue a qui

- `code-review` → `security` (faille trouvee) · `testing` (couvrir le fix) · `refacto` (structure)
- `security` → `vps` (infra) · `ci-cd` (secrets pipeline)
- `testing` → `security` (tests auth) · `code-review` (review des tests)
- `refacto` → `testing` (tests avant refacto) · `debug` (bugs trouves)
- `optimizer-backend` → `optimizer-db` (requetes) · `code-review` (qualite)
- `optimizer-db` → `optimizer-backend` (applicatif) · `vps` (config serveur)
- `optimizer-frontend` → `ci-cd` (config build)
