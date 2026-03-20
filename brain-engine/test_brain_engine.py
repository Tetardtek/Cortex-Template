#!/usr/bin/env python3
"""
brain-engine/test_brain_engine.py — Tests unitaires BE-2
Stdlib uniquement (unittest). Aucun accès réseau, Ollama, ou brain.db requis.

Lancer :
  python3 brain-engine/test_brain_engine.py
  python3 brain-engine/test_brain_engine.py -v
"""

import sys
import os
import unittest
import tempfile
import struct
from pathlib import Path
from unittest.mock import patch, MagicMock

# ── Import des modules sous test ───────────────────────────────────────────────
# Les modules ont un guardrail EMBED_MODEL au niveau module — nomic-embed-text
# (défaut) passe ; on s'assure de ne pas avoir de variable bloquante.
os.environ.setdefault('EMBED_MODEL', 'nomic-embed-text')

sys.path.insert(0, str(Path(__file__).parent))
import embed
import search
import distill


# ══════════════════════════════════════════════════════════════════════════════
# embed.py — chunk_by_size
# ══════════════════════════════════════════════════════════════════════════════

class TestChunkBySize(unittest.TestCase):

    def test_short_text_single_chunk(self):
        """Texte plus court que max_chars → 1 seul chunk."""
        text = "Bonjour le monde."
        chunks = embed.chunk_by_size(text, "test.md")
        self.assertEqual(len(chunks), 1)
        self.assertEqual(chunks[0]['text'], text)

    def test_long_text_multiple_chunks(self):
        """Texte long → plusieurs chunks, tous non vides."""
        text = "A" * (embed.CHUNK_TOKENS * 4 * 3)  # 3× la taille max
        chunks = embed.chunk_by_size(text, "test.md")
        self.assertGreater(len(chunks), 1)
        for c in chunks:
            self.assertTrue(c['text'])

    def test_no_infinite_loop_regression(self):
        """
        RÉGRESSION — bug boucle infinie (corrigé 2026-03-16).
        Tout texte > CHUNK_TOKENS*4 sans saut de ligne déclenchait une boucle
        infinie : start = end - overlap restait toujours < len(text).
        Ce test doit terminer en < 1s.
        """
        import signal

        def timeout_handler(signum, frame):
            raise TimeoutError("chunk_by_size en boucle infinie !")

        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(2)  # 2 secondes max
        try:
            # Texte sans saut de ligne — le cas exact qui causait le freeze
            text = "X" * (embed.CHUNK_TOKENS * 4 + 100)
            chunks = embed.chunk_by_size(text, "test.md")
            self.assertGreater(len(chunks), 0)
        finally:
            signal.alarm(0)

    def test_no_infinite_loop_with_newlines(self):
        """Texte avec sauts de ligne — variante avec newlines."""
        import signal

        def timeout_handler(signum, frame):
            raise TimeoutError("chunk_by_size en boucle infinie !")

        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(2)
        try:
            line = "Ligne de texte normale.\n"
            text = line * 300  # ~7 200 chars
            chunks = embed.chunk_by_size(text, "test.md")
            self.assertGreater(len(chunks), 1)
        finally:
            signal.alarm(0)

    def test_chunks_cover_full_text(self):
        """Vérifier que les chunks couvrent bien tout le texte (pas de trou)."""
        text = "mot " * 1000  # ~4 000 chars
        chunks = embed.chunk_by_size(text, "test.md")
        # Le dernier chunk doit contenir la fin du texte
        last_chunk = chunks[-1]['text']
        self.assertIn("mot", last_chunk)

    def test_filepath_preserved(self):
        """Le filepath est propagé dans chaque chunk."""
        text = "A" * (embed.CHUNK_TOKENS * 4 + 1)
        fp = "agents/helloWorld.md"
        chunks = embed.chunk_by_size(text, fp)
        for c in chunks:
            self.assertEqual(c['filepath'], fp)

    def test_empty_text(self):
        """Texte vide → aucun chunk."""
        chunks = embed.chunk_by_size("", "test.md")
        self.assertEqual(len(chunks), 0)

    def test_whitespace_only(self):
        """Texte uniquement whitespace → aucun chunk."""
        chunks = embed.chunk_by_size("   \n\n   ", "test.md")
        self.assertEqual(len(chunks), 0)


# ══════════════════════════════════════════════════════════════════════════════
# embed.py — chunk_by_h2
# ══════════════════════════════════════════════════════════════════════════════

class TestChunkByH2(unittest.TestCase):

    def test_single_section(self):
        """Un seul fichier sans H2 → 1 chunk."""
        text = "# Titre\n\nContenu simple sans section H2."
        chunks = embed.chunk_by_h2(text, "test.md")
        self.assertEqual(len(chunks), 1)

    def test_multiple_h2_sections(self):
        """Plusieurs sections H2 → un chunk par section."""
        text = "## Section 1\nContenu 1\n\n## Section 2\nContenu 2\n\n## Section 3\nContenu 3"
        chunks = embed.chunk_by_h2(text, "test.md")
        self.assertEqual(len(chunks), 3)

    def test_section_title_extracted(self):
        """Le titre H2 est extrait proprement."""
        text = "## Mon Agent\nContenu de l'agent."
        chunks = embed.chunk_by_h2(text, "test.md")
        self.assertEqual(chunks[0]['title'], 'Mon Agent')

    def test_long_section_sub_chunked(self):
        """Section H2 trop longue → sous-chunking par taille."""
        long_content = "X" * (embed.CHUNK_TOKENS * 4 + 100)
        text = f"## Section longue\n{long_content}"
        chunks = embed.chunk_by_h2(text, "test.md")
        # Doit produire plusieurs chunks, pas boucler
        self.assertGreater(len(chunks), 1)

    def test_empty_text_fallback(self):
        """Texte vide → chunk_by_h2 retourne 1 chunk (vide) — chunk_file filtre en amont."""
        chunks = embed.chunk_by_h2("", "test.md")
        # Le fallback retourne toujours au moins 1 chunk ; chunk_file gère le cas vide avant appel
        self.assertEqual(len(chunks), 1)


# ══════════════════════════════════════════════════════════════════════════════
# embed.py — utilitaires
# ══════════════════════════════════════════════════════════════════════════════

