#!/usr/bin/env python3
"""
brain-engine/server.py — Brain-as-a-Service BE-4
Expose la recherche sémantique via HTTP (FastAPI + uvicorn).

Usage :
  python3 brain-engine/server.py                  → port 7700 (défaut)
  BRAIN_PORT=8080 python3 brain-engine/server.py  → port custom

Tokens (MYSECRETS) :
  BRAIN_TOKEN_OWNER   → zones public + work + kernel  (toi, sessions locales)
  BRAIN_TOKEN_MCP     → zones public + work           (Claude via MCP)
  BRAIN_TOKEN_PUBLIC  → zone public seule             (bot, démo externe)
  BRAIN_TOKEN         → alias owner (compat BE-3)

Zones :
  public  → focus.md, wiki/, agents/, infrastructure/
  work    → todo/, projets/, handoffs/, workspace/
  kernel  → profil/, KERNEL.md, contexts/
  (private → jamais indexé — profil/capital.md, objectifs.md...)

Tier enforcement (has_feature) :
  free  : /search, /boot, /agents, /teams, /workflows, /workflows/create, /logs, /ws
  pro   : /visualize, /infra, PUT /brain/{path}, POST /ambient/notify (remote)
  owner : tout + POST /gate/{wf}/{step}/approve

Level 2 localhost trust (_is_localhost) :
  BSI endpoints → bypass auth + tier depuis 127.0.0.1
  Pay endpoints (visualize, infra, brain_write) → bypass tier depuis localhost (owner machine)

Endpoints :
  GET  /health                       → statut + uptime + version             [aucun]
  GET  /state                        → env fondamental dérivé (pm2+git)       [L2 only]
  GET  /boot                         → zones brain + queries initiales        [free]
  GET  /search?q=                    → RAG sémantique                         [free]
  GET  /agents                       → liste agents disponibles               [free]
  GET  /teams                        → liste team presets                     [free]
  GET  /workflows                    → claims ouverts                         [free]
  POST /workflows/create             → créer un claim BSI                     [free]
  GET  /tier                         → tier actif + feature_tier map          [aucun]
  GET  /visualize                    → coordonnées 3D UMAP                    [PRO]
  GET  /infra                        → services pm2 registry                  [PRO]
  PUT  /brain/{path}                 → écriture fichier brain + reindex       [PRO/owner]
  POST /ambient/notify               → broadcast event daemon Ambient         [PRO; localhost=free]
  POST /gate/{wf}/{step}/approve     → approuver un gate workflow             [owner]
  GET  /bsi/claims                    → liste claims BSI depuis brain.db        [free; localhost bypass]
  POST /bsi/claims                    → créer un claim BSI dans brain.db       [owner; localhost bypass]
  PATCH /bsi/claims/{sess_id}         → update claim (status, close, result)   [owner; localhost bypass]
  GET  /bsi/locks                     → liste locks actifs                     [free; localhost bypass]
  POST /bsi/locks                     → acquérir un lock fichier               [owner; localhost bypass]
  DELETE /bsi/locks/{filepath}        → libérer un lock fichier                [owner; localhost bypass]
  GET  /bsi/network                   → vue réseau BSI (peers + claims agrégés) [free; localhost bypass]
  GET  /logs/{project}               → logs projet                            [free]
  WS   /ws                           → WebSocket temps réel                   [free]
"""

import os
import sys
import re
import time
import hashlib
import json
import logging
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
import subprocess
import asyncio
from fastapi import FastAPI, Header, HTTPException, Query, Body, WebSocket, Request
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.websockets import WebSocketDisconnect

try:
    import yaml
    _YAML_AVAILABLE = True
except ImportError:
    _YAML_AVAILABLE = False

# Import moteur RAG depuis le même répertoire
sys.path.insert(0, str(Path(__file__).parent))
from rag import run_boot_queries, run_single_query

# ── Config ─────────────────────────────────────────────────────────────────────

BRAIN_PORT = int(os.getenv('BRAIN_PORT', 7700))

# Zones accessibles par tier
_SCOPE_ACCESS: dict[str, list[str]] = {
    'owner':  ['public', 'work', 'kernel'],
    'mcp':    ['public', 'work'],
    'public': ['public'],
}

# Résolution token → tier (dernière valeur gagne si conflit)
_TOKEN_MAP: dict[str, str] = {}
for _env, _tier in [
    ('BRAIN_TOKEN',        'owner'),   # compat BE-3 — alias owner
    ('BRAIN_TOKEN_OWNER',  'owner'),
    ('BRAIN_TOKEN_MCP',    'mcp'),
    ('BRAIN_TOKEN_PUBLIC', 'public'),
]:
    _val = os.getenv(_env)
    if _val:
        _TOKEN_MAP[_val] = _tier

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger('brain-engine')

FEATURE_TIER: dict[str, str] = {
    'visualize':     'pro',
    'distillation':  'pro',
    'ambient':       'pro',
    'brain_write':   'pro',
    'infra':         'pro',
    'search':        'free',
    'progression':   'free',
    'boot':          'free',
    'workflows':     'free',
    'gate_approve':  'free',
    'logs':          'free',
    'bsi':           'free',
}

TIER_RANK = {'free': 0, 'featured': 1, 'pro': 2, 'owner': 3, 'full': 3}  # chaîne: free → featured → pro → full

# ── Tier cache ──────────────────────────────────────────────────────────────────

KEYS_API   = os.getenv('BRAIN_KEYS_API', '')
TIER_TTL   = 3600          # 1h TTL normal
TIER_GRACE = 7 * 86400     # 7 jours grace offline

# { token_hash: (tier, expires_at) }
_tier_cache: dict[str, tuple[str, float]] = {}


def has_feature(feature: str, tier: str) -> bool:
    required = FEATURE_TIER.get(feature, 'owner')
    return TIER_RANK.get(tier, 0) >= TIER_RANK.get(required, 99)


def get_tier_from_request(authorization: str | None) -> str:
    """
    Résout le tier depuis le header Authorization.
    1. BRAIN_TIER env → override dev/local immédiat
    2. Pas de token → 'free'
    3. Cache valide (< 1h) → retour immédiat
    4. Validation réseau contre {KEYS_API}/validate (POST, timeout 3s)
       - 200 {"tier": ...} → cache TTL 1h
       - réseau down       → grace cache 7j ou 'free'
       - 401/403           → 'free'
    """
    # 1. Override env
    env_tier = os.getenv('BRAIN_TIER')
    if env_tier:
        return env_tier

    # 2. Extraire le token
    if not authorization or not authorization.startswith('Bearer '):
        return 'free'
    token = authorization.removeprefix('Bearer ').strip()
    if not token:
        return 'free'

    # 3. Hash token
    token_hash = hashlib.sha256(token.encode()).hexdigest()[:16]
    now = time.time()

    # 4. Cache valide ?
    if token_hash in _tier_cache:
        cached_tier, expires_at = _tier_cache[token_hash]
        if expires_at > now:
            return cached_tier

    # 5. Validation réseau
    try:
        payload = json.dumps({'key': token}).encode()
        req = urllib.request.Request(
            f'{KEYS_API}/validate',
            data=payload,
            headers={'Content-Type': 'application/json'},
            method='POST',
        )
        with urllib.request.urlopen(req, timeout=3) as resp:
            if resp.status == 200:
                data = json.loads(resp.read().decode())
                tier = data.get('tier', 'free')
                if tier == 'full':
                    tier = 'owner'  # normalise alias
                if tier not in TIER_RANK:
                    tier = 'free'
                _tier_cache[token_hash] = (tier, now + TIER_TTL)
                return tier
            else:
                # 401/403 → token invalide
                return 'free'
    except Exception as exc:
        log.warning('get_tier_from_request: network error (%s) — trying grace cache', exc)
        # Grace offline : accepter un cache expiré jusqu'à 7j
        if token_hash in _tier_cache:
            cached_tier, expires_at = _tier_cache[token_hash]
            if now - expires_at < TIER_GRACE:
                return cached_tier
        return 'free'

