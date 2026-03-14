# metabolism-spec.md — Schéma des métriques de santé session

> Dernière mise à jour : 2026-03-14
> Type : Référence
> Géré par : `metabolism-scribe`

---

## Schéma d'une entrée de session

```
session_id        : sess-YYYYMMDD-HHMM-<slug>
date              : YYYY-MM-DD
type              : build-brain | use-brain | auto
mode              : prod | dev | sprint | debug | coach | brainstorm | ...
tokens_used       : <nombre — estimé depuis /context ou fourni manuellement>
context_peak_pct  : <pic d'utilisation du context — ex: 87>
context_at_close  : <context au moment du close — ex: 31>
duration_min      : <durée en minutes>
commits           : <nombre de commits produits>
todos_closed      : <todos cochés ✅ pendant la session>
saturation_flag   : true | false
health_score      : <calculé — voir formule>
agents_loaded     : <liste des agents invoqués/chargés pendant la session>
tokens_par_agent  : <estimation tokens par agent — voir formule prix>
notes             : <optionnel — événement notable>
```

---

## Prix par agent — mandatory

Chaque session doit capturer `agents_loaded` et estimer le coût context de chaque agent.

```
Estimation :
  tokens_agent = taille_fichier_bytes / 4  (approximation standard)

Exemple :
  helloWorld.md      → 18k bytes → ~4500 tokens
  secrets-guardian.md → 12k bytes → ~3000 tokens
  debug.md           → 4k bytes  → ~1000 tokens
  total context agents : ~8500 tokens sur 200k = 4.3% alloué aux agents

Objectif : tendance sur 10 sessions
  → Quels agents sont toujours chargés pour rien ?
  → Quels agents coûtent cher vs leur valeur produite ?
  → Base de décision pour le context-orchestrator (chargement capillaire)
```

Format dans le metabolism log :
```
agents_loaded:
  - session-orchestrator : ~Xk tokens
  - helloWorld           : ~Xk tokens
  - <agent>              : ~Xk tokens
total_context_agents     : ~Xk tokens  (X% du budget total)
```

---

## Formule health_score

```
health_score = (todos_closed * 10 + commits * 5) / max(1, tokens_used_k * context_peak_pct / 100)

où tokens_used_k = tokens_used / 1000

Exemples :
  todos=2, commits=3, tokens=45k, peak=31%  → (20+15) / (45 * 0.31) = 35 / 13.95 ≈ 2.51
  todos=0, commits=0, tokens=80k, peak=87%  → 0 / 69.6 = 0  → saturation_flag = true
```

Le score n'est pas absolu — il se lit en tendance sur 7 jours.

---

## saturation_flag

`true` si `context_peak_pct > 80` ET `todos_closed = 0`

Signal : session qui consomme sans produire. Ne pénalise pas les sessions de brainstorm (mode brainstorm exclu du calcul saturation).

---

## Taxonomie session — type

| Type | Définition |
|------|-----------|
| `build-brain` | Session dédiée au brain lui-même (agents, specs, infra, BSI, scribe-system) |
| `use-brain` | Session projet concret (OriginsDigital, SuperOAuth, VPS, portfolio) |
| `auto` | Session mixte ou non classifiable — metabolism-scribe tranche en fin |

**Règle ratio sur 7 jours glissants :**
```
ratio = use-brain_sessions / build-brain_sessions
→ ratio >= 1.0 : équilibré ou sain
→ ratio < 0.5  : ⚠️ Signal boucle narcissique — trop de build-brain sans usage réel
```

Le signal est affiché dans le briefing helloWorld si `ratio < 0.5` sur 7j.

---

## Seuils — mode conserve

| Condition | Signal |
|-----------|--------|
| `context_peak_pct > 70` ET `health_score < 1.0` | ⚠️ Session peu efficiente détectée |
| `context_at_close > 60` | ⚠️ Mode conserve recommandé pour la prochaine session |
| `ratio < 0.5` sur 7j | ⚠️ Boucle narcissique — alterner avec une session use-brain |

Mode `conserve` : helloWorld le propose (jamais forcé) si seuil atteint au boot.

---

## Modes et budget context attendu

| Mode | Budget context | Saturation tolérée |
|------|----------------|-------------------|
| `prod` | normal — surveiller à 60% | non |
| `sprint` | élargi — 80% acceptable si output élevé | oui si commits > 5 |
| `conserve` | strict — target <40% | non |
| `brainstorm` | libre | oui — exclut saturation_flag |
| `review` | minimal — lecture seule | non |
| `debug` | modéré | non |
| `coach` | modéré | non |

---

## Changelog

| Date | Changement |
|------|------------|
| 2026-03-14 | Création — schéma métriques, formule health_score, taxonomie build/use-brain, seuils conserve, ratio 7j |
| 2026-03-14 | Prix par agent mandatory — champs agents_loaded + tokens_par_agent, formule estimation, objectif tendance 10 sessions |
