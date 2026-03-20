#!/usr/bin/env python3
"""
brain-engine/mcp_server.py — BE-4 MCP Server
Expose le brain comme source de contexte native pour Claude.

Transport : StreamableHTTP (MCP 1.x)
Port      : 7701 (défaut) — distinct du BaaS HTTP (7700)
Auth      : BRAIN_TOKEN_MCP dans MYSECRETS → passé via header x-api-key

Outils exposés :
  brain_search(query, top)  → recherche sémantique (zones public + work)
  brain_boot()              → contexte de boot (3 queries ciblées)
  brain_workflows()         → workflows actifs (claims BSI ouverts)
  brain_agents(name)        → liste des agents ou contenu d'un agent
  brain_decisions(last)     → dernières décisions architecturales (ADRs)
  brain_focus()             → focus actuel du brain (direction + projets + blockers)
  brain_write(path, content)→ écrire un fichier dans le brain via PUT /brain/{path}

Usage :
  python3 brain-engine/mcp_server.py                 → port 7701 (défaut)
  BRAIN_MCP_PORT=8000 python3 brain-engine/mcp_server.py

Connexion Claude Code :
  claude mcp add brain --transport http http://localhost:7701/mcp/

Auth dans Claude Code :
  Settings → MCP → brain → Headers → x-api-key: <BRAIN_TOKEN_MCP>
"""

import os
import sys
import logging
from pathlib import Path

from mcp.server.fastmcp import FastMCP
from starlette.requests import Request
from starlette.responses import JSONResponse

sys.path.insert(0, str(Path(__file__).parent))
from rag import run_boot_queries, run_single_query, format_compact, format_full

# ── Config ─────────────────────────────────────────────────────────────────────

BRAIN_MCP_PORT  = int(os.getenv('BRAIN_MCP_PORT', 7701))
BRAIN_TOKEN_MCP = os.getenv('BRAIN_TOKEN_MCP') or os.getenv('BRAIN_TOKEN')

# Scopes autorisés pour le token MCP
MCP_SCOPES = ['public', 'work']

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger('brain-mcp')

# ── MCP Server ─────────────────────────────────────────────────────────────────

mcp = FastMCP(
    name='brain',
    instructions=(
        'Brain-as-a-Service — mémoire sémantique du brain. '
        'Utilise brain_search pour trouver du contexte précis sur un sujet. '
        'Utilise brain_boot au démarrage d\'une session pour charger le contexte actif. '
        'Les résultats sont des chunks de fichiers markdown classés par pertinence. '
        'Zones accessibles : focus, todos, projets, agents, infrastructure.'
    ),
)


# ── Auth middleware ─────────────────────────────────────────────────────────────

class BrainAuthMiddleware:
    """
    Wrapper ASGI — vérifie x-api-key avant chaque requête MCP.
    Note : les dunders Python (__call__) sont résolus sur la classe, pas l'instance.
    Un vrai wrapper ASGI est requis (monkey-patch d'instance ne fonctionne pas).
    """
    def __init__(self, app, token: str | None):
        self._app  = app
        self._token = token

    async def __call__(self, scope, receive, send):
        if scope['type'] == 'http' and self._token:
            headers  = dict(scope.get('headers', []))
            api_key  = headers.get(b'x-api-key', b'').decode()
            if api_key != self._token:
                async def _send_401():
                    await send({'type': 'http.response.start', 'status': 401,
                                'headers': [(b'content-type', b'application/json')]})
                    await send({'type': 'http.response.body',
                                'body': b'{"error":"Unauthorized"}', 'more_body': False})
                await _send_401()
                return
        await self._app(scope, receive, send)


mcp_app = BrainAuthMiddleware(mcp.streamable_http_app(), BRAIN_TOKEN_MCP)


# ── Outils MCP ─────────────────────────────────────────────────────────────────