# Uptime tracking
_START_TIME: float = time.time()

# WebSocket clients
_ws_clients: list[WebSocket] = []

# Racine du brain (un niveau au-dessus de brain-engine/)
BRAIN_ROOT = Path(__file__).parent.parent

app = FastAPI(title='Brain-as-a-Service', version='BE-4', docs_url='/api-docs')

# ── Montage brain-ui static (si build disponible) ────────────────────────────

_UI_DIST = BRAIN_ROOT / 'brain-ui' / 'dist'
if _UI_DIST.is_dir():
    from fastapi.staticfiles import StaticFiles
    app.mount('/ui', StaticFiles(directory=str(_UI_DIST), html=True), name='brain-ui')
    log.info('brain-ui monté sur /ui depuis %s', _UI_DIST)


# ── Level 2 — localhost frictionless ───────────────────────────────────────────

def _is_localhost(request: Request) -> bool:
    """True si la requête vient de localhost — Level 2 agents (frictionless).
    Si X-Forwarded-For présent → vient d'Apache proxy → pas localhost trust.
    """
    if request is None:
        return False
    if request.headers.get('x-forwarded-for'):
        return False
    client_host = request.client.host if request.client else ''
    result = client_host in ('127.0.0.1', '::1', 'localhost')
    if result:
        log.debug('level2 local bypass: %s', request.url.path)
    return result


# ── Auth ───────────────────────────────────────────────────────────────────────

def check_auth(authorization: str | None) -> list[str]:
    """
    Vérifie le header Authorization: Bearer <token>.
    Retourne la liste des scopes autorisés pour ce token.
    Si aucun token configuré : auth désactivée (dev local) → accès total.
    """
    if not _TOKEN_MAP:
        return ['public', 'work', 'kernel']  # dev local — accès total
    if not authorization or not authorization.startswith('Bearer '):
        raise HTTPException(status_code=401, detail='Authorization header requis')
    token = authorization.removeprefix('Bearer ').strip()
    tier  = _TOKEN_MAP.get(token)
    if not tier:
        raise HTTPException(status_code=403, detail='Token invalide')
    return _SCOPE_ACCESS[tier]


# ── Routes ─────────────────────────────────────────────────────────────────────

@app.get('/health')
def health():
    """Sanity check — vérifie que le moteur répond."""
    uptime = int(time.time() - _START_TIME)
    try:
        import sqlite3
        from search import DB_PATH
        conn = sqlite3.connect(DB_PATH)
        # embeddings table is created by embed.py (requires Ollama) — optional
        has_embeddings = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='embeddings'"
        ).fetchone()
        count = 0
        if has_embeddings:
            count = conn.execute("SELECT COUNT(*) FROM embeddings WHERE indexed=1").fetchone()[0]
        conn.close()
        return {'status': 'ok', 'indexed': count, 'uptime': uptime}
    except Exception as e:
        return JSONResponse(status_code=503, content={'status': 'error', 'detail': str(e), 'uptime': uptime})


# ── Brain-compose live — données tiers depuis brain-compose.yml ─────────────────

@app.get('/brain-compose/tiers')
def brain_compose_tiers():
    """Retourne les feature_sets structurés depuis brain-compose.yml — source de vérité."""
    compose_path = BRAIN_ROOT / 'brain-compose.yml'
    if not compose_path.exists():
        raise HTTPException(status_code=404, detail='brain-compose.yml introuvable')

    # Parse custom — brain-compose.yml utilise `extends:` inline qui n'est pas du YAML standard
    raw = compose_path.read_text(encoding='utf-8')
    # Retirer les lignes `extends: X` qui cassent le parser YAML
    cleaned = re.sub(r'^\s+extends:\s+\w+\s*$', '', raw, flags=re.MULTILINE)
    try:
        data = yaml.safe_load(cleaned) if _YAML_AVAILABLE else {}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f'Erreur parsing brain-compose.yml: {e}')

    feature_sets = data.get('feature_sets', {})
    version = data.get('version', 'unknown')

    # Résoudre l'héritage (extends) et compter les agents cumulés
    resolved = {}
    tier_chain = ['free', 'featured', 'pro', 'full']

    cumulative_agents: list[str] = []
    cumulative_sessions: list[str] = []

    for tier_name in tier_chain:
        tier_data = feature_sets.get(tier_name, {})
        if not tier_data:
            continue

        # Agents de ce tier
        tier_agents = tier_data.get('agents', [])
        if tier_agents == '*':
            # full = tous les agents
            agents_dir = BRAIN_ROOT / 'agents'
            if agents_dir.is_dir():
                all_agents = sorted([
                    f.stem for f in agents_dir.glob('*.md')
                    if f.stem not in ('AGENTS', 'CATALOG', '_template', '_template-orchestrator')
                ])
                cumulative_agents = all_agents
            tier_agents_list = cumulative_agents[:]
        else:
            for a in tier_agents:
                if a not in cumulative_agents:
                    cumulative_agents.append(a)
            tier_agents_list = cumulative_agents[:]

        # Sessions de ce tier
        tier_sessions = tier_data.get('sessions', [])
        if tier_sessions == '*':
            cumulative_sessions = [
                'navigate', 'work', 'debug', 'brainstorm', 'brain', 'handoff',
                'coach', 'capital', 'audit', 'deploy', 'infra', 'urgence',
                'kernel', 'edit-brain', 'pilote'
            ]
        elif isinstance(tier_sessions, list):
            for s in tier_sessions:
                if s != 'extends' and not isinstance(s, dict) and s not in cumulative_sessions:
                    cumulative_sessions.append(s)

        resolved[tier_name] = {
            'description': tier_data.get('description', ''),
            'coach_level': tier_data.get('coach_level', ''),
            'distillation': tier_data.get('distillation', False),
            'agents_new': [a for a in (tier_agents if isinstance(tier_agents, list) else []) if a != '*'],
            'agents_total': tier_agents_list,
            'agents_count': len(tier_agents_list),
            'sessions_new': [s for s in (tier_sessions if isinstance(tier_sessions, list) else []) if s not in ('extends',) and not isinstance(s, dict)],
            'sessions_total': cumulative_sessions[:],
            'sessions_count': len(cumulative_sessions),
        }

    return {
        'version': version,
        'tiers': resolved,
        'tier_chain': tier_chain,
    }


# ── Docs live — sert docs/*.md depuis le filesystem ────────────────────────────

@app.get('/docs/view')
def docs_redirect():
    """Redirige /docs/view vers le dashboard docs (pour les navigateurs)."""
    return RedirectResponse(url='/ui/docs', status_code=302)