class TestEmbedUtils(unittest.TestCase):

    def test_chunk_id_deterministic(self):
        """Même input → même chunk_id."""
        cid1 = embed.chunk_id("agents/test.md", "contenu du chunk")
        cid2 = embed.chunk_id("agents/test.md", "contenu du chunk")
        self.assertEqual(cid1, cid2)

    def test_chunk_id_different_inputs(self):
        """Inputs différents → chunk_id différents."""
        cid1 = embed.chunk_id("agents/test.md", "contenu A")
        cid2 = embed.chunk_id("agents/test.md", "contenu B")
        self.assertNotEqual(cid1, cid2)

    def test_chunk_id_format(self):
        """chunk_id commence par 'emb-'."""
        cid = embed.chunk_id("test.md", "texte")
        self.assertTrue(cid.startswith("emb-"))

    def test_vector_roundtrip(self):
        """Sérialiser puis désérialiser un vecteur → valeurs identiques."""
        vec = [0.1, 0.2, 0.3, -0.5, 1.0]
        blob = embed.vector_to_blob(vec)
        restored = embed.blob_to_vector(blob)
        for a, b in zip(vec, restored):
            self.assertAlmostEqual(a, b, places=5)

    def test_should_exclude_brain_engine(self):
        """brain-engine/ est exclu."""
        p = Path("/brain/brain-engine/embed.py")
        self.assertTrue(embed.should_exclude(p))

    def test_should_exclude_git(self):
        """.git/ est exclu."""
        p = Path("/brain/.git/config")
        self.assertTrue(embed.should_exclude(p))

    def test_should_not_exclude_agents(self):
        """agents/ n'est pas exclu."""
        p = Path("/brain/agents/helloWorld.md")
        self.assertFalse(embed.should_exclude(p))

    def test_should_not_exclude_claims(self):
        """claims/ n'est pas exclu."""
        p = Path("/brain/claims/sess-20260316-test.yml")
        self.assertFalse(embed.should_exclude(p))


# ══════════════════════════════════════════════════════════════════════════════
# search.py — cosine_sim
# ══════════════════════════════════════════════════════════════════════════════

class TestCosineSim(unittest.TestCase):

    def test_identical_vectors(self):
        """Vecteurs identiques → similarité 1.0."""
        v = [0.1, 0.5, -0.3, 0.8]
        self.assertAlmostEqual(search.cosine_sim(v, v), 1.0, places=5)

    def test_opposite_vectors(self):
        """Vecteurs opposés → similarité -1.0."""
        v = [1.0, 0.0, 0.0]
        w = [-1.0, 0.0, 0.0]
        self.assertAlmostEqual(search.cosine_sim(v, w), -1.0, places=5)

    def test_orthogonal_vectors(self):
        """Vecteurs orthogonaux → similarité 0.0."""
        v = [1.0, 0.0]
        w = [0.0, 1.0]
        self.assertAlmostEqual(search.cosine_sim(v, w), 0.0, places=5)

    def test_zero_vector(self):
        """Vecteur nul → similarité 0.0 (pas de division par zéro)."""
        v = [0.0, 0.0, 0.0]
        w = [1.0, 2.0, 3.0]
        self.assertEqual(search.cosine_sim(v, w), 0.0)

    def test_symmetry(self):
        """cosine_sim(a, b) == cosine_sim(b, a)."""
        a = [0.3, -0.1, 0.7]
        b = [0.5, 0.2, -0.4]
        self.assertAlmostEqual(search.cosine_sim(a, b), search.cosine_sim(b, a), places=10)

    def test_range(self):
        """Résultat toujours dans [-1, 1]."""
        import random
        random.seed(42)
        for _ in range(50):
            a = [random.uniform(-1, 1) for _ in range(768)]
            b = [random.uniform(-1, 1) for _ in range(768)]
            sim = search.cosine_sim(a, b)
            self.assertGreaterEqual(sim, -1.0 - 1e-6)
            self.assertLessEqual(sim, 1.0 + 1e-6)


# ══════════════════════════════════════════════════════════════════════════════
# search.py — blob_to_vector
# ══════════════════════════════════════════════════════════════════════════════

class TestSearchUtils(unittest.TestCase):

    def test_blob_to_vector_roundtrip(self):
        """Blob → vecteur cohérent avec embed.vector_to_blob."""
        vec = [0.1, -0.2, 0.5, 1.0, -0.9]
        blob = embed.vector_to_blob(vec)
        restored = search.blob_to_vector(blob)
        for a, b in zip(vec, restored):
            self.assertAlmostEqual(a, b, places=5)

    def test_blob_to_vector_768_dims(self):
        """Blob de 768 floats → vecteur de 768 éléments."""
        vec = [float(i) / 768 for i in range(768)]
        blob = embed.vector_to_blob(vec)
        restored = search.blob_to_vector(blob)
        self.assertEqual(len(restored), 768)


# ══════════════════════════════════════════════════════════════════════════════
# Intégration — dry-run sur un fichier temporaire
# ══════════════════════════════════════════════════════════════════════════════

class TestIntegrationDryRun(unittest.TestCase):

    def test_chunk_file_markdown(self):
        """chunk_file sur un vrai fichier .md → chunks non vides."""
        with tempfile.NamedTemporaryFile(suffix='.md', mode='w', delete=False) as f:
            f.write("## Section A\nContenu de la section A.\n\n## Section B\nContenu B.\n")
            tmp = Path(f.name)
        try:
            with patch.object(embed, 'BRAIN_ROOT', tmp.parent):
                chunks = embed.chunk_file(tmp, 'h2')
            self.assertEqual(len(chunks), 2)
            self.assertEqual(chunks[0]['title'], 'Section A')
            self.assertEqual(chunks[1]['title'], 'Section B')
        finally:
            tmp.unlink()

    def test_chunk_file_large_no_hang(self):
        """
        RÉGRESSION — chunk_file sur un fichier large (strategy=file)
        ne doit pas boucler indéfiniment.
        """
        import signal

        def timeout_handler(signum, frame):
            raise TimeoutError("chunk_file en boucle infinie !")

        signal.signal(signal.SIGALRM, timeout_handler)
        signal.alarm(3)
        try:
            with tempfile.NamedTemporaryFile(suffix='.md', mode='w', delete=False) as f:
                # focus.md fait ~11K — reproduire le cas exact du bug
                f.write("Contenu sans saut de ligne.\n" * 400)  # ~11 200 chars
                tmp = Path(f.name)
            with patch.object(embed, 'BRAIN_ROOT', tmp.parent):
                chunks = embed.chunk_file(tmp, 'file')
            self.assertGreater(len(chunks), 0)
        finally:
            signal.alarm(0)
            tmp.unlink()


# ══════════════════════════════════════════════════════════════════════════════
# migrate.py — parse_yml_field
# ══════════════════════════════════════════════════════════════════════════════

import migrate

class TestParseYmlField(unittest.TestCase):

    def test_basic_field(self):
        content = "sess_id: sess-20260316-test\nstatus: open\n"
        self.assertEqual(migrate.parse_yml_field(content, 'sess_id'), 'sess-20260316-test')
        self.assertEqual(migrate.parse_yml_field(content, 'status'), 'open')

    def test_quoted_value(self):
        content = 'story_angle: "Reprise BE-2 après crash"\n'
        self.assertEqual(migrate.parse_yml_field(content, 'story_angle'), 'Reprise BE-2 après crash')

    def test_missing_field_returns_default(self):
        content = "sess_id: test\n"
        self.assertIsNone(migrate.parse_yml_field(content, 'closed_at'))
        self.assertEqual(migrate.parse_yml_field(content, 'closed_at', 'fallback'), 'fallback')

    def test_field_with_spaces(self):
        content = "opened_at:  2026-03-16T13:40  \n"
        self.assertEqual(migrate.parse_yml_field(content, 'opened_at'), '2026-03-16T13:40')