@mcp.tool()
def brain_search(query: str, top: int = 5, full: bool = False) -> str:
    """
    Recherche sémantique dans le brain.

    Args:
        query : Question en langage naturel (ex: "comment fonctionne le BSI v2 ?")
        top   : Nombre de résultats (défaut: 5, max recommandé: 10)
        full  : True = chunks complets, False = extraits 120 chars (défaut)

    Returns:
        Bloc markdown avec les chunks les plus pertinents, triés par score.
        Chaque résultat indique le filepath source et un extrait du contenu.
    """
    log.info('brain_search query=%r top=%d full=%s', query, top, full)
    results = run_single_query(query, top_k=top, allowed_scopes=MCP_SCOPES)
    if not results:
        return f'Aucun résultat pour : {query!r}'
    label = f'brain_search — {query}'
    return format_full(results, label=label) if full else format_compact(results, label=label)


@mcp.tool()
def brain_state() -> str:
    """
    Environnement fondamental du brain — dérivé en temps réel, jamais stocké.

    Retourne les services actifs (pm2), la version brain (git), et les ports
    configurés. Layer 2 uniquement (localhost).

    À appeler en début de session pour connaître l'état de l'infrastructure
    sans avoir à demander "quel port ? quel service tourne ?".

    Returns:
        Bloc markdown structuré avec hostname, version, pm2 status, ports.
        "Indisponible" si brain-engine hors ligne.
    """
    import json
    import urllib.request
    log.info('brain_state')
    try:
        with urllib.request.urlopen('http://127.0.0.1:7700/state', timeout=3) as resp:
            data = json.loads(resp.read())
        lines = [f'## Environnement fondamental\n']
        lines.append(f"**Machine** : {data.get('hostname', '?')}")
        lines.append(f"**Brain** : {data.get('brain_version', '?')}\n")
        pm2 = data.get('pm2', [])
        if pm2:
            lines.append('**Services (pm2)**')
            lines.append('| Nom | Status | Restarts |')
            lines.append('|-----|--------|---------|')
            for p in pm2:
                icon = '🟢' if p.get('status') == 'online' else '🔴'
                lines.append(f"| {p['name']} | {icon} {p.get('status','?')} | {p.get('restarts',0)} |")
        ports = data.get('ports', {})
        if ports:
            lines.append(f"\n**Ports** : engine={ports.get('brain_engine','?')} · mcp={ports.get('brain_mcp','?')} · key={ports.get('brain_key','?')}")
        return '\n'.join(lines)
    except Exception as exc:
        log.warning('brain_state failed: %s', exc)
        return f'Environnement indisponible : {exc}'


@mcp.tool()
def brain_boot() -> str:
    """
    Charge le contexte de boot du brain.

    Séquence :
    1. brain/now.md — slot garanti (push de la session précédente)
    2. brain_state() — environnement fondamental dérivé (pm2, ports)
    3. 3 queries RAG ciblées (décisions récentes, todos prioritaires, sprint actif)

    À appeler en début de session pour enrichir le contexte sans saturer le
    context window. Exit silencieux si Ollama indisponible.

    Returns:
        Bloc markdown additif avec contexte de boot complet.
    """
    log.info('brain_boot')
    sections = []

    # 1. Slot garanti — brain/now.md
    now_path = Path(__file__).parent.parent / 'brain' / 'now.md'
    if now_path.exists():
        try:
            content = now_path.read_text(encoding='utf-8').strip()
            if content:
                sections.append(content)
        except Exception:
            pass

    # 2. Environnement dérivé
    env = brain_state()
    if env and 'Indisponible' not in env:
        sections.append(env)

    # 3. RAG queries
    results = run_boot_queries(allowed_scopes=MCP_SCOPES)
    if results:
        sections.append(format_compact(results, label='brain_boot'))

    return '\n\n---\n\n'.join(sections) if sections else ''