@app.get('/docs')
def docs_list():
    """Liste les fichiers docs/*.md avec métadonnées (frontmatter group/label)."""
    docs_dir = BRAIN_ROOT / 'docs'
    if not docs_dir.is_dir():
        return {'docs': []}

    results = []
    for f in sorted(docs_dir.glob('*.md')):
        if f.name == 'README.md':
            continue
        # Extraire le group depuis le contenu (heuristique basée sur le nom)
        name = f.stem
        group = _guess_doc_group(name)
        label = _guess_doc_label(name)
        results.append({
            'name': name,
            'label': label,
            'group': group,
            'path': f'/docs/{f.name}',
            'size': f.stat().st_size,
            'modified': datetime.fromtimestamp(f.stat().st_mtime, tz=timezone.utc).isoformat(),
        })
    return {'docs': results}


@app.get('/docs/{filename}')
def docs_read(filename: str):
    """Retourne le contenu brut d'un fichier docs/*.md."""
    # Sécurité : pas de path traversal
    if '/' in filename or '..' in filename:
        raise HTTPException(status_code=400, detail='Nom de fichier invalide')
    target = BRAIN_ROOT / 'docs' / filename
    if not target.exists() or not target.suffix == '.md':
        raise HTTPException(status_code=404, detail=f'{filename} introuvable')
    content = target.read_text(encoding='utf-8')
    # Strip frontmatter
    content = re.sub(r'^---[\s\S]*?---\n*', '', content)
    return JSONResponse(content={'name': target.stem, 'content': content})


def _guess_doc_group(name: str) -> str:
    """Heuristique pour grouper les docs par famille."""
    if name.startswith('agents'):
        return 'Agents'
    if name.startswith('vue-'):
        return 'Vues'
    return 'Guides'


def _guess_doc_label(name: str) -> str:
    """Heuristique pour le label sidebar."""
    labels = {
        'getting-started': 'Demarrer',
        'architecture': 'Architecture',
        'sessions': 'Sessions',
        'workflows': 'Workflows',
        'satellites': 'Satellites',
        'brain-engine-guide': 'Brain-engine',
        'agents': "Vue d'ensemble",
        'agents-code': 'Code & Qualite',
        'agents-infra': 'Infra & Deploy',
        'agents-brain': 'Brain & Systeme',
        'vue-tiers': 'Comparatif',
        'vue-free': '🟢 free',
        'vue-featured': '🔵 featured',
        'vue-pro': '🟠 pro',
        'vue-full': '🟣 full',
    }
    return labels.get(name, name.replace('-', ' ').title())


@app.get('/search')
def search(
    q:             str        = Query(..., description='Requête en langage naturel'),
    top:           int        = Query(5,   description='Nombre de résultats'),
    full:          bool       = Query(False, description='Chunks complets (défaut: compact)'),
    mode:          str        = Query('develop', description='develop | service (réservé)'),
    authorization: str | None = Header(None),
):
    scopes = check_auth(authorization)
    log.info('search q=%r top=%d full=%s scopes=%s', q, top, full, scopes)

    results = run_single_query(q, top_k=top, allowed_scopes=scopes)

    return _format_results(results, full=full, mode=mode)


@app.get('/boot')
def boot(
    full:          bool       = Query(False, description='Chunks complets (défaut: compact)'),
    mode:          str        = Query('develop', description='develop | service (réservé)'),
    authorization: str | None = Header(None),
    request:       Request    = None,
):
    if _is_localhost(request):
        scopes = ['public', 'work', 'kernel']
    else:
        scopes = check_auth(authorization)
    log.info('boot full=%s scopes=%s', full, scopes)

    results = run_boot_queries(allowed_scopes=scopes)

    return _format_results(results, full=full, mode=mode)


def _load_catalog(agents_dir: Path) -> dict:
    """
    Charge agents/CATALOG.yml et retourne un dict {agent_id: {tier, export, description}}.
    Retourne {} si CATALOG absent ou invalide.
    """
    catalog_path = agents_dir / 'CATALOG.yml'
    if not catalog_path.exists():
        return {}
    data = _load_yaml_file(catalog_path)
    if not data or not isinstance(data.get('agents'), list):
        return {}
    return {
        entry['id']: {
            'tier':        entry.get('tier', 'free'),
            'export':      entry.get('export', True),
            'description': entry.get('description', ''),
        }
        for entry in data['agents']
        if isinstance(entry, dict) and 'id' in entry
    }


# Tier access hierarchy: owner sees all, pro sees pro+free, free sees only free
_CATALOG_TIER_RANK: dict[str, int] = {'free': 0, 'featured': 1, 'pro': 2, 'owner': 3}

# Map token tier → max catalog tier accessible
_TOKEN_TIER_TO_CATALOG: dict[str, str] = {
    'free':     'free',
    'featured': 'featured',
    'mcp':      'pro',
    'pro':      'pro',
    'owner':    'owner',
}


def _catalog_tier_allowed(agent_catalog_tier: str, request_tier: str) -> bool:
    """True si l'agent est accessible au tier de la requête."""
    catalog_rank  = _CATALOG_TIER_RANK.get(agent_catalog_tier, 99)
    max_tier      = _TOKEN_TIER_TO_CATALOG.get(request_tier, 'free')
    allowed_rank  = _CATALOG_TIER_RANK.get(max_tier, 0)
    return catalog_rank <= allowed_rank


@app.get('/agents')
def agents_list(
    authorization: str | None = Header(None),
    request:       Request    = None,
):
    """Liste les agents disponibles, filtrés par tier depuis agents/CATALOG.yml."""
    if not _is_localhost(request):
        check_auth(authorization)  # zones=['public'] — tout token valide suffit

    # Résoudre le tier de l'appelant
    if _is_localhost(request):
        req_tier = 'owner'
    else:
        req_tier = get_tier_from_request(authorization)

    log.info('agents_list tier=%s', req_tier)

    agents_dir = BRAIN_ROOT / 'agents'
    tier_map   = _parse_agents_tier_map(agents_dir / 'AGENTS.md')
    catalog    = _load_catalog(agents_dir)
    result     = []

    for md_file in sorted(agents_dir.glob('*.md')):
        if md_file.name in ('AGENTS.md', '_template.md', '_template-orchestrator.md'):
            continue
        fm = _parse_frontmatter(md_file)
        if not fm:
            continue
        agent_id = fm.get('name') or md_file.stem

        # Filtrage par tier depuis CATALOG — si CATALOG absent, tout passe (comportement legacy)
        if catalog:
            cat_entry = catalog.get(agent_id)
            if cat_entry is None:
                # Agent absent du CATALOG → visible uniquement pour owner
                if req_tier != 'owner':
                    continue
                catalog_tier = 'owner'
                export       = False
            else:
                catalog_tier = cat_entry['tier']
                export       = cat_entry['export']
                if not _catalog_tier_allowed(catalog_tier, req_tier):
                    continue
        else:
            catalog_tier = 'free'
            export       = True

        info  = tier_map.get(agent_id, {})
        brain = fm.get('brain', {}) if isinstance(fm.get('brain'), dict) else {}
        result.append({
            'id':          agent_id,
            'label':       agent_id,
            'tier':        catalog_tier,
            'export':      export,
            'status':      fm.get('status', 'active'),
            'triggers':    brain.get('triggers') or fm.get('domain') or [],
            'scope':       brain.get('scope', 'project'),
            'created':     info.get('created', ''),
            'description': catalog.get(agent_id, {}).get('description', ''),
        })

    return result