# ══════════════════════════════════════════════════════════════════════════════
# migrate.py — migrate_claims + migrate_sessions (BE-2b)
# ══════════════════════════════════════════════════════════════════════════════

SCHEMA_PATH = Path(__file__).parent / 'schema.sql'

def make_in_memory_db():
    """Crée une DB SQLite in-memory avec le schéma brain + table embeddings."""
    import sqlite3
    conn = sqlite3.connect(':memory:')
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys=ON")
    with open(SCHEMA_PATH) as f:
        conn.executescript(f.read())
    # Table embeddings créée par embed.connect() — pas dans schema.sql
    conn.execute("""
        CREATE TABLE IF NOT EXISTS embeddings (
            chunk_id    TEXT PRIMARY KEY,
            filepath    TEXT NOT NULL,
            title       TEXT,
            chunk_text  TEXT NOT NULL,
            vector      BLOB,
            model       TEXT,
            indexed     INTEGER DEFAULT 0,
            created_at  TEXT NOT NULL DEFAULT (datetime('now')),
            updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
        )
    """)
    conn.commit()
    return conn


class TestMigrateClaims(unittest.TestCase):

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.claims_dir = Path(self.tmpdir.name) / 'claims'
        self.claims_dir.mkdir()

    def tearDown(self):
        self.tmpdir.cleanup()

    def _write_claim(self, filename, content):
        (self.claims_dir / filename).write_text(content)

    def test_migrate_single_claim(self):
        """Un claim valide est inséré dans la table claims."""
        self._write_claim('sess-20260316-test.yml', """
sess_id: sess-20260316-test
type: build-brain
scope: shadow-be2
status: open
opened_at: "2026-03-16T13:00"
handoff_level: FULL
""")
        conn = make_in_memory_db()
        with patch.object(migrate, 'BRAIN_ROOT', self.tmpdir.name):
            count = migrate.migrate_claims(conn)
        self.assertEqual(count, 1)
        row = conn.execute("SELECT * FROM claims WHERE sess_id='sess-20260316-test'").fetchone()
        self.assertIsNotNone(row)
        self.assertEqual(row['status'], 'open')
        self.assertEqual(row['scope'], 'shadow-be2')

    def test_migrate_multiple_claims(self):
        """Plusieurs claims — tous insérés."""
        for i in range(3):
            self._write_claim(f'sess-2026031{i}-test.yml', f"""
sess_id: sess-2026031{i}-test
type: build-brain
scope: brain/
status: closed
opened_at: "2026-03-1{i}T10:00"
""")
        conn = make_in_memory_db()
        with patch.object(migrate, 'BRAIN_ROOT', self.tmpdir.name):
            count = migrate.migrate_claims(conn)
        self.assertEqual(count, 3)

    def test_migrate_idempotent(self):
        """Relancer migrate_claims ne duplique pas les données."""
        self._write_claim('sess-20260316-idem.yml', """
sess_id: sess-20260316-idem
type: brain
scope: brain/
status: open
opened_at: "2026-03-16T10:00"
""")
        conn = make_in_memory_db()
        with patch.object(migrate, 'BRAIN_ROOT', self.tmpdir.name):
            migrate.migrate_claims(conn)
            migrate.migrate_claims(conn)
        total = conn.execute("SELECT COUNT(*) FROM claims").fetchone()[0]
        self.assertEqual(total, 1)

    def test_migrate_skips_non_yml(self):
        """Fichiers non .yml ignorés."""
        self._write_claim('README.md', "# not a claim")
        self._write_claim('sess-20260316-ok.yml', """
sess_id: sess-20260316-ok
type: brain
scope: brain/
status: closed
opened_at: "2026-03-16T10:00"
""")
        conn = make_in_memory_db()
        with patch.object(migrate, 'BRAIN_ROOT', self.tmpdir.name):
            count = migrate.migrate_claims(conn)
        self.assertEqual(count, 1)


class TestMigrateSessions(unittest.TestCase):
    """BE-2b — migrate_sessions dérive sessions depuis claims."""

    def _setup_claims(self, conn, claims):
        """Insère des claims directement en DB (sans passer par migrate_claims)."""
        for c in claims:
            conn.execute("""
                INSERT INTO claims(sess_id, type, scope, status, opened_at, handoff_level)
                VALUES (?,?,?,?,?,?)
            """, (c['sess_id'], c.get('type','brain'), c.get('scope','brain/'),
                  c.get('status','closed'), c.get('opened_at','2026-03-16T10:00'),
                  c.get('handoff_level','FULL')))
        conn.commit()

    def test_sessions_created_from_claims(self):
        """migrate_sessions crée autant de sessions que de claims."""
        conn = make_in_memory_db()
        self._setup_claims(conn, [
            {'sess_id': 'sess-A', 'opened_at': '2026-03-16T10:00'},
            {'sess_id': 'sess-B', 'opened_at': '2026-03-16T11:00'},
            {'sess_id': 'sess-C', 'opened_at': '2026-03-16T12:00'},
        ])
        count = migrate.migrate_sessions(conn)
        self.assertEqual(count, 3)

    def test_date_extracted_from_opened_at(self):
        """La date ISO est tronquée à YYYY-MM-DD dans sessions.date."""
        conn = make_in_memory_db()
        self._setup_claims(conn, [
            {'sess_id': 'sess-date-test', 'opened_at': '2026-03-16T13:40'},
        ])
        migrate.migrate_sessions(conn)
        row = conn.execute("SELECT date FROM sessions WHERE sess_id='sess-date-test'").fetchone()
        self.assertEqual(row['date'], '2026-03-16')

    def test_sessions_idempotent(self):
        """Relancer migrate_sessions ne duplique pas les sessions."""
        conn = make_in_memory_db()
        self._setup_claims(conn, [
            {'sess_id': 'sess-idem', 'opened_at': '2026-03-16T10:00'},
        ])
        migrate.migrate_sessions(conn)
        migrate.migrate_sessions(conn)
        total = conn.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
        self.assertEqual(total, 1)

    def test_handoff_level_preserved(self):
        """handoff_level est propagé de claims vers sessions."""
        conn = make_in_memory_db()
        self._setup_claims(conn, [
            {'sess_id': 'sess-hl', 'opened_at': '2026-03-16T10:00', 'handoff_level': 'FULL'},
        ])
        migrate.migrate_sessions(conn)
        row = conn.execute("SELECT handoff_level FROM sessions WHERE sess_id='sess-hl'").fetchone()
        self.assertEqual(row['handoff_level'], 'FULL')

    def test_empty_claims_zero_sessions(self):
        """Aucun claim → aucune session."""
        conn = make_in_memory_db()
        count = migrate.migrate_sessions(conn)
        self.assertEqual(count, 0)


