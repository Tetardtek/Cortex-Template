#!/usr/bin/env python3
"""
brain-engine/embed.py — Pipeline d'embedding BE-2c
Indexe le corpus brain via Ollama nomic-embed-text → table embeddings dans brain.db

Usage :
  python3 brain-engine/embed.py                  → index tout le corpus
  python3 brain-engine/embed.py --dry-run        → liste les chunks sans embed
  python3 brain-engine/embed.py --file agents/helloWorld.md  → réindexer un fichier
  python3 brain-engine/embed.py --stats          → stats de l'index actuel

Headless : zéro dépendance Wayland/display.
OLLAMA_URL : variable d'env (défaut localhost:11434) — supporte réseau local.

Zone filter — ADR-033a (2026-03-18) :
  kernel  (agents/, wiki/, toolkit/, contexts/, KERNEL.md) → toujours indexé
  project (projets/, handoffs/, workspace/)                → TTL 60 jours git-based
  session (claims/)                                        → JAMAIS indexé
  personal (profil/bact/, profil/collaboration.md)         → JAMAIS indexé
  profil/decisions/                                        → scope frontmatter (kernel | project)

Stratégie chunking par type :
  agents/*.md, projets/*.md, wiki/**/*.md  → chunk par section H2
  workspace/**/*.md, profil/decisions/*.md → H2 ou fichier entier si < 512 tokens
  KERNEL.md, focus.md, contexts/           → fichier entier (documents courts)
"""

import os
import re
import sys
import json
import struct
import hashlib
import argparse
import sqlite3
import subprocess
import time
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

BRAIN_ROOT   = Path(__file__).parent.parent
DB_PATH      = BRAIN_ROOT / 'brain.db'
OLLAMA_URL   = os.getenv('OLLAMA_URL', 'http://localhost:11434')
EMBED_MODEL  = os.getenv('EMBED_MODEL', 'nomic-embed-text')

# Guardrail — LLMs génériques interdits : freeze machine garanti sur corpus entier
# (validé empiriquement : mistral:7b + qwen3:8b → freeze total ~20min, 2026-03-16)
_BLOCKED_MODELS = ['mistral', 'qwen', 'llama', 'gemma', 'phi', 'deepseek']
if any(b in EMBED_MODEL.lower() for b in _BLOCKED_MODELS):
    sys.exit(f"❌ EMBED_MODEL='{EMBED_MODEL}' interdit — LLM générique → freeze machine sur corpus entier.\n"
             f"   Utiliser un modèle dédié embedding : nomic-embed-text, mxbai-embed-large, all-minilm")

CHUNK_TOKENS = 512   # tokens max par chunk (approximé : 1 token ≈ 4 chars)
CHUNK_OVERLAP = 64   # overlap entre chunks consécutifs

# ── Zones d'accès ─────────────────────────────────────────────────────────────

# Zone 0 — jamais indexé (privé absolu) — ADR-033a
PRIVATE_PATHS = [
    'profil/capital.md',
    'profil/objectifs.md',
    'profil/bact/',           # personal — jamais
    'profil/collaboration.md',# personal — jamais
    'progression/',           # personal — journal + tout le répertoire
    'MYSECRETS',
]

# Zone par préfixe — premier match gagne — ADR-033a + KERNEL.md zones
# Zones : kernel | instance | satellite | public  (private = exclusion totale ci-dessus)
PATH_SCOPES = [
    # KERNEL — protection maximale
    ('contexts/',             'kernel'),
    ('profil/decisions/',     'kernel'),
    ('profil/',               'kernel'),
    ('KERNEL.md',             'kernel'),
    ('brain-constitution.md', 'kernel'),
    ('scripts/',              'kernel'),
    # INSTANCE — configuration machine + projets actifs
    ('focus.md',              'instance'),
    ('projets/',              'instance'),
    ('PATHS.md',              'instance'),
    ('now.md',                'instance'),
    # SATELLITE — vie libre, promotion possible
    ('toolkit/',              'satellite'),
    ('todo/',                 'satellite'),
    ('workspace/',            'satellite'),
    ('handoffs/',             'satellite'),
    ('intentions/',           'satellite'),
    # PUBLIC — visible, distribué
    ('wiki/',                 'public'),
    ('agents/',               'public'),
    ('infrastructure/',       'public'),
    ('BRAIN-INDEX.md',        'public'),
]
DEFAULT_SCOPE = 'public'