@mcp.tool()
def brain_workflows() -> str:
    """
    Retourne les workflows actifs du brain (claims BSI ouverts).

    Returns:
        Bloc markdown avec les workflows en cours : nom, projet, étapes, statuts.
        Utile en début de session pour connaître l'état des sprints actifs.
    """
    import json
    import urllib.request
    log.info('brain_workflows')
    try:
        url = f'http://127.0.0.1:7700/workflows'
        with urllib.request.urlopen(url, timeout=3) as resp:
            data = json.loads(resp.read())
        workflows = data.get('workflows', [])
        if not workflows:
            return 'Aucun workflow actif.'
        lines = ['## Workflows actifs\n']
        for wf in workflows:
            lines.append(f"### {wf.get('name', wf.get('id', '?'))} — {wf.get('project', '')}")
            for step in wf.get('steps', []):
                status = step.get('status', '?')
                icon = {'done': '✅', 'in-progress': '🔄', 'pending': '⬜',
                        'gate': '🔶', 'blocked': '🔴', 'fail': '❌'}.get(status, '•')
                gate = ' [GATE]' if step.get('isGate') else ''
                lines.append(f"  {icon} {step.get('label', step.get('id', '?'))}{gate}")
            lines.append('')
        return '\n'.join(lines)
    except Exception as exc:
        log.warning('brain_workflows failed: %s', exc)
        return f'Workflows indisponibles : {exc}'


@mcp.tool()
def brain_agents(name: str = '') -> str:
    """
    Retourne les agents disponibles dans le brain.

    Args:
        name : Nom de l'agent (sans extension .md). Si vide, retourne la liste
               complète. Exemple : "debug", "vps", "code-review".

    Returns:
        Liste des agents en tableau markdown (nom, status, context_tier, description)
        ou contenu brut du fichier agents/{name}.md si name fourni.
        Fallback filesystem si brain-engine indisponible.
    """
    import json
    import urllib.request
    BRAIN_ROOT = Path(__file__).parent.parent
    log.info('brain_agents name=%r', name)

    if name:
        agent_path = BRAIN_ROOT / 'agents' / f'{name}.md'
        if not agent_path.exists():
            return f'Agent introuvable : agents/{name}.md'
        return agent_path.read_text(encoding='utf-8')

    # Liste via brain-engine
    try:
        with urllib.request.urlopen('http://127.0.0.1:7700/agents', timeout=3) as resp:
            data = json.loads(resp.read())
        agents = data.get('agents', data) if isinstance(data, dict) else data
        if not agents:
            return 'Aucun agent trouvé.'
        lines = ['## Agents disponibles\n', '| Nom | Status | Tier | Description |',
                 '|-----|--------|------|-------------|']
        for ag in agents:
            nom   = ag.get('name', ag.get('id', '?'))
            stat  = ag.get('status', '—')
            tier  = ag.get('context_tier', '—')
            desc  = (ag.get('boot_summary') or ag.get('description') or '')[:80]
            lines.append(f'| {nom} | {stat} | {tier} | {desc} |')
        return '\n'.join(lines)
    except Exception as exc:
        log.warning('brain_agents HTTP failed, fallback filesystem: %s', exc)

    # Fallback filesystem
    agents_dir = BRAIN_ROOT / 'agents'
    if not agents_dir.exists():
        return 'Répertoire agents/ introuvable.'
    files = sorted(agents_dir.glob('*.md'))
    if not files:
        return 'Aucun agent trouvé.'
    lines = ['## Agents disponibles (filesystem)\n', '| Nom |', '|-----|']
    for f in files:
        lines.append(f'| {f.stem} |')
    return '\n'.join(lines)