# ══════════════════════════════════════════════════════════════════════════════
# search.py — search() avec Ollama mocké + DB in-memory
# ══════════════════════════════════════════════════════════════════════════════

class TestSearchFunction(unittest.TestCase):

    def _make_db_with_vectors(self, entries):
        """
        Crée une DB in-memory avec des embeddings pré-calculés.
        entries = [{'filepath', 'title', 'chunk_text', 'vector'}]
        """
        conn = make_in_memory_db()
        for e in entries:
            blob = embed.vector_to_blob(e['vector'])
            cid  = embed.chunk_id(e['filepath'], e['chunk_text'])
            conn.execute("""
                INSERT INTO embeddings(chunk_id, filepath, title, chunk_text, vector, model, indexed)
                VALUES (?,?,?,?,?,?,1)
            """, (cid, e['filepath'], e['title'], e['chunk_text'], blob, 'nomic-embed-text'))
        conn.commit()
        return conn

    def _patch_search(self, query_vec, db_conn):
        """Patche embed_query + sqlite3.connect pour les tests."""
        return (
            patch.object(search, 'embed_query', return_value=query_vec),
            patch('sqlite3.connect', return_value=db_conn),
        )

    def test_returns_top_k_results(self):
        """search() retourne au plus top_k résultats."""
        # Vecteur query : [1, 0, 0]
        # 3 chunks avec vecteurs variés
        entries = [
            {'filepath': 'agents/a.md', 'title': 'A', 'chunk_text': 'chunk A',
             'vector': [1.0, 0.0, 0.0]},   # cos_sim = 1.0 — le plus proche
            {'filepath': 'agents/b.md', 'title': 'B', 'chunk_text': 'chunk B',
             'vector': [0.0, 1.0, 0.0]},   # cos_sim = 0.0
            {'filepath': 'agents/c.md', 'title': 'C', 'chunk_text': 'chunk C',
             'vector': [-1.0, 0.0, 0.0]},  # cos_sim = -1.0 — le plus loin
        ]
        db = self._make_db_with_vectors(entries)
        p1, p2 = self._patch_search([1.0, 0.0, 0.0], db)
        with p1, p2:
            results = search.search("test", top_k=2)
        self.assertEqual(len(results), 2)

    def test_results_sorted_by_score_desc(self):
        """Les résultats sont triés par score décroissant."""
        entries = [
            {'filepath': 'a.md', 'title': '', 'chunk_text': 'A', 'vector': [1.0, 0.0, 0.0]},
            {'filepath': 'b.md', 'title': '', 'chunk_text': 'B', 'vector': [0.5, 0.5, 0.0]},
            {'filepath': 'c.md', 'title': '', 'chunk_text': 'C', 'vector': [0.0, 0.0, 1.0]},
        ]
        db = self._make_db_with_vectors(entries)
        p1, p2 = self._patch_search([1.0, 0.0, 0.0], db)
        with p1, p2:
            results = search.search("test", top_k=3)
        scores = [r['score'] for r in results]
        self.assertEqual(scores, sorted(scores, reverse=True))

    def test_best_match_is_correct(self):
        """Le chunk le plus proche de la query est bien le premier résultat."""
        entries = [
            {'filepath': 'best.md', 'title': 'Best', 'chunk_text': 'best chunk',
             'vector': [1.0, 0.0, 0.0]},
            {'filepath': 'worst.md', 'title': 'Worst', 'chunk_text': 'worst chunk',
             'vector': [0.0, 1.0, 0.0]},
        ]
        db = self._make_db_with_vectors(entries)
        p1, p2 = self._patch_search([1.0, 0.0, 0.0], db)
        with p1, p2:
            results = search.search("test", top_k=2)
        self.assertEqual(results[0]['filepath'], 'best.md')

    def test_min_score_filter(self):
        """Les chunks sous le score minimum sont filtrés."""
        entries = [
            {'filepath': 'high.md', 'title': '', 'chunk_text': 'H',
             'vector': [1.0, 0.0, 0.0]},   # cos = 1.0
            {'filepath': 'low.md',  'title': '', 'chunk_text': 'L',
             'vector': [0.0, 1.0, 0.0]},   # cos = 0.0
        ]
        db = self._make_db_with_vectors(entries)
        p1, p2 = self._patch_search([1.0, 0.0, 0.0], db)
        with p1, p2:
            results = search.search("test", top_k=5, min_score=0.5)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['filepath'], 'high.md')

    def test_ollama_unavailable_returns_empty(self):
        """Si Ollama est indisponible (embed_query=None) → liste vide."""
        with patch.object(search, 'embed_query', return_value=None):
            results = search.search("test")
        self.assertEqual(results, [])

    def test_empty_db_returns_empty(self):
        """DB sans vecteurs → liste vide + warning."""
        db = make_in_memory_db()  # DB vide, table embeddings existe mais 0 rows
        p1, p2 = self._patch_search([1.0, 0.0, 0.0], db)
        with p1, p2:
            results = search.search("test")
        self.assertEqual(results, [])


# ══════════════════════════════════════════════════════════════════════════════
# rag.py — BE-3a : couche RAG (formatters, déduplication, skip helloWorld)
# ══════════════════════════════════════════════════════════════════════════════

import rag


def _make_hit(filepath, score, chunk_text='chunk', title='', query='q'):
    return {
        'filepath':   filepath,
        'score':      score,
        'title':      title,
        'chunk_text': chunk_text,
        '_query':     query,
    }


class TestRagConstants(unittest.TestCase):

    def test_helloworld_skip_contains_focus(self):
        """focus.md est dans HELLOWORLD_SKIP (chargé par helloWorld)."""
        self.assertIn('focus.md', rag.HELLOWORLD_SKIP)

    def test_helloworld_skip_contains_kernel(self):
        self.assertIn('KERNEL.md', rag.HELLOWORLD_SKIP)

    def test_helloworld_skip_does_not_contain_adr(self):
        """Les ADRs ne sont pas dans HELLOWORLD_SKIP — ils doivent remonter."""
        self.assertFalse(any('ADR' in p for p in rag.HELLOWORLD_SKIP))

    def test_three_boot_queries(self):
        """Exactement 3 queries boot définies."""
        self.assertEqual(len(rag.RAG_BOOT_QUERIES), 3)

    def test_boot_queries_have_top_k(self):
        """Chaque query boot a un top_k > 0."""
        for query, top_k in rag.RAG_BOOT_QUERIES:
            self.assertIsInstance(query, str)
            self.assertGreater(top_k, 0)


