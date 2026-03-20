#!/usr/bin/env python3
"""
brain-engine/search.py — Recherche sémantique BE-2d
Embed une query → cosine similarity sur brain.db → top-K chunks

Usage :
  python3 brain-engine/search.py "décisions archi SuperOAuth"
  python3 brain-engine/search.py "cold start" --top 10
  python3 brain-engine/search.py "agents helloWorld" --mode file
  python3 brain-engine/search.py "sessions metabolism" --mode json

Modes :
  human  (défaut) → tableau lisible : score | filepath | extrait
  file            → filepaths dédupliqués, triés par score (pour Claude : charger ces fichiers)
  json            → JSON brut : [{score, filepath, title, chunk_text}]

Headless : zéro dépendance display/Wayland.
OLLAMA_URL : variable d'env (défaut localhost:11434).
"""

import os
import sys
import json
import struct
import argparse
import sqlite3
import urllib.request
import urllib.error
from pathlib import Path

BRAIN_ROOT  = Path(__file__).parent.parent
DB_PATH     = BRAIN_ROOT / 'brain.db'
OLLAMA_URL  = os.getenv('OLLAMA_URL', 'http://localhost:11434')
EMBED_MODEL = os.getenv('EMBED_MODEL', 'nomic-embed-text')

# Guardrail — cohérent avec embed.py
_BLOCKED_MODELS = ['mistral', 'qwen', 'llama', 'gemma', 'phi', 'deepseek']
if any(b in EMBED_MODEL.lower() for b in _BLOCKED_MODELS):
    sys.exit(f"❌ EMBED_MODEL='{EMBED_MODEL}' interdit — utiliser nomic-embed-text ou mxbai-embed-large")


# ── Maths ─────────────────────────────────────────────────────────────────────

def cosine_sim(a: list[float], b: list[float]) -> float:
    dot    = sum(x * y for x, y in zip(a, b))
    norm_a = sum(x * x for x in a) ** 0.5
    norm_b = sum(x * x for x in b) ** 0.5
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return dot / (norm_a * norm_b)


def blob_to_vector(blob: bytes) -> list[float]:
    n = len(blob) // 4
    return list(struct.unpack(f'{n}f', blob))


# ── Ollama ─────────────────────────────────────────────────────────────────────

def embed_query(text: str) -> list[float] | None:
    url     = f"{OLLAMA_URL}/api/embeddings"
    payload = json.dumps({"model": EMBED_MODEL, "prompt": text}).encode()
    req     = urllib.request.Request(url, data=payload,
                                     headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read())
            return data.get('embedding')
    except (urllib.error.URLError, TimeoutError) as e:
        print(f"❌ Ollama indisponible ({OLLAMA_URL}) : {e}", file=sys.stderr)
        return None


# ── SQLite ─────────────────────────────────────────────────────────────────────

def load_vectors(conn: sqlite3.Connection,
                 allowed_scopes: list[str] | None = None,
                 include_historical: bool = False) -> list[dict]:
    """Charge les chunks indexés depuis brain.db, filtrés par scope si fourni.
    Shadow indexing (ADR-037) : scope='historical' exclu par défaut."""
    historical_filter = "" if include_historical else "AND scope != 'historical'"
    if allowed_scopes:
        placeholders = ','.join('?' * len(allowed_scopes))
        rows = conn.execute(f"""
            SELECT chunk_id, filepath, title, chunk_text, vector
            FROM embeddings
            WHERE indexed = 1 AND vector IS NOT NULL
              AND scope IN ({placeholders})
              {historical_filter}
        """, allowed_scopes).fetchall()
    else:
        rows = conn.execute(f"""
            SELECT chunk_id, filepath, title, chunk_text, vector
            FROM embeddings
            WHERE indexed = 1 AND vector IS NOT NULL
              {historical_filter}
        """).fetchall()
    result = []
    for row in rows:
        result.append({
            'chunk_id':   row['chunk_id'],
            'filepath':   row['filepath'],
            'title':      row['title'] or '',
            'chunk_text': row['chunk_text'],
            'vector':     blob_to_vector(row['vector']),
        })
    return result