@app.get('/teams')
def teams_list(
    authorization: str | None = Header(None),
    request:       Request    = None,
):
    """Liste toutes les teams parsées depuis teams/*.yml."""
    if not _is_localhost(request):
        check_auth(authorization)  # zones=['public']
    log.info('teams_list')

    teams_dir = BRAIN_ROOT / 'teams'
    result    = []

    for yml_file in sorted(teams_dir.glob('*.yml')):
        data = _load_yaml_file(yml_file)
        if not data:
            continue
        result.append({
            'id':                  data.get('id', yml_file.stem),
            'label':               data.get('label', ''),
            'icon':                data.get('icon', ''),
            'agents':              data.get('agents', []),
            'capabilities':        data.get('capabilities', []),
            'gate_required':       data.get('gate_required', False),
            'default_timeout_min': data.get('default_timeout_min', 30),
        })

    return result


@app.get('/workflows')
def workflows_list(
    authorization: str | None = Header(None),
    request: Request = None,
):
    """Retourne les workflows BSI depuis brain.db (ADR-042)."""
    if _is_localhost(request):
        scopes = ['work', 'kernel', 'public']
    else:
        scopes = check_auth(authorization)
    if 'work' not in scopes:
        raise HTTPException(status_code=403, detail='Zone work requise')
    log.info('workflows_list scopes=%s', scopes)

    db_path = BRAIN_ROOT / 'brain.db'
    if not db_path.exists():
        return []

    import sqlite3 as _sql
    conn = _sql.connect(str(db_path))
    conn.row_factory = _sql.Row
    rows = conn.execute(
        "SELECT * FROM claims WHERE satellite_type IS NOT NULL OR workflow IS NOT NULL "
        "ORDER BY opened_at DESC"
    ).fetchall()
    conn.close()

    result = []
    for r in rows:
        result.append({
            'id':             r['sess_id'],
            'name':           r['story_angle'] or r['workflow'] or r['sess_id'],
            'project':        r['workflow'] or r['scope'] or r['sess_id'],
            'status':         r['status'] or 'open',
            'opened_at':      r['opened_at'] or '',
            'workflow_step':  r['workflow_step'],
            'satellite_type': r['satellite_type'],
            'steps':          [],
        })

    return result


@app.post('/workflows/create')
def workflows_create(
    body:          dict       = Body(...),
    authorization: str | None = Header(None),
    request:       Request    = None,
):
    """Crée un claim BSI dans brain.db (ADR-042). Requiert zone kernel (owner uniquement)."""
    if not _is_localhost(request):
        scopes = check_auth(authorization)
        if 'kernel' not in scopes:
            raise HTTPException(status_code=403, detail='Zone kernel requise (owner only)')

    title        = body.get('title', '')
    team_id      = body.get('teamId', '')

    if not title:
        raise HTTPException(status_code=422, detail='title requis')

    now      = datetime.now(timezone.utc)
    date_str = now.strftime('%Y%m%d-%H%M')
    slug     = re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')[:40]
    sess_id  = f'sess-{date_str}-{slug}'
    now_str  = now.strftime('%Y-%m-%dT%H:%M')

    db_path = BRAIN_ROOT / 'brain.db'
    import sqlite3 as _sql
    conn = _sql.connect(str(db_path))
    conn.execute(
        "INSERT OR REPLACE INTO claims "
        "(sess_id, type, scope, status, opened_at, story_angle, workflow, zone, mode, "
        " handoff_level, ttl_hours, expires_at) "
        "VALUES (?, 'work', ?, 'open', ?, ?, ?, 'project', ?, '0', 4.0, datetime(?, '+4 hours'))",
        (sess_id, f'work/{slug}', now_str, title, title, team_id or 'build', now_str)
    )
    conn.commit()
    conn.close()
    log.info('workflows_create sess_id=%s (brain.db)', sess_id)

    return {'ok': True, 'claimId': sess_id}


@app.get('/visualize')
def visualize(
    request:       Request,
    zone:          str       = Query('all'),
    force:         bool      = Query(False),
    authorization: str | None = Header(None),
):
    """Retourne les coordonnées 3D UMAP des embeddings brain. Cache JSON regénéré si stale."""
    check_auth(authorization)
    if not _is_localhost(request):
        tier = get_tier_from_request(authorization)
        if not has_feature('visualize', tier):
            raise HTTPException(status_code=403, detail='feature:visualize requires pro tier')

    cache_path = BRAIN_ROOT / 'brain-engine' / 'viz_cache.json'
    db_path    = BRAIN_ROOT / 'brain.db'

    need_regen = force or not cache_path.exists()
    if not need_regen and cache_path.exists() and db_path.exists():
        need_regen = db_path.stat().st_mtime > cache_path.stat().st_mtime

    if need_regen:
        try:
            import struct as _struct
            import numpy as _np
            import umap as _umap

            _sqlite3 = __import__('sqlite3')
            conn = _sqlite3.connect(str(db_path))
            cur  = conn.cursor()
            tables = cur.execute(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='embeddings'"
            ).fetchone()
            if not tables:
                conn.close()
                raise HTTPException(status_code=503, detail='embeddings not indexed — run migrate.py')
            cur.execute(
                'SELECT filepath, title, scope, vector, chunk_text FROM embeddings'
                ' WHERE indexed=1 AND vector IS NOT NULL'
            )
            rows = cur.fetchall()
            conn.close()

            vecs = [_struct.unpack(f'{len(r[3])//4}f', r[3]) for r in rows]
            X    = _np.array(vecs, dtype=_np.float32)

            t0      = __import__('time').time()
            reducer = _umap.UMAP(n_components=3, n_neighbors=15, min_dist=0.1, random_state=42, verbose=False)
            coords  = reducer.fit_transform(X)
            elapsed = __import__('time').time() - t0

            points = [
                {
                    'id':      r[0],
                    'path':    r[0],
                    'zone':    r[2] or 'unknown',
                    'label':   r[1] or Path(r[0]).stem,
                    'excerpt': (r[4] or '')[:200],
                    'x': float(coords[i, 0]),
                    'y': float(coords[i, 1]),
                    'z': float(coords[i, 2]),
                }
                for i, r in enumerate(rows)
            ]
            cache_data = {
                'points':       points,
                'generated_at': datetime.now(timezone.utc).isoformat(),
                'cached':       False,
                'umap_params':  {'n_components': 3, 'n_neighbors': 15, 'min_dist': 0.1},
                'elapsed_s':    round(elapsed, 1),
            }
            cache_path.write_text(__import__('json').dumps(cache_data))
            log.info('visualize: cache regenerated %d points in %.1fs', len(points), elapsed)
        except Exception as exc:
            log.error('visualize regen failed: %s', exc)
            if not cache_path.exists():
                raise HTTPException(status_code=503, detail=f'UMAP generation failed: {exc}')

    raw = __import__('json').loads(cache_path.read_text())
    points = raw.get('points', [])
    if zone != 'all':
        points = [p for p in points if p.get('zone') == zone]

    return {**raw, 'points': points, 'cached': True}


@app.get('/tier')
def tier_get(authorization: str | None = Header(None)):
    """Retourne le tier actif (owner | pro | free) + features. Cache 1h, grace 7j offline."""
    # Pas d'auth requise — le tier est public (il détermine ce qu'on peut voir)
    tier = get_tier_from_request(authorization)
    features: dict[str, list[str]] = {
        'owner': ['cosmos', 'workspace', 'workflows', 'builder', 'secrets', 'infra', 'editor'],
        'pro':   ['cosmos', 'workspace', 'workflows', 'builder'],
        'free':  ['cosmos'],
    }
    return {
        'tier': tier,
        'features': features.get(tier, features['free']),
        'kernel_access': tier == 'owner',
        'feature_tier': FEATURE_TIER,
    }