@mcp.tool()
def brain_decisions(last: int = 5) -> str:
    """
    Retourne les dernières décisions architecturales (ADRs).

    Lit les fichiers profil/decisions/*.md, triés par nom décroissant
    (numérotation → plus récent en premier).

    Args:
        last : Nombre d'ADRs à retourner (défaut: 5).

    Returns:
        Bloc markdown avec numéro, titre, statut, date et résumé (150 chars)
        de chaque ADR. "Aucune décision trouvée" si le répertoire est absent.
    """
    BRAIN_ROOT = Path(__file__).parent.parent
    log.info('brain_decisions last=%d', last)
    decisions_dir = BRAIN_ROOT / 'profil' / 'decisions'
    if not decisions_dir.exists():
        return 'Aucune décision trouvée.'
    files = sorted(decisions_dir.glob('*.md'), reverse=True)[:last]
    if not files:
        return 'Aucune décision trouvée.'
    lines = ['## Décisions architecturales récentes\n']
    for f in files:
        body = f.read_text(encoding='utf-8')
        # Extraire titre (première ligne # ...)
        titre = next((l.lstrip('# ').strip() for l in body.splitlines() if l.startswith('#')), f.stem)
        # Extraire statut et date depuis les premières lignes (format ADR standard)
        statut = '—'
        date   = '—'
        for line in body.splitlines():
            ll = line.lower()
            if ll.startswith('statut') or ll.startswith('status') or ll.startswith('- statut'):
                statut = line.split(':', 1)[-1].strip()
            if ll.startswith('date') or ll.startswith('- date'):
                date = line.split(':', 1)[-1].strip()
        # Résumé : premier paragraphe non-titre non-vide de moins de 150 chars
        resume = ''
        for line in body.splitlines():
            if line.startswith('#') or not line.strip():
                continue
            resume = line.strip()[:150]
            break
        lines.append(f'### {f.stem} — {titre}')
        lines.append(f'**Statut** : {statut} | **Date** : {date}')
        lines.append(f'{resume}')
        lines.append('')
    return '\n'.join(lines)


@mcp.tool()
def brain_focus() -> str:
    """
    Retourne le focus actuel du brain.

    Lit BRAIN_ROOT/focus.md et retourne le contenu brut.
    Utile pour connaître la direction active, les projets en cours et les blockers.

    Returns:
        Contenu complet de focus.md ou "focus.md non trouvé".
    """
    BRAIN_ROOT = Path(__file__).parent.parent
    log.info('brain_focus')
    focus_path = BRAIN_ROOT / 'focus.md'
    if not focus_path.exists():
        return 'focus.md non trouvé.'
    return focus_path.read_text(encoding='utf-8')


@mcp.tool()
def brain_write(path: str, content: str) -> str:
    """
    Écrit un fichier dans le brain via PUT /brain/{path}.

    Réservé aux sessions owner. Permet de mettre à jour n'importe quel fichier
    du brain depuis une session Claude avec MCP actif.

    Args:
        path    : Chemin relatif dans le brain (ex: "focus.md", "todos/sprint.md").
        content : Contenu complet du fichier à écrire.

    Returns:
        JSON {"ok": true, "path": path} en cas de succès,
        message d'erreur sinon. 403 → "Requiert tier owner".
    """
    import json
    import urllib.request
    log.info('brain_write path=%r len=%d', path, len(content))
    url     = f'http://127.0.0.1:7700/brain/{path}'
    payload = json.dumps({'content': content}).encode('utf-8')
    req     = urllib.request.Request(
        url, data=payload, method='PUT',
        headers={'Content-Type': 'application/json'},
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            body = resp.read()
            return json.dumps({'ok': True, 'path': path})
    except urllib.error.HTTPError as exc:
        if exc.code == 403:
            return 'Requiert tier owner — écriture refusée.'
        return f'Erreur {exc.code} : {exc.reason}'
    except Exception as exc:
        log.warning('brain_write failed: %s', exc)
        return f'brain_write indisponible : {exc}'


# ── Entrypoint ─────────────────────────────────────────────────────────────────

if __name__ == '__main__':
    import uvicorn
    auth_status = 'token actif' if BRAIN_TOKEN_MCP else 'auth désactivée (dev)'
    log.info('Brain MCP BE-4 — port %d — %s — scopes: %s',
             BRAIN_MCP_PORT, auth_status, MCP_SCOPES)
    uvicorn.run(mcp_app, host='0.0.0.0', port=BRAIN_MCP_PORT,
                forwarded_allow_ips='*', proxy_headers=True)