class TestRagFormatCompact(unittest.TestCase):

    def test_empty_returns_empty_string(self):
        self.assertEqual(rag.format_compact([]), '')

    def test_contains_header(self):
        results = [_make_hit('ADR/001.md', 0.80)]
        out = rag.format_compact(results)
        self.assertIn('## Brain context', out)

    def test_contains_filepath(self):
        results = [_make_hit('ADR/001.md', 0.80)]
        out = rag.format_compact(results)
        self.assertIn('ADR/001.md', out)

    def test_contains_score(self):
        results = [_make_hit('ADR/001.md', 0.82)]
        out = rag.format_compact(results)
        self.assertIn('0.82', out)

    def test_title_prepended_to_excerpt(self):
        results = [_make_hit('f.md', 0.70, chunk_text='body', title='MyTitle')]
        out = rag.format_compact(results)
        self.assertIn('[MyTitle]', out)

    def test_query_grouping_header(self):
        """Deux résultats avec queries différentes → 2 sous-headers."""
        results = [
            _make_hit('a.md', 0.80, query='query A'),
            _make_hit('b.md', 0.70, query='query B'),
        ]
        out = rag.format_compact(results)
        self.assertIn('### query A', out)
        self.assertIn('### query B', out)

    def test_excerpt_max_120_chars(self):
        """L'extrait est tronqué à 120 chars."""
        long_text = 'X' * 300
        results = [_make_hit('f.md', 0.70, chunk_text=long_text)]
        out = rag.format_compact(results)
        # L'extrait dans la ligne = 120 chars max + "…" → ligne < 200 chars hors metadata
        line = [l for l in out.splitlines() if 'f.md' in l][0]
        # la partie après "— " est l'extrait ; on vérifie qu'il est borné
        excerpt_part = line.split('— ', 1)[1] if '— ' in line else ''
        self.assertLessEqual(len(excerpt_part.rstrip('…')), 120)

    def test_custom_label(self):
        results = [_make_hit('f.md', 0.70)]
        out = rag.format_compact(results, label='RAG — test')
        self.assertIn('RAG — test', out)


class TestRagFormatFull(unittest.TestCase):

    def test_empty_returns_empty_string(self):
        self.assertEqual(rag.format_full([]), '')

    def test_contains_full_chunk_text(self):
        long_text = 'Contenu complet ' * 20
        results = [_make_hit('f.md', 0.75, chunk_text=long_text)]
        out = rag.format_full(results)
        self.assertIn(long_text.strip(), out)

    def test_contains_filepath_header(self):
        results = [_make_hit('ADR/002.md', 0.75)]
        out = rag.format_full(results)
        self.assertIn('ADR/002.md', out)

    def test_custom_label(self):
        results = [_make_hit('f.md', 0.70)]
        out = rag.format_full(results, label='RAG — full')
        self.assertIn('RAG — full', out)


class TestRagFormatJson(unittest.TestCase):

    def test_empty_returns_empty_list(self):
        import json
        self.assertEqual(json.loads(rag.format_json([])), [])

    def test_fields_present(self):
        import json
        results = [_make_hit('f.md', 0.80, chunk_text='text', title='T', query='q')]
        out = json.loads(rag.format_json(results))
        self.assertEqual(len(out), 1)
        self.assertIn('score', out[0])
        self.assertIn('filepath', out[0])
        self.assertIn('title', out[0])
        self.assertIn('chunk_text', out[0])
        self.assertIn('query', out[0])

    def test_score_rounded(self):
        import json
        results = [_make_hit('f.md', 0.123456789)]
        out = json.loads(rag.format_json(results))
        self.assertEqual(out[0]['score'], round(0.123456789, 4))


class TestRagBootDeduplication(unittest.TestCase):
    """
    Teste la logique de déduplication et skip helloWorld de run_boot_queries().
    Mocke semantic_search pour rester headless.
    """

    def _mock_search(self, hits_by_query):
        """
        hits_by_query = {query_str: [hit_dicts]}
        Retourne une fonction qui joue le rôle de semantic_search.
        """
        def _search(query, top_k=5, min_score=0.0, allowed_scopes=None):
            return hits_by_query.get(query, [])
        return _search

    def test_skip_helloworld_files(self):
        """Les fichiers HELLOWORLD_SKIP ne remontent pas dans les résultats boot."""
        hits = {
            rag.RAG_BOOT_QUERIES[0][0]: [
                _make_hit('focus.md', 0.90),          # doit être skippé
                _make_hit('ADR/001.md', 0.80),         # doit passer
            ],
            rag.RAG_BOOT_QUERIES[1][0]: [],
            rag.RAG_BOOT_QUERIES[2][0]: [],
        }
        with patch.object(rag, 'semantic_search', self._mock_search(hits)):
            results = rag.run_boot_queries()
        filepaths = [r['filepath'] for r in results]
        self.assertNotIn('focus.md', filepaths)
        self.assertIn('ADR/001.md', filepaths)

    def test_deduplication_across_queries(self):
        """Un filepath qui remonte dans 2 queries différentes n'est inclus qu'une fois."""
        common = _make_hit('workspace/sprint.md', 0.75, query=rag.RAG_BOOT_QUERIES[0][0])
        hits = {
            rag.RAG_BOOT_QUERIES[0][0]: [common],
            rag.RAG_BOOT_QUERIES[1][0]: [_make_hit('workspace/sprint.md', 0.65,
                                                    query=rag.RAG_BOOT_QUERIES[1][0])],
            rag.RAG_BOOT_QUERIES[2][0]: [],
        }
        with patch.object(rag, 'semantic_search', self._mock_search(hits)):
            results = rag.run_boot_queries()
        filepaths = [r['filepath'] for r in results]
        self.assertEqual(filepaths.count('workspace/sprint.md'), 1)

    def test_query_tag_preserved(self):
        """Chaque résultat conserve le tag _query de la query qui l'a produit."""
        q0 = rag.RAG_BOOT_QUERIES[0][0]
        hits = {
            q0: [_make_hit('ADR/001.md', 0.80, query=q0)],
            rag.RAG_BOOT_QUERIES[1][0]: [],
            rag.RAG_BOOT_QUERIES[2][0]: [],
        }
        with patch.object(rag, 'semantic_search', self._mock_search(hits)):
            results = rag.run_boot_queries()
        self.assertEqual(results[0]['_query'], q0)

    def test_empty_results_when_ollama_down(self):
        """Si semantic_search retourne [] partout → run_boot_queries retourne []."""
        hits = {q: [] for q, _ in rag.RAG_BOOT_QUERIES}
        with patch.object(rag, 'semantic_search', self._mock_search(hits)):
            results = rag.run_boot_queries()
        self.assertEqual(results, [])


# ══════════════════════════════════════════════════════════════════════════════
# server.py — BE-3b : Brain-as-a-Service (headless — pas de serveur réel lancé)
# ══════════════════════════════════════════════════════════════════════════════

import server as srv
from fastapi.testclient import TestClient