# ── Search ─────────────────────────────────────────────────────────────────────

def search(query: str, top_k: int = 5, min_score: float = 0.0,
           allowed_scopes: list[str] | None = None) -> list[dict]:
    """Retourne les top-K chunks les plus proches de la query."""
    # 1. Embed la query
    q_vec = embed_query(query)
    if q_vec is None:
        return []

    # 2. Charger les vecteurs (filtrés par scope si fourni)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    chunks = load_vectors(conn, allowed_scopes=allowed_scopes)
    conn.close()

    if not chunks:
        print("⚠️  Index vide — lancer embed.py d'abord", file=sys.stderr)
        return []

    # 3. Cosine similarity
    scored = []
    for chunk in chunks:
        score = cosine_sim(q_vec, chunk['vector'])
        if score >= min_score:
            scored.append({**chunk, 'score': score})

    # 4. Trier, dédupliquer par chunk_id (déjà unique), retourner top-K
    scored.sort(key=lambda x: x['score'], reverse=True)
    top_results = scored[:top_k]

    # 5. Tracking V1 (ADR-037) — hit_count + last_queried_at sur les chunks retournés
    if top_results:
        try:
            track_conn = sqlite3.connect(DB_PATH)
            chunk_ids = [r['chunk_id'] for r in top_results if r.get('chunk_id')]
            if chunk_ids:
                placeholders = ','.join('?' * len(chunk_ids))
                track_conn.execute(f"""
                    UPDATE embeddings
                    SET hit_count = COALESCE(hit_count, 0) + 1,
                        last_queried_at = datetime('now')
                    WHERE chunk_id IN ({placeholders})
                """, chunk_ids)
                track_conn.commit()
            track_conn.close()
        except Exception:
            pass  # tracking is best-effort — never breaks search

    return top_results


# ── Output ─────────────────────────────────────────────────────────────────────

def print_human(results: list[dict], query: str):
    if not results:
        print(f"Aucun résultat pour : {query!r}")
        return
    print(f"\nRecherche : {query!r}  ({len(results)} résultat(s))\n")
    print(f"{'Score':>6}  {'Fichier':<50}  Extrait")
    print("─" * 100)
    for r in results:
        score   = f"{r['score']:.3f}"
        fp      = r['filepath']
        if len(fp) > 50:
            fp = '…' + fp[-49:]
        title   = r['title']
        excerpt = r['chunk_text'].replace('\n', ' ')[:80]
        if title:
            excerpt = f"[{title}] {excerpt}"
        print(f"{score:>6}  {fp:<50}  {excerpt}")
    print()


def print_files(results: list[dict]):
    """Filepaths dédupliqués, ordre par meilleur score."""
    seen = []
    for r in results:
        if r['filepath'] not in seen:
            seen.append(r['filepath'])
    for fp in seen:
        print(fp)


def print_json(results: list[dict]):
    out = [{
        'score':      round(r['score'], 4),
        'filepath':   r['filepath'],
        'title':      r['title'],
        'chunk_text': r['chunk_text'],
    } for r in results]
    print(json.dumps(out, ensure_ascii=False, indent=2))


# ── CLI ────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description='brain-engine search — BE-2d')
    parser.add_argument('query',                          help='Requête en langage naturel')
    parser.add_argument('--top',    type=int, default=5,  help='Nombre de résultats (défaut: 5)')
    parser.add_argument('--mode',   choices=['human', 'file', 'json'], default='human',
                        help='Format de sortie (défaut: human)')
    parser.add_argument('--min-score', type=float, default=0.0,
                        help='Score minimum cosine (0.0–1.0, défaut: 0.0)')
    args = parser.parse_args()

    results = search(args.query, top_k=args.top, min_score=args.min_score)

    if args.mode == 'file':
        print_files(results)
    elif args.mode == 'json':
        print_json(results)
    else:
        print_human(results, args.query)


if __name__ == '__main__':
    main()
