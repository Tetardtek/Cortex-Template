# memory-global — Layer cognitif Claude

Ce répertoire est le **layer 0 de ta relation avec Claude Code**.

Il est symlinké vers `~/.claude/memory/` au setup — ce qui signifie que son contenu est chargé **avant tout** : avant CLAUDE.md, avant les agents, avant le bootstrap. C'est la première chose que Claude lit sur cette machine, dans tous tes projets.

---

## Pourquoi ça existe

Sans ce layer, Claude repart de zéro à chaque projet. Il ne sait pas qui tu es, comment tu travailles, ce que tu attends de lui. Avec ce layer, il porte une personnalité forgée autour de toi — et elle grandit avec toi.

---

## Ce que tu mets ici

**3 types de fichiers — tous optionnels, tous à toi :**

### `user_<ton-nom>.md` — ton profil
Qui tu es techniquement. Comment tu apprends. Ce que tu construis. Ton niveau réel, pas un CV.
→ Voir `examples/user_example.md`

### `coach_presence.md` — l'ancrage de ton Claude
Pas obligatoire. Si tu veux un Claude avec une présence, une énergie, des règles non-négociables — c'est ici.
Sans ce fichier : Claude standard, fait ce qu'on lui demande. Correct, efficace, sans âme particulière.
→ Voir `examples/coach_example.md`

### `feedback_<sujet>.md` — tes corrections comportementales
Chaque fois que Claude fait quelque chose qui t'agace ou que tu veux ancrer comme règle universelle → un fichier ici. Il s'appliquera dans tous tes projets.
→ Voir `examples/feedback_example.md`

---

## Ce que tu ne mets PAS ici

- Contexte projet (→ `focus.md`, `agents/`, `workflows/`)
- Secrets ou tokens (→ `MYSECRETS`)
- Décisions techniques éphémères (→ `decisions/`)
- Tout ce qui décadera en quelques semaines

Ce layer est conçu pour être **stable et personnel**. Il évolue lentement — comme toi.

---

## Setup nouvelle machine

```bash
# Après avoir cloné le brain
ln -s <BRAIN_ROOT>/memory-global ~/.claude/memory
```

C'est tout. Claude charge ton layer au prochain démarrage.

---

## MEMORY.md — l'index

Le fichier `MEMORY.md` est l'index de ce répertoire. Claude le lit en premier.
Chaque fichier que tu crées ici doit y être référencé avec une description d'une ligne.

```markdown
## User
- [user_alice.md](user_alice.md) — Profil Alice : description courte

## Feedback
- [feedback_output.md](feedback_output.md) — Règle courte

## Reference
- [reference_infra.md](reference_infra.md) — Pointeurs infra machine
```