TTL_PROJECT_DAYS = 60  # ADR-033a — TTL projet, git-based


def is_private(filepath: str) -> bool:
    """Zone 0 — jamais indexé, jamais accessible."""
    return any(filepath == p or filepath.startswith(p) for p in PRIVATE_PATHS)


def resolve_scope(filepath: str) -> str:
    """Retourne la zone d'accès (kernel | instance | satellite | public)."""
    for prefix, scope in PATH_SCOPES:
        if filepath == prefix or filepath.startswith(prefix):
            return scope
    return DEFAULT_SCOPE


def get_frontmatter_scope(filepath: Path) -> str | None:
    """
    Lit le champ scope: du frontmatter YAML d'un fichier .md.
    Retourne 'kernel' | 'project' | 'personal' | None si absent.
    ADR-033a Règle 2 — override sur la règle répertoire.
    """
    try:
        text = filepath.read_text(errors='replace')
        if not text.startswith('---'):
            return None
        end = text.find('\n---', 3)
        if end == -1:
            return None
        for line in text[3:end].splitlines():
            line = line.strip()
            if line.startswith('scope:'):
                val = line[len('scope:'):].strip()
                val = val.split('#')[0].strip()  # retire commentaires inline
                return val if val else None
    except Exception:
        pass
    return None


def get_git_age_days(filepath: Path) -> int | None:
    """
    Retourne le nombre de jours depuis le dernier git commit sur ce fichier.
    None si le fichier n'est pas tracké ou si git échoue.
    ADR-033a — TTL git-based, aucun couplage BSI.
    """
    try:
        result = subprocess.run(
            ['git', 'log', '-1', '--format=%ct', '--', str(filepath)],
            capture_output=True, text=True, cwd=str(BRAIN_ROOT), timeout=5
        )
        ts = result.stdout.strip()
        if not ts:
            return None
        age_secs = time.time() - int(ts)
        return int(age_secs / 86400)
    except Exception:
        return None


def should_skip_by_zone(filepath: Path) -> bool:
    """
    Applique les règles ADR-033a — retourne True si le fichier doit être exclu.

    Règle 1 — répertoire (défaut)
    Règle 2 — frontmatter scope: (override sur Règle 1, pour profil/decisions/)

    Zones :
      kernel               → False (toujours indexé)
      project + TTL > 60j  → True  (périmé)
      personal             → True  (jamais)
    """
    rel = str(filepath.relative_to(BRAIN_ROOT))

    # profil/decisions/ — Règle 2 : scope par frontmatter
    if rel.startswith('profil/decisions/'):
        scope = get_frontmatter_scope(filepath)
        if scope == 'personal':
            return True
        if scope == 'project':
            age = get_git_age_days(filepath)
            return age is not None and age > TTL_PROJECT_DAYS
        # scope: kernel ou absent → toujours indexé
        return False

    # Zone project — TTL git-based
    if any(rel.startswith(p) for p in ('projets/', 'handoffs/', 'workspace/')):
        age = get_git_age_days(filepath)
        return age is not None and age > TTL_PROJECT_DAYS

    return False