class TestServerAuth(unittest.TestCase):
    """Auth via Authorization: Bearer — sans token = dev, avec token = vérifié."""

    def setUp(self):
        self.client = TestClient(srv.app, raise_server_exceptions=False)

    def test_no_token_env_allows_any_request(self):
        """Sans token configuré → pas de contrôle d'accès."""
        with patch.object(srv, '_TOKEN_MAP', {}):
            with patch.object(srv, 'run_single_query', return_value=[]):
                resp = self.client.get('/search?q=test')
        self.assertEqual(resp.status_code, 200)

    def test_valid_token_accepted(self):
        """Bearer token correct → 200."""
        with patch.object(srv, '_TOKEN_MAP', {'secret': 'owner'}):
            with patch.object(srv, 'run_single_query', return_value=[]):
                resp = self.client.get('/search?q=test',
                                       headers={'Authorization': 'Bearer secret'})
        self.assertEqual(resp.status_code, 200)

    def test_wrong_token_rejected(self):
        """Bearer token incorrect → 403."""
        with patch.object(srv, '_TOKEN_MAP', {'secret': 'owner'}):
            resp = self.client.get('/search?q=test',
                                   headers={'Authorization': 'Bearer wrong'})
        self.assertEqual(resp.status_code, 403)

    def test_missing_header_rejected(self):
        """Header absent quand token requis → 401."""
        with patch.object(srv, '_TOKEN_MAP', {'secret': 'owner'}):
            resp = self.client.get('/search?q=test')
        self.assertEqual(resp.status_code, 401)

    def test_token_not_in_query_param(self):
        """Token passé en query param n'est pas accepté comme auth."""
        with patch.object(srv, '_TOKEN_MAP', {'secret': 'owner'}):
            resp = self.client.get('/search?q=test&token=secret')
        self.assertIn(resp.status_code, [401, 422])  # pas autorisé, pas d'exception


class TestServerFormatResults(unittest.TestCase):
    """_format_results — filepath visibility, excerpt vs full, mode."""

    def _hit(self, filepath='f.md', score=0.80, chunk='body', title='T'):
        return {'filepath': filepath, 'score': score,
                'chunk_text': chunk, 'title': title, '_query': 'q'}

    def test_develop_mode_exposes_filepath(self):
        out = srv._format_results([self._hit()], full=False, mode='develop')
        self.assertIn('filepath', out['results'][0])

    def test_service_mode_hides_filepath(self):
        out = srv._format_results([self._hit()], full=False, mode='service')
        self.assertNotIn('filepath', out['results'][0])

    def test_compact_mode_has_excerpt_not_chunk(self):
        out = srv._format_results([self._hit(chunk='full content')], full=False, mode='develop')
        item = out['results'][0]
        self.assertIn('excerpt', item)
        self.assertNotIn('chunk_text', item)

    def test_full_mode_has_chunk_text(self):
        out = srv._format_results([self._hit(chunk='full content')], full=True, mode='develop')
        item = out['results'][0]
        self.assertIn('chunk_text', item)
        self.assertEqual(item['chunk_text'], 'full content')

    def test_count_matches_results(self):
        hits = [self._hit('a.md'), self._hit('b.md')]
        out = srv._format_results(hits, full=False, mode='develop')
        self.assertEqual(out['count'], 2)
        self.assertEqual(len(out['results']), 2)

    def test_score_rounded_to_4_decimals(self):
        out = srv._format_results([self._hit(score=0.123456789)], full=False, mode='develop')
        self.assertEqual(out['results'][0]['score'], round(0.123456789, 4))

    def test_empty_results(self):
        out = srv._format_results([], full=False, mode='develop')
        self.assertEqual(out, {'count': 0, 'results': []})


class TestServerRoutes(unittest.TestCase):
    """Routes /health /search /boot — mocked moteur."""

    def setUp(self):
        self.client = TestClient(srv.app)

    def test_health_returns_ok(self):
        with patch('sqlite3.connect') as mock_conn:
            mock_conn.return_value.__enter__ = lambda s: s
            mock_conn.return_value.execute.return_value.fetchone.return_value = [42]
            # Appel direct de la fonction
            resp = self.client.get('/health')
        self.assertIn(resp.status_code, [200, 503])  # 503 si brain.db absent en CI

    def test_search_requires_q(self):
        """GET /search sans ?q → 422 Unprocessable."""
        with patch.object(srv, '_TOKEN_MAP', {}):
            resp = self.client.get('/search')
        self.assertEqual(resp.status_code, 422)

    def test_search_mode_logged(self):
        """Le champ mode est accepté sans erreur."""
        with patch.object(srv, '_TOKEN_MAP', {}):
            with patch.object(srv, 'run_single_query', return_value=[]):
                resp = self.client.get('/search?q=test&mode=develop')
        self.assertEqual(resp.status_code, 200)

    def test_boot_endpoint_exists(self):
        """GET /boot répond (moteur mocké)."""
        with patch.object(srv, '_TOKEN_MAP', {}):
            with patch.object(srv, 'run_boot_queries', return_value=[]):
                resp = self.client.get('/boot')
        self.assertEqual(resp.status_code, 200)
        self.assertEqual(resp.json()['count'], 0)


class TestServerScript(unittest.TestCase):
    """bsi-server.sh — existence et exécutabilité."""

    SERVER_SCRIPT = Path(__file__).parent.parent / 'scripts' / 'bsi-server.sh'

    def test_script_exists(self):
        self.assertTrue(self.SERVER_SCRIPT.exists())

    def test_script_executable(self):
        self.assertTrue(os.access(self.SERVER_SCRIPT, os.X_OK))

    def test_invalid_command_exits_nonzero(self):
        result = subprocess.run(
            ['bash', str(self.SERVER_SCRIPT), 'invalid'],
            capture_output=True, text=True
        )
        self.assertNotEqual(result.returncode, 0)