@app.get('/state')
def state_get(request: Request = None):
    """
    Environnement fondamental dérivé — Layer 2 uniquement.
    pm2 status + git version + ports. Jamais mis en cache, toujours frais.
    """
    if not _is_localhost(request):
        raise HTTPException(status_code=403, detail='Layer 2 only — localhost requis')

    # pm2 status
    pm2_procs = []
    try:
        result = subprocess.run(['pm2', 'jlist'], capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            for proc in json.loads(result.stdout):
                env = proc.get('pm2_env', {})
                pm2_procs.append({
                    'name':    proc.get('name', '?'),
                    'status':  env.get('status', 'unknown'),
                    'uptime':  env.get('pm_uptime'),
                    'restarts': env.get('restart_time', 0),
                })
    except Exception as exc:
        log.warning('state pm2 error: %s', exc)

    # Version brain (dernier commit)
    brain_version = ''
    try:
        r = subprocess.run(
            ['git', 'log', '-1', '--oneline'],
            capture_output=True, text=True, timeout=3, cwd=str(BRAIN_ROOT)
        )
        if r.returncode == 0:
            brain_version = r.stdout.strip()
    except Exception:
        pass

    import socket
    return {
        'hostname':      socket.gethostname(),
        'brain_version': brain_version,
        'pm2':           pm2_procs,
        'ports': {
            'brain_engine': BRAIN_PORT,
            'brain_mcp':    int(os.getenv('BRAIN_MCP_PORT', 7701)),
            'brain_key':    int(os.getenv('BRAIN_KEY_PORT', 7432)),
        },
    }


@app.get('/infra')
def infra_list(request: Request, authorization: str | None = Header(None)):
    """Retourne l'état des services infrastructure depuis pm2 + config statique."""
    check_auth(authorization)
    if not _is_localhost(request):
        tier = get_tier_from_request(authorization)
        if not has_feature('infra', tier):
            raise HTTPException(status_code=403, detail='feature:infra requires pro tier')
    log.info('infra_list')

    services = []

    # Services pm2
    try:
        result = subprocess.run(
            ['pm2', 'jlist'],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            import json as _json
            pm2_list = _json.loads(result.stdout)
            for proc in pm2_list:
                env = proc.get('pm2_env', {})
                services.append({
                    'id':      f"pm2-{proc.get('name', proc.get('pm_id', '?'))}",
                    'name':    proc.get('name', '?'),
                    'type':    'pm2',
                    'status':  env.get('status', 'unknown'),
                    'port':    env.get('PORT') or env.get('port') or None,
                    'uptime':  env.get('pm_uptime', None),
                    'restarts': proc.get('pm2_env', {}).get('restart_time', 0),
                    'memory':  proc.get('monit', {}).get('memory', 0),
                    'cpu':     proc.get('monit', {}).get('cpu', 0),
                })
    except Exception as exc:
        log.warning('infra pm2 error: %s', exc)

    # Services statiques (Apache vhosts connus)
    static_services = [
        {'id': 'apache',      'name': 'Apache2',       'type': 'system', 'status': 'online', 'port': 443},
        {'id': 'brain-engine','name': 'brain-engine',  'type': 'info',   'status': 'online', 'port': 7700},
        {'id': 'gitea',       'name': 'Gitea',         'type': 'info',   'status': 'online', 'port': 3000},
    ]

    return {'services': services + static_services, 'total': len(services) + len(static_services)}


@app.put('/brain/{path:path}')
async def brain_put(
    request:       Request,
    path:          str,
    body:          dict       = Body(...),
    authorization: str | None = Header(None),
):
    """
    Écrit ou met à jour un document brain.
    Requiert zone kernel (owner uniquement).
    body: { content: str }   — contenu Markdown brut
    """
    scopes = check_auth(authorization)
    if 'kernel' not in scopes:
        raise HTTPException(status_code=403, detail='Zone kernel requise (owner only)')
    if not _is_localhost(request):
        tier = get_tier_from_request(authorization)
        if not has_feature('brain_write', tier):
            raise HTTPException(status_code=403, detail='feature:brain_write requires pro tier')

    # Sécurité : interdire les path traversal
    target = (BRAIN_ROOT / path).resolve()
    if not str(target).startswith(str(BRAIN_ROOT.resolve())):
        raise HTTPException(status_code=400, detail='Path traversal interdit')

    content = body.get('content', '')
    if not content:
        raise HTTPException(status_code=422, detail='content requis')

    # Écriture
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding='utf-8')
    log.info('brain_put path=%s (%d bytes)', path, len(content))

    # Signal reindex via subprocess (non-bloquant)
    try:
        subprocess.Popen(
            ['python3', str(BRAIN_ROOT / 'brain-engine' / 'index.py'), '--file', str(target)],
            cwd=str(BRAIN_ROOT),
        )
        reindex_triggered = True
    except Exception as exc:
        log.warning('brain_put reindex failed: %s', exc)
        reindex_triggered = False

    # Broadcast WebSocket — les clients rechargent le point modifié
    await _broadcast({
        'type':    'brain:updated',
        'payload': {'path': path, 'reindex': reindex_triggered},
    })

    return {'ok': True, 'path': path, 'reindex': reindex_triggered}


# ── Ambient Brain ──────────────────────────────────────────────────────────────

@app.post('/ambient/notify')
async def ambient_notify(
    body:          dict       = Body(...),
    authorization: str | None = Header(None),
    request:       Request    = None,
):
    """Reçoit un event du daemon Ambient Brain et le broadcast aux clients WebSocket."""
    if _is_localhost(request):
        pass  # daemon local — toujours OK
    else:
        tier = get_tier_from_request(authorization)
        if not has_feature('ambient', tier):
            raise HTTPException(status_code=403, detail='feature:ambient requires pro tier')
    event = {
        'type':    body.get('type', 'ambient:event'),
        'context': body.get('context', ''),
        'message': body.get('message', ''),
        'level':   body.get('level', 'info'),
        'ts':      body.get('ts', ''),
    }
    log.info('ambient_notify context=%s msg=%s', event['context'], event['message'])
    await _broadcast(event)
    return {'ok': True}


# ── WebSocket ──────────────────────────────────────────────────────────────────

@app.websocket('/ws')
async def websocket_endpoint(websocket: WebSocket):
    """WebSocket temps réel — broadcasts workflow:update, gate:pending, gate:resolved."""
    await websocket.accept()
    _ws_clients.append(websocket)
    try:
        while True:
            await websocket.receive_text()  # keepalive ping
    except WebSocketDisconnect:
        _ws_clients.remove(websocket)


async def _broadcast(payload: dict) -> None:
    """Broadcast JSON à tous les clients WebSocket connectés."""
    import json as _json
    dead = []
    for ws in list(_ws_clients):
        try:
            await ws.send_text(_json.dumps(payload))
        except Exception:
            dead.append(ws)
    for ws in dead:
        if ws in _ws_clients:
            _ws_clients.remove(ws)


# ── GET /logs/{project} ─────────────────────────────────────────────────────────

_LOG_LINE_RE = re.compile(
    r'(?P<ts>\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[.\d]*Z?)?'
    r'\s*(?P<level>ERROR|WARN(?:ING)?|INFO|DEBUG)?\s*(?P<msg>.+)',
    re.IGNORECASE,
)

def _parse_log_line(raw: str) -> dict | None:
    """Parse une ligne pm2 brute en {ts, level, msg}."""
    raw = raw.strip()
    if not raw or raw.startswith('> Log tailing'):
        return None

    # Essai extraction ts ISO
    ts_now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    m = _LOG_LINE_RE.match(raw)
    if not m:
        return {'ts': ts_now, 'level': 'info', 'msg': raw}

    ts    = m.group('ts') or ts_now
    raw_level = (m.group('level') or 'info').lower()
    level = 'warn' if raw_level.startswith('warn') else raw_level if raw_level in ('error', 'debug') else 'info'
    msg   = m.group('msg').strip() or raw

    return {'ts': ts, 'level': level, 'msg': msg}


@app.get('/logs/{project}')
def logs_get(
    project:       str,
    since:         str | None = Query(None, description='ISO8601 — exclure les lignes antérieures'),
    authorization: str | None = Header(None),
):
    """Lit les 50 dernières lignes pm2 pour un projet. Requiert zone work."""
    scopes = check_auth(authorization)
    if 'work' not in scopes:
        raise HTTPException(status_code=403, detail='Zone work requise')

    log.info('logs_get project=%s since=%s', project, since)

    try:
        result = subprocess.run(
            ['pm2', 'logs', project, '--lines', '50', '--nostream'],
            capture_output=True, text=True, timeout=10,
        )
        raw_lines = (result.stdout + result.stderr).splitlines()
    except FileNotFoundError:
        raw_lines = [f'[mock] pm2 non disponible — project={project}']
    except subprocess.TimeoutExpired:
        raw_lines = ['[error] pm2 timeout']

    lines = [_parse_log_line(l) for l in raw_lines]
    lines = [l for l in lines if l is not None]

    if since:
        lines = [l for l in lines if l['ts'] > since]

    return {'lines': lines}


# ── POST /gate/{workflow_id}/{step_id}/approve ──────────────────────────────────

@app.post('/gate/{workflow_id}/{step_id}/approve')
async def gate_approve(
    workflow_id:   str,
    step_id:       str,
    body:          dict       = Body(...),
    authorization: str | None = Header(None),
):
    """Résout une gate (approve / abort / skip). Requiert zone kernel (owner)."""
    scopes = check_auth(authorization)
    if 'kernel' not in scopes:
        raise HTTPException(status_code=403, detail='Zone kernel requise (owner only)')

    action = body.get('action', 'approve')
    if action not in ('approve', 'abort', 'skip'):
        raise HTTPException(status_code=422, detail='action doit être approve | abort | skip')

    now         = datetime.now(timezone.utc)
    resolved_at = now.strftime('%Y-%m-%dT%H:%M:%SZ')
    ack = {
        'workflow_id': workflow_id,
        'step_id':     step_id,
        'action':      action,
        'resolved_at': resolved_at,
    }

    # Écriture du fichier gate-ack YAML
    claims_dir = BRAIN_ROOT / 'claims'
    claims_dir.mkdir(parents=True, exist_ok=True)
    slug = re.sub(r'[^a-z0-9]+', '-', f'{workflow_id}-{step_id}'.lower()).strip('-')
    ack_path = claims_dir / f'gate-ack-{slug}.yml'
    _write_yaml_file(ack_path, ack)

    log.info('gate_approve workflow=%s step=%s action=%s', workflow_id, step_id, action)

    # Broadcast WebSocket
    await _broadcast({
        'type':    'gate:resolved',
        'payload': {'workflowId': workflow_id, 'stepId': step_id, 'result': action},
    })

    return {'ok': True}


# ── BSI endpoints (ADR-036) ────────────────────────────────────────────────

import sqlite3

DB_BSI_PATH = str(BRAIN_ROOT / 'brain.db')

# ── BSI peers — chargement depuis brain-compose.local.yml ─────────────────

def _load_peers() -> list[dict]:
    """Charge les peers actifs depuis brain-compose.local.yml."""
    compose_local = BRAIN_ROOT / 'brain-compose.local.yml'
    if not compose_local.exists():
        return []
    try:
        if _YAML_AVAILABLE:
            with open(compose_local) as f:
                data = yaml.safe_load(f) or {}
        else:
            return []
        peers = data.get('peers', {})
        return [
            {'name': name, 'url': p.get('url', '')}
            for name, p in peers.items()
            if isinstance(p, dict) and p.get('active', False)
        ]
    except Exception as exc:
        log.warning('peers load error: %s', exc)
        return []


def _fetch_peer_claims(peer_url: str, timeout: float = 2.0) -> list[dict]:
    """Fetch claims depuis un peer brain-engine. Timeout court — best effort."""
    try:
        req = urllib.request.Request(f"{peer_url.rstrip('/')}/bsi/claims")
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read())
    except Exception as exc:
        log.debug('peer %s unreachable: %s', peer_url, exc)
        return []