# Corpus à indexer — chemins relatifs à BRAIN_ROOT — ADR-033a
# kernel → toujours  |  project → TTL 60j git  |  omis → JAMAIS
CORPUS_PATHS = [
    # ── kernel — toujours indexé ──────────────────────────────────────────────
    ('agents',           '*.md',    'h2'),    # agents brain
    ('wiki',             '**/*.md', 'h2'),    # documentation (submodule)
    ('toolkit',          '**/*.md', 'h2'),    # patterns réutilisables
    ('contexts',         '*.yml',   'file'),  # contextes de session
    # ── project — TTL 60 jours git-based ─────────────────────────────────────
    ('projets',          '*.md',    'h2'),
    ('handoffs',         '*.md',    'file'),
    ('workspace',        '**/*.md', 'h2'),
    # ── profil/decisions — scope par frontmatter (kernel | project) ──────────
    ('profil/decisions', '*.md',    'file'),
    # ── fichiers racine kernel ────────────────────────────────────────────────
    ('.',                'KERNEL.md',      'file'),
    ('.',                'focus.md',       'file'),
    ('.',                'BRAIN-INDEX.md', 'file'),
    # SUPPRIMÉ : ('ADR', ...) — chemin obsolète (ADRs dans profil/decisions/)
    # SUPPRIMÉ : ('profil', ...) — trop large, inclut bact/ — géré par scope
    # SUPPRIMÉ : ('claims', ...) — JAMAIS indexé per ADR-033a (session structurée)
]

# Fichiers à exclure
EXCLUDE_PATTERNS = [
    'brain-template/',
    'brain-engine/',
    '.git/',
    'node_modules/',
]


# ── Helpers ───────────────────────────────────────────────────────────────────

def should_exclude(filepath: Path) -> bool:
    s = str(filepath)
    if any(p in s for p in EXCLUDE_PATTERNS):
        return True
    # Zone 0 — privé absolu, jamais indexé
    if filepath.is_absolute():
        try:
            rel = str(filepath.relative_to(BRAIN_ROOT))
        except ValueError:
            rel = s  # path hors BRAIN_ROOT — is_private unlikely mais safe
    else:
        rel = s
    return is_private(rel)


def chunk_by_h2(text: str, filepath: str) -> list[dict]:
    """Découpe un markdown en chunks par section H2."""
    sections = re.split(r'\n(?=## )', text)
    chunks = []
    for sec in sections:
        sec = sec.strip()
        if not sec:
            continue
        # Si section trop longue → re-découper par paragraphes
        if len(sec) > CHUNK_TOKENS * 4:
            sub = chunk_by_size(sec, filepath)
            chunks.extend(sub)
        else:
            title = sec.split('\n')[0].strip('#').strip()
            chunks.append({'text': sec, 'title': title, 'filepath': filepath})
    return chunks if chunks else [{'text': text, 'title': '', 'filepath': filepath}]


def chunk_by_size(text: str, filepath: str) -> list[dict]:
    """Découpe un texte en chunks de CHUNK_TOKENS tokens (approx)."""
    max_chars = CHUNK_TOKENS * 4
    overlap_chars = CHUNK_OVERLAP * 4
    chunks = []
    start = 0
    while start < len(text):
        end = min(start + max_chars, len(text))
        # Couper sur un saut de ligne si possible
        if end < len(text):
            nl = text.rfind('\n', start, end)
            if nl > start:
                end = nl
        chunk_text = text[start:end].strip()
        if chunk_text:
            chunks.append({'text': chunk_text, 'title': '', 'filepath': filepath})
        if end >= len(text):
            break
        # Toujours avancer : si l'overlap remonterait avant start, aller à end
        next_start = end - overlap_chars
        start = next_start if next_start > start else end
    return chunks


def chunk_file(filepath: Path, strategy: str) -> list[dict]:
    """Lit un fichier et retourne ses chunks selon la stratégie."""
    try:
        text = filepath.read_text(errors='replace').strip()
    except Exception as e:
        print(f"  ⚠️  {filepath.name} : erreur lecture — {e}")
        return []

    if not text:
        return []

    rel = str(filepath.relative_to(BRAIN_ROOT))

    if strategy == 'h2':
        return chunk_by_h2(text, rel)
    else:
        # Fichier entier — si trop long, chunk par taille
        if len(text) > CHUNK_TOKENS * 4:
            return chunk_by_size(text, rel)
        title = filepath.stem
        return [{'text': text, 'title': title, 'filepath': rel}]


