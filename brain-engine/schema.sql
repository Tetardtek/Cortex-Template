-- brain-engine/schema.sql — Brain State Engine (BE-1)
-- Source de vérité : les .md restent souverains.
-- Ce schema est un INDEX QUERYABLE dérivé depuis les fichiers.
-- brain.db = lecture seule sur le brain — jamais d'écriture sur les .md.
--
-- Ref : ADR-012 (L3a), ADR-011 (autonomie), workspace/brain-engine/vision.md
-- Migration : brain-engine/migrate.py

PRAGMA journal_mode=WAL;  -- Concurrent reads safe (multi-sessions)
PRAGMA foreign_keys=ON;

-- ── Claims BSI ───────────────────────────────────────────────────────────────
-- ADR-036 : source de vérité BSI — claims/*.yml migrent ici
CREATE TABLE IF NOT EXISTS claims (
    sess_id         TEXT PRIMARY KEY,
    type            TEXT NOT NULL,              -- brainstorm | work | deploy | debug | coach | brain
    scope           TEXT NOT NULL,              -- ex: brain/memory-sql
    status          TEXT NOT NULL DEFAULT 'open',  -- open | closed | stale
    opened_at       TEXT NOT NULL,              -- ISO8601
    closed_at       TEXT,                       -- ISO8601 — null si encore open
    handoff_level   TEXT,                       -- NO | SEMI | SEMI+ | FULL
    story_angle     TEXT,                       -- angle narratif optionnel
    health_score    REAL,                       -- alimenté par metabolism-scribe au close
    context_at_close INTEGER,                   -- % context utilisé au close
    cold_start_kpi_pass INTEGER,                -- 1=true 0=false NULL=non mesuré
    -- BSI v3 fields (ADR-036)
    ttl_hours       INTEGER DEFAULT 4,          -- TTL par défaut deep work
    expires_at      TEXT,                       -- ISO8601 — calculé au boot
    instance        TEXT,                       -- brain_name@machine
    parent_sess     TEXT,                       -- parent_satellite
    satellite_type  TEXT,                       -- code|brain-write|test|deploy|search|domain
    satellite_level TEXT,                       -- leaf|domain
    theme_branch    TEXT,                       -- theme/<nom>
    zone            TEXT,                       -- kernel|project|personal (inféré)
    mode            TEXT,                       -- rendering|pilote|etc.
    result_status   TEXT,                       -- success|partial|fail
    result_json     TEXT,                       -- {files_modified, tests, children, signal_id}
    CHECK(status IN ('open', 'closed', 'stale')),
    CHECK(handoff_level IN ('NO', 'SEMI', 'SEMI+', 'FULL', NULL))
);

-- ── Locks BSI (ADR-036 — ex file-lock.sh) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS locks (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    filepath        TEXT NOT NULL UNIQUE,       -- chemin normalisé (ex: agents/foo.md)
    holder          TEXT NOT NULL,              -- sess_id détenteur
    claimed_at      TEXT NOT NULL DEFAULT (datetime('now')),  -- ISO8601
    expires_at      TEXT NOT NULL,              -- ISO8601
    ttl_min         INTEGER NOT NULL DEFAULT 60
);

-- ── Circuit breaker BSI (ADR-036) ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS circuit_breaker (
    sess_id         TEXT PRIMARY KEY,
    fail_count      INTEGER NOT NULL DEFAULT 0,
    last_fail_at    TEXT,                       -- ISO8601
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ── Signaux inter-sessions ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS signals (
    sig_id          TEXT PRIMARY KEY,           -- sig-YYYYMMDD-<seq>
    from_sess       TEXT,                       -- sess_id source
    to_sess         TEXT NOT NULL,              -- sess_id cible ou brain_name@machine
    type            TEXT NOT NULL,              -- READY_FOR_REVIEW | REVIEWED | BLOCKED_ON | HANDOFF | CHECKPOINT | INFO
    projet          TEXT,
    payload         TEXT,                       -- description ou chemin handoff file
    state           TEXT NOT NULL DEFAULT 'pending',  -- pending | delivered | archived
    created_at      TEXT NOT NULL,              -- ISO8601
    delivered_at    TEXT,
    CHECK(type IN ('READY_FOR_REVIEW','REVIEWED','BLOCKED_ON','HANDOFF','CHECKPOINT','INFO')),
    CHECK(state IN ('pending','delivered','archived'))
);

-- ── Handoffs ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS handoffs (
    filename        TEXT PRIMARY KEY,           -- handoffs/<nom>.md
    type            TEXT,                       -- CHECKPOINT | HANDOFF | FEEDBACK
    projet          TEXT,
    status          TEXT NOT NULL DEFAULT 'active',  -- active | consumed | archived
    from_sess       TEXT,
    consumed_by     TEXT,                       -- sess_id qui a consommé ce handoff
    created_at      TEXT NOT NULL,
    consumed_at     TEXT,
    CHECK(status IN ('active','consumed','archived'))
);

-- ── Mémoire agents L3a ────────────────────────────────────────────────────────
-- Alimenté par metabolism-scribe via kpi.yml dans agent-memory/<agent>/<projet>/
CREATE TABLE IF NOT EXISTS agent_memory (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    agent           TEXT NOT NULL,              -- ex: tech-lead, debug, vps
    projet          TEXT NOT NULL,              -- slug projet
    stack           TEXT NOT NULL,              -- ex: node-express-jwt
    pattern_id      TEXT NOT NULL,              -- slug du pattern
    validations     INTEGER NOT NULL DEFAULT 0, -- sessions où le pattern a été validé
    kpi_score       REAL NOT NULL DEFAULT 0.0,  -- 0.0 → 1.0
    graduated       INTEGER NOT NULL DEFAULT 0, -- 0=false 1=true (→ L3b toolkit)
    seuil_graduation INTEGER NOT NULL DEFAULT 3,
    last_validated  TEXT,                       -- ISO8601
    notes           TEXT,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(agent, projet, stack, pattern_id)
);

-- ── Sessions metabolism ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS sessions (
    sess_id             TEXT PRIMARY KEY,
    date                TEXT NOT NULL,
    type                TEXT,                   -- build-brain | use-brain | auto
    mode                TEXT,
    handoff_level       TEXT,
    tokens_used         INTEGER,
    context_peak_pct    INTEGER,
    context_at_close    INTEGER,
    duration_min        INTEGER,
    commits             INTEGER,
    todos_closed        INTEGER,
    saturation_flag     INTEGER,                -- 0/1
    health_score        REAL,
    cold_start_kpi_pass INTEGER,                -- 0/1/NULL
    notes               TEXT
);

-- ── Agents chargés par session ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agent_loads (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    sess_id         TEXT NOT NULL REFERENCES claims(sess_id),
    agent           TEXT NOT NULL,
    tokens_estimated INTEGER,
    loaded_at       TEXT NOT NULL DEFAULT (datetime('now')),
    reason          TEXT                        -- why it was loaded
);

-- ── Vues utilitaires ─────────────────────────────────────────────────────────

CREATE VIEW IF NOT EXISTS v_open_claims AS
    SELECT sess_id, scope, opened_at,
           ROUND((julianday('now') - julianday(opened_at)) * 24, 1) AS age_hours
    FROM claims
    WHERE status = 'open'
    ORDER BY opened_at DESC;

CREATE VIEW IF NOT EXISTS v_stale_claims AS
    SELECT sess_id, scope, opened_at,
           ROUND((julianday('now') - julianday(opened_at)) * 24, 1) AS age_hours
    FROM claims
    WHERE status = 'open'
      AND julianday('now') > julianday(opened_at, '+4 hours')
    ORDER BY age_hours DESC;

CREATE VIEW IF NOT EXISTS v_active_locks AS
    SELECT filepath, holder, claimed_at, expires_at,
           CASE WHEN julianday('now') < julianday(expires_at) THEN 'active' ELSE 'expired' END AS lock_status
    FROM locks
    ORDER BY claimed_at DESC;

CREATE VIEW IF NOT EXISTS v_graduation_candidates AS
    SELECT agent, projet, stack, pattern_id, validations, kpi_score,
           ROUND(CAST(validations AS REAL) / seuil_graduation, 2) AS progress
    FROM agent_memory
    WHERE graduated = 0
      AND validations >= seuil_graduation
    ORDER BY validations DESC;

CREATE VIEW IF NOT EXISTS v_cold_start_kpi AS
    SELECT
        COUNT(*) AS total_no_handoff,
        SUM(CASE WHEN cold_start_kpi_pass = 1 THEN 1 ELSE 0 END) AS passes,
        ROUND(
            100.0 * SUM(CASE WHEN cold_start_kpi_pass = 1 THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN cold_start_kpi_pass IS NOT NULL THEN 1 ELSE 0 END), 0),
        1) AS pass_rate_pct
    FROM sessions
    WHERE handoff_level = 'NO';

CREATE VIEW IF NOT EXISTS v_metabolism_7d AS
    SELECT
        date,
        type,
        AVG(health_score) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS health_7d_avg,
        SUM(CASE WHEN type='build-brain' THEN 1 ELSE 0 END)
            OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS build_7d,
        SUM(CASE WHEN type='use-brain' THEN 1 ELSE 0 END)
            OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS use_7d
    FROM sessions
    ORDER BY date DESC;
