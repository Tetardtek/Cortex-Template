# Le brain en 30 secondes

Un brain, c'est un systeme de **specialistes IA** qui travaillent ensemble. Chaque specialiste (agent) fait une chose bien : debugger, reviewer du code, deployer, ecrire des tests. Tu n'en charges jamais plus de 5 a la fois — le brain sait lesquels activer selon ce que tu fais.

Tu forkes le brain, tu codes. Les agents se chargent automatiquement.

---

## Les 4 tiers

> 🟢 **free — Tu forkes, ca marche**
>
> **14 agents + 8 systeme. 6 sessions.** Pas de cle API, pas de config.
>
> Debug, brainstorm, scribes automatiques, protection secrets, creation d'agents custom. Le coach observe en arriere-plan.

> 🔵 **featured — Le brain te connait**
>
> **18 agents + systeme. 8 sessions.** Le coach se reveille.
>
> Bilans de session, objectifs concrets, progression tracee. Le brain se souvient de tes acquis entre sessions grace a la distillation RAG.

> 🟠 **pro — L'atelier complet**
>
> **40 agents + systeme. 12 sessions.** Tu ship en prod.
>
> Code review (7 priorites), audit securite (8 priorites OWASP), tests automatises, 3 optimiseurs perf, deploy VPS + CI/CD + SSL, sessions urgence et infra.

> 🟣 **full — Ton brain, tes regles**
>
> **75 agents (tous). 15 sessions.** Tu es owner.
>
> Modification du kernel, copilotage long (mode pilote), supervision multi-phase (hypervisor), coach proactif qui anticipe.

---

## Ce qui change quand tu montes

> 🟢 → 🔵 **free vers featured**
>
> Le coach passe de spectateur a mentor. Il fait un bilan a chaque session, fixe des objectifs, et trace ta progression. Le brain apprend de toi — il se souvient entre sessions.

> 🔵 → 🟠 **featured vers pro**
>
> Tu recois une equipe complete : review code, audit securite, tests, refacto, 3 optimiseurs perf, deploy prod, monitoring, pipelines CI/CD. Plus besoin d'improviser — le brain fait le travail metier.

> 🟠 → 🟣 **pro vers full**
>
> Tu deviens owner. Tu modifies le brain lui-meme (kernel, agents, profil). Sessions longues en copilote proactif. Supervision multi-phase avec circuit breaker.

---

## Comment ca marche en pratique

**Les agents se chargent tout seuls.** Tu parles de "bug" → `debug` arrive. Tu dis "deploy" → `vps` + `ci-cd` se chargent. Tu peux aussi les appeler :

```
Charge l'agent testing
Charge les agents security et code-review
```

**Ils se delegent entre eux.** Chaque agent connait ses limites :
- `debug` detecte un probleme infra → passe a `vps`
- `code-review` trouve une faille → passe a `security`
- `optimizer-db` voit un probleme Node.js → passe a `optimizer-backend`

**Ils ne chargent que l'essentiel.** Un agent de 200 lignes → ~25 lignes au boot. Le reste se charge quand tu en as besoin.

---

## Explore les agents par famille

**Code & Qualite** — review, securite, tests, refacto, 3 optimiseurs perf

**Infra & Deploy** — VPS, pipelines CI/CD, monitoring, process manager, mail

**Brain & Systeme** — coach, scribes, orchestration, protection, kernel

→ Chaque famille est accessible dans la sidebar.

---

## Nouveautes

| Date | Quoi de neuf |
|------|-------------|
| 2026-03-20 | Agents 87% plus legers au boot |
| 2026-03-20 | Coach adaptatif — 5 comportements selon la session |
| 2026-03-20 | Fermeture fiable — sequence deterministe |
| 2026-03-18 | Auto-mefiance — le brain se verifie quand il s'edite |
| 2026-03-17 | Supervision avancee — hypervisor + circuit breaker |