def chunk_id(filepath: str, text: str) -> str:
    """ID déterministe : hash(filepath + text[:64])."""
    h = hashlib.sha1(f"{filepath}::{text[:64]}".encode()).hexdigest()[:12]
    return f"emb-{h}"


# ── Ollama API ────────────────────────────────────────────────────────────────

def get_embedding(text: str) -> list[float] | None:
    """Appelle Ollama embeddings API — retourne None si indisponible."""
    url = f"{OLLAMA_URL}/api/embeddings"
    payload = json.dumps({"model": EMBED_MODEL, "prompt": text}).encode()
    req = urllib.request.Request(url, data=payload,
                                  headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
            return data.get('embedding')
    except (urllib.error.URLError, TimeoutError) as e:
        print(f"  ⚠️  Ollama indisponible ({OLLAMA_URL}) : {e}")
        return None


def vector_to_blob(vec: list[float]) -> bytes:
    """Sérialise un vecteur float32 en BLOB SQLite."""
    return struct.pack(f'{len(vec)}f', *vec)


def blob_to_vector(blob: bytes) -> list[float]:
    """Désérialise un BLOB SQLite en vecteur float32."""
    n = len(blob) // 4
    return list(struct.unpack(f'{n}f', blob))


# ── SQLite ────────────────────────────────────────────────────────────────────

def connect() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    # Créer la table embeddings si absente (extend schema)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS embeddings (
            chunk_id    TEXT PRIMARY KEY,
            filepath    TEXT NOT NULL,
            title       TEXT,
            chunk_text  TEXT NOT NULL,
            vector      BLOB,               -- NULL si Ollama indisponible au moment du chunk
            model       TEXT,
            indexed     INTEGER DEFAULT 0,  -- 1 = vecteur présent
            scope       TEXT NOT NULL DEFAULT 'work',  -- kernel | instance | satellite | public
            created_at  TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)
    # Migration — ajouter scope si absente (db existante avant BE-4)
    try:
        conn.execute("ALTER TABLE embeddings ADD COLUMN scope TEXT NOT NULL DEFAULT 'work'")
        conn.commit()
        # Backfill — résoudre le scope de chaque chunk existant depuis son filepath
        rows = conn.execute("SELECT DISTINCT filepath FROM embeddings WHERE scope = 'work'").fetchall()
        for row in rows:
            fp = row['filepath']
            s  = resolve_scope(fp)
            if s != 'work':
                conn.execute("UPDATE embeddings SET scope = ? WHERE filepath = ?", (s, fp))
        conn.commit()
    except Exception:
        pass  # colonne déjà présente
    conn.execute("CREATE INDEX IF NOT EXISTS idx_emb_filepath ON embeddings(filepath)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_emb_indexed ON embeddings(indexed)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_emb_scope ON embeddings(scope)")
    conn.commit()
    return conn


def upsert_chunk(conn: sqlite3.Connection, chunk: dict,
                 vector: list[float] | None, dry_run: bool = False) -> bool:
    cid     = chunk_id(chunk['filepath'], chunk['text'])
    blob    = vector_to_blob(vector) if vector else None
    indexed = 1 if vector else 0
    scope   = chunk.get('scope', resolve_scope(chunk['filepath']))

    if dry_run:
        return True

    conn.execute("""
        INSERT INTO embeddings(chunk_id, filepath, title, chunk_text, vector, model, indexed, scope, updated_at)
        VALUES (?,?,?,?,?,?,?,?, datetime('now'))
        ON CONFLICT(chunk_id) DO UPDATE SET
            chunk_text = excluded.chunk_text,
            vector     = COALESCE(excluded.vector, embeddings.vector),
            indexed    = COALESCE(excluded.indexed, embeddings.indexed),
            scope      = excluded.scope,
            updated_at = excluded.updated_at
    """, (cid, chunk['filepath'], chunk.get('title',''), chunk['text'],
          blob, EMBED_MODEL if vector else None, indexed, scope))
    return True


# ── Pipeline principal ────────────────────────────────────────────────────────