def _bsi_conn() -> sqlite3.Connection:
    """Connexion brain.db avec row_factory dict — init schema si absent."""
    conn = sqlite3.connect(DB_BSI_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")
    # Ensure BSI tables exist
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS locks (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            filepath    TEXT NOT NULL UNIQUE,
            holder      TEXT NOT NULL,
            claimed_at  TEXT NOT NULL DEFAULT (datetime('now')),
            expires_at  TEXT NOT NULL,
            ttl_min     INTEGER NOT NULL DEFAULT 60
        );
        CREATE TABLE IF NOT EXISTS circuit_breaker (
            sess_id     TEXT PRIMARY KEY,
            fail_count  INTEGER NOT NULL DEFAULT 0,
            last_fail_at TEXT,
            updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
        );
    """)
    return conn


@app.get('/bsi/claims')
def bsi_claims_list(
    status:        str | None  = Query(None),
    include_peers: bool        = Query(False),
    request:       Request     = None,
    authorization: str | None  = Header(None),
):
    """Liste les claims BSI depuis brain.db. ?include_peers=true agrège les peers."""
    if not _is_localhost(request):
        scopes = check_auth(authorization)
        if 'work' not in scopes:
            raise HTTPException(status_code=403, detail='Zone work requise')

    # Local claims
    conn = _bsi_conn()
    try:
        if status:
            rows = conn.execute(
                "SELECT * FROM claims WHERE status = ? ORDER BY opened_at DESC", (status,)
            ).fetchall()
        else:
            rows = conn.execute(
                "SELECT * FROM claims ORDER BY opened_at DESC"
            ).fetchall()
        local_claims = [dict(r) for r in rows]
    finally:
        conn.close()

    # Tag local claims with instance
    compose_local = BRAIN_ROOT / 'brain-compose.local.yml'
    machine_name = 'local'
    if compose_local.exists() and _YAML_AVAILABLE:
        try:
            with open(compose_local) as f:
                data = yaml.safe_load(f) or {}
            machine_name = data.get('machine', 'local')
        except Exception:
            pass

    for c in local_claims:
        c['_source'] = machine_name

    if not include_peers:
        return local_claims

    # Fetch peer claims
    all_claims = list(local_claims)
    for peer in _load_peers():
        peer_claims = _fetch_peer_claims(peer['url'])
        for c in peer_claims:
            c['_source'] = peer['name']
            if status and c.get('status') != status:
                continue
            all_claims.append(c)

    return all_claims


@app.get('/bsi/network')
def bsi_network(
    request:       Request    = None,
    authorization: str | None = Header(None),
):
    """Vue réseau BSI — état de chaque peer + claims open agrégés."""
    if not _is_localhost(request):
        scopes = check_auth(authorization)
        if 'work' not in scopes:
            raise HTTPException(status_code=403, detail='Zone work requise')

    # Local
    conn = _bsi_conn()
    try:
        local_open = conn.execute(
            "SELECT COUNT(*) FROM claims WHERE status = 'open'"
        ).fetchone()[0]
        local_total = conn.execute("SELECT COUNT(*) FROM claims").fetchone()[0]
    finally:
        conn.close()

    compose_local = BRAIN_ROOT / 'brain-compose.local.yml'
    machine_name = 'local'
    if compose_local.exists() and _YAML_AVAILABLE:
        try:
            with open(compose_local) as f:
                data = yaml.safe_load(f) or {}
            machine_name = data.get('machine', 'local')
        except Exception:
            pass

    nodes = [{
        'name': machine_name,
        'url': f'http://localhost:{BRAIN_PORT}',
        'status': 'online',
        'claims_open': local_open,
        'claims_total': local_total,
    }]

    # Peers
    for peer in _load_peers():
        peer_claims = _fetch_peer_claims(peer['url'])
        if peer_claims is not None and isinstance(peer_claims, list):
            open_count = sum(1 for c in peer_claims if c.get('status') == 'open')
            nodes.append({
                'name': peer['name'],
                'url': peer['url'],
                'status': 'online',
                'claims_open': open_count,
                'claims_total': len(peer_claims),
            })
        else:
            nodes.append({
                'name': peer['name'],
                'url': peer['url'],
                'status': 'offline',
                'claims_open': 0,
                'claims_total': 0,
            })

    return {'nodes': nodes, 'peer_count': len(nodes)}


@app.post('/bsi/claims')
async def bsi_claims_create(
    body:          dict       = Body(...),
    request:       Request    = None,
    authorization: str | None = Header(None),
):
    """Crée un claim BSI dans brain.db."""
    if not _is_localhost(request):
        scopes = check_auth(authorization)
        if 'kernel' not in scopes:
            raise HTTPException(status_code=403, detail='Zone kernel requise (owner only)')

    sess_id = body.get('sess_id')
    if not sess_id:
        raise HTTPException(status_code=422, detail='sess_id requis')

    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    ttl_hours = body.get('ttl_hours', 4)

    conn = _bsi_conn()
    try:
        conn.execute("""
            INSERT OR REPLACE INTO claims
                (sess_id, type, scope, status, opened_at, handoff_level,
                 ttl_hours, expires_at, instance, parent_sess,
                 satellite_type, satellite_level, theme_branch, zone, mode)
            VALUES (?, ?, ?, ?, ?, ?, ?, datetime(?, '+' || ? || ' hours'), ?, ?, ?, ?, ?, ?, ?)
        """, (
            sess_id,
            body.get('type', 'work'),
            body.get('scope', ''),
            body.get('status', 'open'),
            body.get('opened_at', now),
            body.get('handoff_level'),
            ttl_hours,
            body.get('opened_at', now), ttl_hours,
            body.get('instance'),
            body.get('parent_sess'),
            body.get('satellite_type'),
            body.get('satellite_level'),
            body.get('theme_branch'),
            body.get('zone'),
            body.get('mode'),
        ))
        conn.commit()
        log.info('bsi_claims_create sess_id=%s', sess_id)

        await _broadcast({
            'type': 'bsi:claim:open',
            'payload': {'sess_id': sess_id, 'scope': body.get('scope', ''), 'status': 'open'},
        })

        return {'ok': True, 'sess_id': sess_id}
    finally:
        conn.close()


@app.patch('/bsi/claims/{sess_id}')
async def bsi_claims_update(
    sess_id:       str,
    body:          dict       = Body(...),
    request:       Request    = None,
    authorization: str | None = Header(None),
):
    """Met à jour un claim BSI (status, result, close)."""
    if not _is_localhost(request):
        scopes = check_auth(authorization)
        if 'kernel' not in scopes:
            raise HTTPException(status_code=403, detail='Zone kernel requise (owner only)')

    conn = _bsi_conn()
    try:
        existing = conn.execute(
            "SELECT sess_id FROM claims WHERE sess_id = ?", (sess_id,)
        ).fetchone()
        if not existing:
            raise HTTPException(status_code=404, detail=f'Claim {sess_id} introuvable')

        updates = []
        values  = []
        for field in ('status', 'closed_at', 'health_score', 'context_at_close',
                       'result_status', 'result_json', 'mode'):
            if field in body:
                updates.append(f"{field} = ?")
                values.append(body[field])

        if not updates:
            raise HTTPException(status_code=422, detail='Aucun champ à mettre à jour')

        # Auto-set closed_at if status → closed
        if body.get('status') == 'closed' and 'closed_at' not in body:
            updates.append("closed_at = ?")
            values.append(datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'))

        values.append(sess_id)
        conn.execute(f"UPDATE claims SET {', '.join(updates)} WHERE sess_id = ?", values)
        conn.commit()
        log.info('bsi_claims_update sess_id=%s fields=%s', sess_id, list(body.keys()))

        await _broadcast({
            'type': f'bsi:claim:{body.get("status", "update")}',
            'payload': {'sess_id': sess_id, **body},
        })

        return {'ok': True, 'sess_id': sess_id}
    finally:
        conn.close()


@app.get('/bsi/locks')
def bsi_locks_list(
    request:       Request    = None,
    authorization: str | None = Header(None),
):
    """Liste les locks actifs depuis brain.db."""
    if not _is_localhost(request):
        scopes = check_auth(authorization)
        if 'work' not in scopes:
            raise HTTPException(status_code=403, detail='Zone work requise')

    conn = _bsi_conn()
    try:
        rows = conn.execute("""
            SELECT filepath, holder, claimed_at, expires_at,
                   CASE WHEN julianday('now') < julianday(expires_at)
                        THEN 'active' ELSE 'expired' END AS lock_status
            FROM locks ORDER BY claimed_at DESC
        """).fetchall()
        return [dict(r) for r in rows]
    finally:
        conn.close()


@app.post('/bsi/locks')
async def bsi_locks_acquire(
    body:          dict       = Body(...),
    request:       Request    = None,
    authorization: str | None = Header(None),
):
    """Acquiert un lock fichier. Échoue si déjà tenu par un autre holder."""
    if not _is_localhost(request):
        scopes = check_auth(authorization)
        if 'kernel' not in scopes:
            raise HTTPException(status_code=403, detail='Zone kernel requise (owner only)')

    filepath = body.get('filepath')
    holder   = body.get('holder')
    ttl_min  = body.get('ttl_min', 60)

    if not filepath or not holder:
        raise HTTPException(status_code=422, detail='filepath et holder requis')

    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

    # Check peer locks FIRST (cross-machine coordination)
    for peer in _load_peers():
        try:
            req = urllib.request.Request(f"{peer['url'].rstrip('/')}/bsi/locks")
            with urllib.request.urlopen(req, timeout=2) as resp:
                peer_locks = json.loads(resp.read())
                for pl in peer_locks:
                    if (pl.get('filepath') == filepath
                            and pl.get('lock_status') == 'active'
                            and pl.get('holder') != holder):
                        raise HTTPException(
                            status_code=409,
                            detail=f"Lock détenu par {pl['holder']} sur {peer['name']} jusqu'à {pl.get('expires_at')}"
                        )
        except HTTPException:
            raise
        except Exception:
            pass  # peer unreachable — continue (mode dégradé)

    conn = _bsi_conn()
    try:
        # Check existing local lock
        existing = conn.execute("""
            SELECT holder, expires_at FROM locks
            WHERE filepath = ? AND julianday('now') < julianday(expires_at)
        """, (filepath,)).fetchone()

        if existing and existing['holder'] != holder:
            raise HTTPException(
                status_code=409,
                detail=f"Lock détenu par {existing['holder']} jusqu'à {existing['expires_at']}"
            )

        # Upsert — remplace si même holder ou expiré
        conn.execute("DELETE FROM locks WHERE filepath = ?", (filepath,))
        conn.execute("""
            INSERT INTO locks (filepath, holder, claimed_at, expires_at, ttl_min)
            VALUES (?, ?, ?, datetime(?, '+' || ? || ' minutes'), ?)
        """, (filepath, holder, now, now, ttl_min, ttl_min))
        conn.commit()
        log.info('bsi_lock_acquire filepath=%s holder=%s ttl=%dm', filepath, holder, ttl_min)

        await _broadcast({
            'type': 'bsi:lock:acquire',
            'payload': {'filepath': filepath, 'holder': holder},
        })

        return {'ok': True, 'filepath': filepath, 'holder': holder}
    finally:
        conn.close()


@app.delete('/bsi/locks/{filepath:path}')
async def bsi_locks_release(
    filepath:      str,
    holder:        str        = Query(...),
    request:       Request    = None,
    authorization: str | None = Header(None),
):
    """Libère un lock fichier. Seul le holder peut libérer."""
    if not _is_localhost(request):
        scopes = check_auth(authorization)
        if 'kernel' not in scopes:
            raise HTTPException(status_code=403, detail='Zone kernel requise (owner only)')

    conn = _bsi_conn()
    try:
        deleted = conn.execute(
            "DELETE FROM locks WHERE filepath = ? AND holder = ?", (filepath, holder)
        ).rowcount
        conn.commit()

        if deleted == 0:
            raise HTTPException(status_code=404, detail=f'Lock {filepath} non trouvé pour {holder}')

        log.info('bsi_lock_release filepath=%s holder=%s', filepath, holder)

        await _broadcast({
            'type': 'bsi:lock:release',
            'payload': {'filepath': filepath, 'holder': holder},
        })

        return {'ok': True, 'filepath': filepath}
    finally:
        conn.close()


# ── Helpers ────────────────────────────────────────────────────────────────────

def _format_results(results: list[dict], full: bool, mode: str) -> dict:
    """
    Sérialise les chunks en JSON.
    mode=develop  → filepath visible
    mode=service  → filepath masqué (prévu BE-3c — structure prête)
    """
    expose_filepath = (mode != 'service')   # garde le if pour BE-3c

    items = []
    for r in results:
        item = {
            'score':      round(r['score'], 4),
            'title':      r.get('title') or '',
            'query':      r.get('_query', ''),
        }
        if expose_filepath:
            item['filepath'] = r['filepath']
        if full:
            item['chunk_text'] = r['chunk_text']
        else:
            item['excerpt'] = r['chunk_text'].replace('\n', ' ')[:120].strip() + '…'
        items.append(item)

    return {'count': len(items), 'results': items}


def _parse_frontmatter(path: Path) -> dict:
    """
    Parse le frontmatter YAML d'un fichier Markdown (bloc entre les premiers `---`).
    Retourne {} si absent ou en cas d'erreur.
    """
    try:
        text = path.read_text(encoding='utf-8')
    except Exception:
        return {}

    m = re.match(r'^---\s*\n(.*?)\n---', text, re.DOTALL)
    if not m:
        return {}

    raw = m.group(1)
    if _YAML_AVAILABLE:
        try:
            return yaml.safe_load(raw) or {}
        except Exception:
            pass

    # Fallback : parser simple key: value (une profondeur)
    result: dict = {}
    for line in raw.splitlines():
        kv = re.match(r'^(\w[\w-]*):\s*(.*)$', line)
        if kv:
            k, v = kv.group(1), kv.group(2).strip()
            # liste inline [a, b, c]
            if v.startswith('[') and v.endswith(']'):
                items = [x.strip().strip('"\'') for x in v[1:-1].split(',') if x.strip()]
                result[k] = items
            else:
                result[k] = v.strip('"\'') or None
    return result


def _load_yaml_file(path: Path) -> dict:
    """Charge un fichier YAML. Retourne {} si absent ou invalide."""
    try:
        text = path.read_text(encoding='utf-8')
    except Exception:
        return {}

    if _YAML_AVAILABLE:
        try:
            return yaml.safe_load(text) or {}
        except Exception:
            return {}

    # Fallback : même parser simple que _parse_frontmatter
    result: dict = {}
    for line in text.splitlines():
        kv = re.match(r'^(\w[\w-]*):\s*(.*)$', line)
        if kv:
            k, v = kv.group(1), kv.group(2).strip()
            if v.startswith('[') and v.endswith(']'):
                items = [x.strip().strip('"\'') for x in v[1:-1].split(',') if x.strip()]
                result[k] = items
            else:
                result[k] = v.strip('"\'') or None
    return result


def _write_yaml_file(path: Path, data: dict) -> None:
    """Écrit un dict en YAML (ou format clé: valeur si yaml indisponible)."""
    if _YAML_AVAILABLE:
        path.write_text(yaml.dump(data, allow_unicode=True, default_flow_style=False), encoding='utf-8')
        return

    # Fallback minimal
    lines = []
    for k, v in data.items():
        if isinstance(v, list):
            lines.append(f'{k}: [{", ".join(str(i) for i in v)}]')
        elif isinstance(v, bool):
            lines.append(f'{k}: {"true" if v else "false"}')
        elif v is None:
            lines.append(f'{k}:')
        else:
            val = str(v)
            if any(c in val for c in (':', '#', '[', ']', '{', '}')):
                val = f'"{val}"'
            lines.append(f'{k}: {val}')
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')


def _parse_agents_tier_map(agents_md: Path) -> dict:
    """
    Parse AGENTS.md pour extraire tier et date de création par agent.
    Retourne {agent_id: {'tier': 'hot'|'stable'|'kernel', 'created': 'YYYY-MM-DD'}}.
    """
    tier_map: dict = {}
    try:
        text = agents_md.read_text(encoding='utf-8')
    except Exception:
        return tier_map

    # Détection de section : 🔴 → hot, 🔵 → stable, ⚙️ → kernel
    current_tier = 'stable'
    for line in text.splitlines():
        if '🔴' in line:
            current_tier = 'hot'
        elif '🔵' in line:
            current_tier = 'stable'
        elif '⚙️' in line or '⚙' in line:
            current_tier = 'kernel'
        # Ligne de tableau : | `agent-name` | ... | ✅ 2026-03-12 |
        row = re.match(r'\|\s*`([^`]+)`\s*\|.*\|\s*(.*?)\s*\|?\s*$', line)
        if row:
            agent_id = row.group(1)
            status_col = row.group(2)
            date_m = re.search(r'(\d{4}-\d{2}-\d{2})', status_col)
            created = date_m.group(1) if date_m else ''
            tier_map[agent_id] = {'tier': current_tier, 'created': created}

    return tier_map


# ── Entrypoint ─────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    import uvicorn
    tiers = ', '.join(sorted(set(_TOKEN_MAP.values()))) if _TOKEN_MAP else 'auth désactivée (dev)'
    log.info('Brain-as-a-Service BE-4 — port %d — tokens: %s', BRAIN_PORT, tiers)
    uvicorn.run(app, host='0.0.0.0', port=BRAIN_PORT,
                forwarded_allow_ips='*', proxy_headers=True)