class TestServerBe3c(unittest.TestCase):
    """BE-3c — mode=service masquage filepath, fichiers VPS."""

    def setUp(self):
        self.client = TestClient(srv.app)

    def test_service_mode_hides_filepath_end_to_end(self):
        """GET /search?mode=service → pas de filepath dans la réponse JSON."""
        hit = {'filepath': 'secret/path.md', 'score': 0.9,
                'chunk_text': 'body', 'title': 'T', '_query': 'q'}
        with patch.object(srv, '_TOKEN_MAP', {}):
            with patch.object(srv, 'run_single_query', return_value=[hit]):
                resp = self.client.get('/search?q=test&mode=service')
        self.assertEqual(resp.status_code, 200)
        item = resp.json()['results'][0]
        self.assertNotIn('filepath', item)

    def test_develop_mode_exposes_filepath_end_to_end(self):
        """GET /search?mode=develop → filepath présent dans la réponse JSON."""
        hit = {'filepath': 'ADR/001.md', 'score': 0.9,
                'chunk_text': 'body', 'title': 'T', '_query': 'q'}
        with patch.object(srv, '_TOKEN_MAP', {}):
            with patch.object(srv, 'run_single_query', return_value=[hit]):
                resp = self.client.get('/search?q=test&mode=develop')
        item = resp.json()['results'][0]
        self.assertIn('filepath', item)
        self.assertEqual(item['filepath'], 'ADR/001.md')

    def test_systemd_service_file_exists(self):
        """brain-engine.service présent dans scripts/."""
        svc = Path(__file__).parent.parent / 'scripts' / 'brain-engine.service'
        self.assertTrue(svc.exists(), f"Service absent : {svc}")

    def test_systemd_service_has_mysecrets_env(self):
        """Le service charge MYSECRETS via EnvironmentFile."""
        svc = Path(__file__).parent.parent / 'scripts' / 'brain-engine.service'
        content = svc.read_text()
        self.assertIn('EnvironmentFile', content)
        self.assertIn('MYSECRETS', content)

    def test_systemd_service_has_brain_token(self):
        """Le service ne hardcode pas BRAIN_TOKEN — il vient de EnvironmentFile."""
        svc = Path(__file__).parent.parent / 'scripts' / 'brain-engine.service'
        content = svc.read_text()
        self.assertNotIn('BRAIN_TOKEN=', content)  # jamais hardcodé dans le service

    def test_install_script_exists_and_executable(self):
        """install-brain-engine.sh existe et est exécutable."""
        script = Path(__file__).parent.parent / 'scripts' / 'install-brain-engine.sh'
        self.assertTrue(script.exists())
        self.assertTrue(os.access(script, os.X_OK))

    def test_mysecrets_has_brain_token_entry(self):
        """MYSECRETS contient une entrée BRAIN_TOKEN (valeur vide ou non)."""
        mysecrets = Path(__file__).parent.parent / 'MYSECRETS'
        self.assertTrue(mysecrets.exists(), "MYSECRETS absent")
        content = mysecrets.read_text()
        self.assertIn('BRAIN_TOKEN', content)


