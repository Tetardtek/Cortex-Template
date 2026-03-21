# Le brain en 30 secondes

## Pourquoi un brain plutot que Claude seul ?

Claude est puissant. Mais a chaque session, il repart de zero. Tu re-expliques ton projet, ta stack, tes conventions. Tu repetes les memes consignes. Tu perds du contexte a chaque compaction.

Le brain resout ca : **un systeme de specialistes IA qui persistent entre sessions.** Chaque specialiste (agent) fait une chose bien — debugger, reviewer du code, deployer, ecrire des tests. Ils connaissent tes regles, ta stack, tes decisions passees. Tu n'en charges jamais plus de 5 a la fois — le brain sait lesquels activer selon ce que tu fais.

Tu forkes le brain, tu codes. Les agents se chargent automatiquement. Ton contexte survit aux sessions.

---

## Les 4 tiers

> 🟢 **free — Tu forkes, ca marche**
>
> **17 agents + 9 systeme. 6 sessions.** Pas de cle API, pas de config.
>
> Debug, brainstorm, scribes automatiques, protection secrets, creation d'agents custom. 3 agents d'onboarding (guide, catalogist, pathfinder) pour t'orienter. Le coach observe en arriere-plan.

> 🔵 **featured — Le brain te connait**
>
> **21 agents + systeme. 8 sessions.** Le coach se reveille.
>
> Bilans de session, objectifs concrets, progression tracee. Le brain se souvient de tes acquis entre sessions grace a la distillation RAG.

> 🟠 **pro — L'atelier complet**
>
> **42 agents + systeme. 14 sessions.** Tu ship en prod.
>
> Code review (7 priorites), audit securite (8 priorites OWASP), tests automatises, 3 optimiseurs perf, deploy VPS + CI/CD + SSL, sessions urgence et infra.

> 🟣 **full — Ton brain, tes regles**
>
> **81 agents (tous). 15 sessions.** Tu es owner.
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

**Premier fork ? 3 agents t'orientent.**
- `guide` — presente le systeme, repond a "c'est quoi ce truc ?"
- `catalogist` — explore ce qui est disponible (agents, tiers, features)
- `pathfinder` — t'oriente vers la bonne session selon ce que tu veux faire

---

## Explore les agents par famille

**Code & Qualite** — review, securite, tests, refacto, 3 optimiseurs perf

**Infra & Deploy** — VPS, pipelines CI/CD, monitoring, process manager, mail

**Brain & Systeme** — coach, scribes, orchestration, protection, kernel

→ Chaque famille est accessible dans la sidebar.

---

## Pour aller plus loin

**L'histoire du projet** — [story.tetardtek.com](https://story.tetardtek.com) raconte le pourquoi, le parcours, les decisions. Si tu veux comprendre la vision avant de fork.

---

## Nouveautes

| Date | Quoi de neuf |
|------|-------------|
| 2026-03-21 | 3 agents onboarding (guide, catalogist, pathfinder) — le brain accueille les nouveaux |
| 2026-03-21 | Docs live — git pull = docs a jour, zero rebuild |
| 2026-03-21 | VPS scission — vitrine template publique separee du brain prod |
| 2026-03-20 | Agents 87% plus legers au boot |
| 2026-03-20 | Coach adaptatif — 5 comportements selon la session |
| 2026-03-20 | Fermeture fiable — sequence deterministe |
| 2026-03-18 | Auto-mefiance — le brain se verifie quand il s'edite |
| 2026-03-17 | Supervision avancee — hypervisor + circuit breaker |