def collect_files(target_file: str | None = None) -> list[tuple[Path, str]]:
    """Retourne la liste (path, strategy) des fichiers à indexer."""
    files = []
    seen = set()

    if target_file:
        p = (BRAIN_ROOT / target_file).resolve()
        if not str(p).startswith(str(BRAIN_ROOT.resolve())):
            print(f"  🚨 --file hors BRAIN_ROOT refusé : {p}")
            return files
        if p.exists():
            # Déterminer stratégie par répertoire
            for base, pattern, strategy in CORPUS_PATHS:
                if str(p).startswith(str(BRAIN_ROOT / base)):
                    files.append((p, strategy))
                    break
            else:
                files.append((p, 'h2'))
        return files

    for base, pattern, strategy in CORPUS_PATHS:
        base_path = BRAIN_ROOT / base
        if not base_path.exists():
            continue
        for p in sorted(base_path.glob(pattern)):
            if p in seen or not p.is_file():
                continue
            if should_exclude(p):
                continue
            if should_skip_by_zone(p):
                continue
            seen.add(p)
            files.append((p, strategy))

    return files


def run(dry_run: bool = False, target_file: str | None = None,
        stats_only: bool = False):

    conn = connect()

    if stats_only:
        total   = conn.execute("SELECT COUNT(*) FROM embeddings").fetchone()[0]
        indexed = conn.execute("SELECT COUNT(*) FROM embeddings WHERE indexed=1").fetchone()[0]
        pending = total - indexed
        files_n = conn.execute("SELECT COUNT(DISTINCT filepath) FROM embeddings").fetchone()[0]
        print(f"Index embeddings :")
        print(f"  chunks total  : {total}")
        print(f"  indexés       : {indexed}  ({100*indexed//total if total else 0}%)")
        print(f"  sans vecteur  : {pending}")
        print(f"  fichiers      : {files_n}")
        print(f"  modèle        : {EMBED_MODEL} @ {OLLAMA_URL}")
        conn.close()
        return

    files = collect_files(target_file)
    print(f"Corpus : {len(files)} fichier(s) — modèle {EMBED_MODEL} @ {OLLAMA_URL}")

    # Tester Ollama avant de boucler
    test_vec = get_embedding("test connexion") if not dry_run else None
    ollama_ok = test_vec is not None
    if not ollama_ok and not dry_run:
        print(f"  ⚠️  Ollama indisponible — chunks enregistrés sans vecteur (indexed=0)")

    total_chunks = 0
    total_indexed = 0

    for filepath, strategy in files:
        chunks = chunk_file(filepath, strategy)
        if not chunks:
            continue

        file_chunks = 0
        for chunk in chunks:
            chunk['scope'] = resolve_scope(chunk['filepath'])
            vec = None
            if ollama_ok and not dry_run:
                vec = get_embedding(chunk['text'])
                if vec:
                    total_indexed += 1

            upsert_chunk(conn, chunk, vec, dry_run=dry_run)
            total_chunks += 1
            file_chunks += 1

        rel = str(filepath.relative_to(BRAIN_ROOT))
        status = "✅" if ollama_ok else "⬜"
        print(f"  {status} {rel} — {file_chunks} chunk(s)")

    if not dry_run:
        conn.commit()

    print(f"\n{'[dry] ' if dry_run else ''}Chunks traités : {total_chunks}")
    if not dry_run:
        print(f"Vecteurs générés : {total_indexed}")
        if not ollama_ok:
            print(f"⚠️  Relancer avec Ollama actif pour compléter l'index")

    conn.close()


# ── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='brain-engine embed — pipeline embeddings BE-2c')
    parser.add_argument('--dry-run',  action='store_true', help='Liste les chunks sans embed')
    parser.add_argument('--file',     metavar='PATH',      help='Réindexer un fichier spécifique')
    parser.add_argument('--stats',    action='store_true', help='Stats de l\'index actuel')
    args = parser.parse_args()

    run(dry_run=args.dry_run, target_file=args.file, stats_only=args.stats)


if __name__ == '__main__':
    main()