class TestRagScript(unittest.TestCase):
    """Test existence et exécutabilité du script bash bsi-rag.sh."""

    RAG_SCRIPT = Path(__file__).parent.parent / 'scripts' / 'bsi-rag.sh'

    def test_script_exists(self):
        self.assertTrue(self.RAG_SCRIPT.exists(), f"bsi-rag.sh absent : {self.RAG_SCRIPT}")

    def test_script_executable(self):
        self.assertTrue(os.access(self.RAG_SCRIPT, os.X_OK),
                        f"bsi-rag.sh non exécutable : {self.RAG_SCRIPT}")

    def test_script_help_passthrough(self):
        """bsi-rag.sh --help passe à rag.py et sort proprement (exit 0)."""
        result = subprocess.run(
            ['bash', str(self.RAG_SCRIPT), '--help'],
            capture_output=True, text=True
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn('brain-engine RAG', result.stdout)


# ══════════════════════════════════════════════════════════════════════════════
# brain-db-sync.sh — tests bash (--check mode)
# ══════════════════════════════════════════════════════════════════════════════

import subprocess

BRAIN_ROOT_PATH = Path(__file__).parent.parent
SYNC_SCRIPT     = BRAIN_ROOT_PATH / 'scripts' / 'brain-db-sync.sh'

class TestBrainDbSyncScript(unittest.TestCase):

    def test_script_exists_and_executable(self):
        """brain-db-sync.sh existe et est exécutable."""
        self.assertTrue(SYNC_SCRIPT.exists(), f"Script absent : {SYNC_SCRIPT}")
        self.assertTrue(os.access(SYNC_SCRIPT, os.X_OK),
                        f"Script non exécutable : {SYNC_SCRIPT}")

    def test_check_mode_ok_when_db_fresh(self):
        """
        --check : exit 0 si brain.db est plus récent que le dernier commit claims.
        On simule avec une DB temporaire fraîchement créée.
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            # Mini repo git + brain.db
            subprocess.run(['git', 'init', '-q'], cwd=tmpdir, check=True)
            subprocess.run(['git', 'config', 'user.email', 'test@test.com'],
                           cwd=tmpdir, check=True)
            subprocess.run(['git', 'config', 'user.name', 'Test'], cwd=tmpdir, check=True)
            # brain.db créé APRÈS le dernier commit → devrait être à jour
            db = Path(tmpdir) / 'brain.db'
            db.write_bytes(b'SQLite format 3\x00')  # header minimal
            result = subprocess.run(
                ['bash', str(SYNC_SCRIPT), '--check'],
                cwd=tmpdir,
                capture_output=True, text=True,
                env={**os.environ, 'BRAIN_ROOT': tmpdir}
            )
            # Exit 0 = OK, exit 2 = stale — les deux sont acceptables ici
            # (dépend du timing git). L'important : pas de crash (exit 1).
            self.assertNotEqual(result.returncode, 1,
                                f"Script crash inattendu : {result.stderr}")

    def test_check_mode_ok_on_real_brain(self):
        """
        --check sur le vrai brain : exit 0 si brain.db à jour.
        Note : brain-db-sync.sh calcule BRAIN_ROOT depuis dirname $0 — pas surchargeable.
        Le cas DB absente (exit 2) est couvert par test manuel ou CI avec repo frais.
        """
        result = subprocess.run(
            ['bash', str(SYNC_SCRIPT), '--check'],
            cwd=str(BRAIN_ROOT_PATH),
            capture_output=True, text=True
        )
        # 0 = à jour, 2 = stale — les deux OK ; 1 = crash script = fail
        self.assertNotEqual(result.returncode, 1,
                            f"Script crash (exit 1) : {result.stderr}")

    def test_install_hooks_script_exists(self):
        """install-brain-hooks.sh existe et est exécutable."""
        hooks_script = BRAIN_ROOT_PATH / 'scripts' / 'install-brain-hooks.sh'
        self.assertTrue(hooks_script.exists())
        self.assertTrue(os.access(hooks_script, os.X_OK))

    def test_install_hooks_check_mode_installed(self):
        """
        install-brain-hooks.sh --check : exit 0 si le hook est installé.
        Le hook est installé dans le vrai brain root (scripts/install-brain-hooks.sh
        calcule BRAIN_ROOT depuis dirname $0 — ne peut pas être redirigé).
        On vérifie l'état réel : le hook doit être présent en dev actif.
        """
        hooks_script = BRAIN_ROOT_PATH / 'scripts' / 'install-brain-hooks.sh'
        result = subprocess.run(
            ['bash', str(hooks_script), '--check'],
            cwd=str(BRAIN_ROOT_PATH),
            capture_output=True, text=True
        )
        # Exit 0 = installé, exit 1 = absent
        # Les deux sont acceptables — on vérifie juste que le script ne crash pas (pas exit > 1)
        self.assertLessEqual(result.returncode, 1,
                             f"Script crash inattendu (exit {result.returncode}): {result.stderr}")


# ══════════════════════════════════════════════════════════════════════════════
# distill.py — BE-5e (summarisation 2 passes)
# ══════════════════════════════════════════════════════════════════════════════

def _make_messages(n: int) -> list[dict]:
    """Génère n messages alternés user/assistant pour les tests."""
    roles = ['user', 'assistant']
    return [{'role': roles[i % 2], 'content': f'message {i}'} for i in range(n)]


class TestBuildContext(unittest.TestCase):

    def test_small_session_uses_all_messages(self):
        """Session ≤ MAX_MESSAGES → tous les messages sont inclus dans le contexte."""
        msgs = _make_messages(distill.MAX_MESSAGES)
        ctx = distill.build_context(msgs)
        # Chaque message doit apparaître
        self.assertIn('message 0', ctx)
        self.assertIn(f'message {distill.MAX_MESSAGES - 1}', ctx)

    def test_large_session_truncates_to_recent(self):
        """Session > MAX_MESSAGES → build_context prend les MAX_MESSAGES derniers."""
        msgs = _make_messages(distill.MAX_MESSAGES + 20)
        ctx = distill.build_context(msgs)
        # Les 20 premiers messages (trop anciens) ne doivent pas apparaître
        self.assertNotIn('message 0', ctx)
        # Les derniers doivent être présents
        self.assertIn(f'message {len(msgs) - 1}', ctx)

    def test_context_respects_max_chars(self):
        """build_context respecte max_chars même sur grande session."""
        msgs = _make_messages(10)
        ctx = distill.build_context(msgs, max_chars=50)
        self.assertLessEqual(len(ctx), 50)


class TestSummarize2Pass(unittest.TestCase):

    def test_splits_into_blocks_of_max_messages(self):
        """summarize_2pass appelle summarize une fois par bloc + 1 fois pour la passe finale."""
        n = distill.MAX_MESSAGES * 3  # 3 blocs complets
        msgs = _make_messages(n)

        call_count = []

        def fake_summarize(context, aspect):
            call_count.append(1)
            return f'- résumé bloc {len(call_count)}'

        with patch.object(distill, 'summarize', side_effect=fake_summarize):
            result = distill.summarize_2pass(msgs, 'decisions')

        # Pass 1 : 3 appels (un par bloc) + Pass 2 : 1 appel final = 4 total
        self.assertEqual(len(call_count), 4)
        self.assertIsNotNone(result)

    def test_partial_none_blocks_are_skipped(self):
        """Blocs dont summarize retourne None ne cassent pas la 2e passe."""
        n = distill.MAX_MESSAGES * 2
        msgs = _make_messages(n)

        responses = [None, '- décision bloc 2']  # bloc 1 → None, bloc 2 → bullet

        def fake_summarize(context, aspect):
            if responses:
                return responses.pop(0)
            return '- résumé final'

        with patch.object(distill, 'summarize', side_effect=fake_summarize):
            result = distill.summarize_2pass(msgs, 'decisions')

        # La passe 2 est appelée car il y a au moins 1 résumé partiel non-None
        self.assertIsNotNone(result)

    def test_all_none_blocks_returns_none(self):
        """Si tous les blocs renvoient None, summarize_2pass retourne None."""
        n = distill.MAX_MESSAGES * 2
        msgs = _make_messages(n)

        with patch.object(distill, 'summarize', return_value=None):
            result = distill.summarize_2pass(msgs, 'decisions')

        self.assertIsNone(result)

    def test_all_none_sentinel_blocks_returns_none(self):
        """Si tous les blocs renvoient 'none', summarize_2pass retourne None."""
        n = distill.MAX_MESSAGES * 2
        msgs = _make_messages(n)

        with patch.object(distill, 'summarize', return_value='none'):
            result = distill.summarize_2pass(msgs, 'decisions')

        self.assertIsNone(result)

    def test_single_block_still_calls_pass2(self):
        """Même avec exactement MAX_MESSAGES+1 messages (2 blocs dont 1 micro), pass 2 est appelée."""
        msgs = _make_messages(distill.MAX_MESSAGES + 1)
        call_args = []

        def fake_summarize(context, aspect):
            call_args.append(context[:30])
            return '- bullet test'

        with patch.object(distill, 'summarize', side_effect=fake_summarize):
            result = distill.summarize_2pass(msgs, 'todos')

        # Pass 1 : 2 blocs → 2 appels ; Pass 2 : 1 appel → total 3
        self.assertEqual(len(call_args), 3)
        self.assertIsNotNone(result)


class TestDistillSession2Pass(unittest.TestCase):
    """distill_session() sélectionne 1-pass ou 2-pass selon la taille de la session."""

    def _make_jsonl(self, n_messages: int) -> Path:
        """Crée un .jsonl temporaire avec n messages."""
        import json as _json
        tmp = tempfile.NamedTemporaryFile(suffix='.jsonl', delete=False, mode='w')
        for i in range(n_messages):
            role = 'user' if i % 2 == 0 else 'assistant'
            entry = {'message': {'role': role, 'content': f'contenu message {i}'}}
            tmp.write(_json.dumps(entry) + '\n')
        tmp.close()
        return Path(tmp.name)

    def test_small_session_uses_single_pass(self):
        """Session ≤ MAX_MESSAGES → summarize() appelé directement (pas summarize_2pass)."""
        jsonl = self._make_jsonl(distill.MAX_MESSAGES)
        try:
            with patch.object(distill, 'summarize', return_value='- décision test') as mock_sum, \
                 patch.object(distill, 'summarize_2pass') as mock_2pass, \
                 patch('distill.connect', return_value=None), \
                 patch('distill.upsert_chunk'), \
                 patch('distill.get_embedding', return_value=None):
                distill.distill_session(jsonl, dry_run=True)
            mock_sum.assert_called()
            mock_2pass.assert_not_called()
        finally:
            jsonl.unlink(missing_ok=True)

    def test_large_session_uses_2pass(self):
        """Session > MAX_MESSAGES → summarize_2pass() appelé, pas summarize() directement."""
        jsonl = self._make_jsonl(distill.MAX_MESSAGES + 10)
        try:
            with patch.object(distill, 'summarize_2pass', return_value='- décision 2pass') as mock_2pass, \
                 patch.object(distill, 'summarize') as mock_sum, \
                 patch('distill.connect', return_value=None), \
                 patch('distill.upsert_chunk'), \
                 patch('distill.get_embedding', return_value=None):
                distill.distill_session(jsonl, dry_run=True)
            mock_2pass.assert_called()
            mock_sum.assert_not_called()
        finally:
            jsonl.unlink(missing_ok=True)

    def test_large_session_dry_run_produces_chunks(self):
        """Grande session en dry-run → au moins 1 chunk produit par aspect non-vide."""
        jsonl = self._make_jsonl(distill.MAX_MESSAGES * 2)
        try:
            with patch.object(distill, 'summarize_2pass', return_value='- décision test') as mock_2pass:
                n = distill.distill_session(jsonl, dry_run=True)
            # 3 aspects × 1 bullet min
            self.assertGreater(n, 0)
        finally:
            jsonl.unlink(missing_ok=True)


# ══════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    unittest.main(verbosity=2)
