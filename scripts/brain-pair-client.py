#!/usr/bin/env python3
"""brain-pair client — laptop/new machine side (ADR-041)
Scans LAN for a brain-pair server, sends code, receives config.

Usage: python3 brain-pair-client.py <brain_root> <code>
"""

import json
import os
import socket
import sys
import time

BRAIN_ROOT = sys.argv[1]
CODE = sys.argv[2]
BROADCAST_PORT = 7711   # UDP listen port
SCAN_TIMEOUT = 30       # seconds to scan for server


def get_ssh_pubkey():
    """Read the local SSH public key."""
    for name in ["id_ed25519.pub", "id_rsa.pub", "id_ecdsa.pub"]:
        path = os.path.expanduser(f"~/.ssh/{name}")
        if os.path.exists(path):
            with open(path) as f:
                return f.read().strip()
    return ""


def get_local_machine():
    """Read machine name from brain-compose.local.yml."""
    try:
        import yaml
        compose_path = os.path.join(BRAIN_ROOT, "brain-compose.local.yml")
        with open(compose_path) as f:
            compose = yaml.safe_load(f)
        return compose.get("machine", socket.gethostname())
    except Exception:
        return socket.gethostname()


def scan_for_server():
    """Listen for UDP broadcast from brain-pair server."""
    print(f"🔍 Scan du LAN pour brain-pair server ({SCAN_TIMEOUT}s)...")

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.settimeout(2)
    sock.bind(("0.0.0.0", BROADCAST_PORT))

    start = time.time()
    while time.time() - start < SCAN_TIMEOUT:
        try:
            data, addr = sock.recvfrom(1024)
            msg = json.loads(data.decode())
            if msg.get("type") == "brain-pair":
                server_ip = msg["ip"]
                server_port = msg["port"]
                print(f"   ✅ Serveur trouvé : {server_ip}:{server_port}")
                sock.close()
                return server_ip, server_port
        except socket.timeout:
            continue
        except Exception:
            continue

    sock.close()
    return None, None


def do_handshake(server_ip, server_port, code, machine, ssh_pubkey):
    """Connect to server, send code, receive config."""
    print(f"🤝 Handshake avec {server_ip}:{server_port}...")

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(15)
    sock.connect((server_ip, server_port))

    request = json.dumps({
        "code": code,
        "machine": machine,
        "ssh_pubkey": ssh_pubkey,
    })
    sock.sendall(request.encode())

    data = sock.recv(8192).decode()
    sock.close()

    response = json.loads(data)
    return response


def apply_config(response, server_ip):
    """Apply received config to local brain-compose.local.yml."""
    import yaml

    if response.get("status") != "ok":
        print(f"❌ Pairing refusé : {response.get('msg', 'unknown error')}")
        return False

    server_machine = response["machine"]
    api_key = response.get("api_key")
    engine_port = response.get("brain_engine_port", 7700)

    compose_path = os.path.join(BRAIN_ROOT, "brain-compose.local.yml")

    # Read or create compose
    if os.path.exists(compose_path):
        with open(compose_path) as f:
            compose = yaml.safe_load(f) or {}
    else:
        compose = {
            "machine": get_local_machine(),
            "instances": {},
            "kernel_path": BRAIN_ROOT,
        }

    # Add peer
    if "peers" not in compose:
        compose["peers"] = {}

    compose["peers"][server_machine] = {
        "url": f"http://{server_ip}:{engine_port}",
        "active": True,
    }

    # Inject API key if provided
    if api_key:
        instances = compose.get("instances", {})
        # Find or create active instance
        active_found = False
        for name, inst in instances.items():
            if inst.get("active"):
                inst["brain_api_key"] = api_key
                active_found = True
                break
        if not active_found:
            machine = compose.get("machine", "unknown")
            instances[machine] = {
                "active": True,
                "brain_name": machine,
                "brain_api_key": api_key,
                "path": BRAIN_ROOT,
            }
        compose["instances"] = instances

    with open(compose_path, "w") as f:
        yaml.dump(compose, f, default_flow_style=False, allow_unicode=True)

    print(f"  ✅ Peer {server_machine} ({server_ip}) ajouté")
    if api_key:
        print(f"  ✅ Brain API Key injectée dans brain-compose.local.yml")
    print(f"  ✅ brain-compose.local.yml mis à jour")

    # Add server host to known_hosts
    os.system(f"ssh-keyscan -H {server_ip} >> ~/.ssh/known_hosts 2>/dev/null")
    print(f"  ✅ Fingerprint {server_ip} ajoutée à known_hosts")

    return True


def main():
    machine = get_local_machine()
    ssh_pubkey = get_ssh_pubkey()

    print(f"🔗 brain-pair join — machine : {machine}")
    if not ssh_pubkey:
        print(f"⚠️  Aucune clé SSH trouvée — ssh-keygen recommandé")
    print()

    # Scan LAN
    server_ip, server_port = scan_for_server()
    if not server_ip:
        print(f"❌ Aucun serveur brain-pair trouvé sur le LAN")
        print(f"   Vérifier : brain-pair.sh start sur la machine source")
        sys.exit(1)

    # Handshake
    response = do_handshake(server_ip, server_port, CODE, machine, ssh_pubkey)

    # Apply config
    success = apply_config(response, server_ip)
    if success:
        print(f"\n✅ Pairing terminé !")
        print(f"   Vérifier : bash scripts/bsi-query.sh peers")
        print(f"   Secrets  : bash scripts/brain-secrets-sync.sh status")
    else:
        print(f"\n❌ Pairing échoué")
        sys.exit(1)


if __name__ == "__main__":
    main()
