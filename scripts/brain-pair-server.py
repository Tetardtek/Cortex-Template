#!/usr/bin/env python3
"""brain-pair server — desktop side (ADR-041)
Generates a 6-digit code, broadcasts on LAN, waits for client handshake.
Exchanges: API key, SSH pubkey, peer config. Never MYSECRETS.

Usage: python3 brain-pair-server.py <brain_root>
"""

import json
import os
import random
import socket
import sys
import threading
import time
import subprocess

BRAIN_ROOT = sys.argv[1]
PAIR_PORT = 7710        # TCP handshake port
BROADCAST_PORT = 7711   # UDP broadcast port
CODE_TTL = 120          # seconds
TEST_CODE = os.environ.get("BRAIN_PAIR_TEST_CODE")  # force code for testing

def get_machine_info():
    """Read local machine config."""
    import yaml
    compose_path = os.path.join(BRAIN_ROOT, "brain-compose.local.yml")
    with open(compose_path) as f:
        compose = yaml.safe_load(f)

    machine = compose.get("machine", "unknown")
    local_ip = get_local_ip()

    # Read brain API key
    instances = compose.get("instances", {})
    api_key = None
    for name, inst in instances.items():
        if inst.get("active"):
            api_key = inst.get("brain_api_key")
            break

    return {
        "machine": machine,
        "ip": local_ip,
        "brain_engine_port": 7700,
        "api_key": api_key,
    }


def get_local_ip():
    """Get the LAN IP of this machine."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))
        return s.getsockname()[0]
    finally:
        s.close()


def broadcast_presence(code, stop_event):
    """Broadcast pairing availability on LAN via UDP."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.settimeout(1)

    local_ip = get_local_ip()
    msg = json.dumps({
        "type": "brain-pair",
        "ip": local_ip,
        "port": PAIR_PORT,
    }).encode()

    while not stop_event.is_set():
        try:
            sock.sendto(msg, ("<broadcast>", BROADCAST_PORT))
        except OSError:
            pass
        time.sleep(1)
    sock.close()


def handle_client(conn, addr, code, machine_info):
    """Handle a pairing handshake from a client."""
    conn.settimeout(30)
    try:
        data = conn.recv(4096).decode()
        request = json.loads(data)

        # Verify code
        if request.get("code") != code:
            conn.sendall(json.dumps({"status": "error", "msg": "Invalid code"}).encode())
            print(f"❌ Code invalide depuis {addr[0]}")
            return False

        client_machine = request.get("machine", "unknown")
        client_ssh_pubkey = request.get("ssh_pubkey", "")

        print(f"✅ Code vérifié — pairing avec {client_machine} ({addr[0]})")

        # Build response (what we send to the client)
        response = {
            "status": "ok",
            "machine": machine_info["machine"],
            "ip": machine_info["ip"],
            "brain_engine_port": machine_info["brain_engine_port"],
            "api_key": machine_info["api_key"],
        }
        conn.sendall(json.dumps(response).encode())

        # Add client SSH key to authorized_keys
        if client_ssh_pubkey:
            ak_path = os.path.expanduser("~/.ssh/authorized_keys")
            comment = f" # brain-pair:{client_machine}"
            key_line = client_ssh_pubkey.strip() + comment + "\n"

            # Check if already present
            existing = ""
            if os.path.exists(ak_path):
                with open(ak_path) as f:
                    existing = f.read()

            if client_ssh_pubkey.strip().split()[1] not in existing:
                with open(ak_path, "a") as f:
                    f.write(key_line)
                print(f"  ✅ Clé SSH de {client_machine} ajoutée à authorized_keys")
            else:
                print(f"  ℹ️  Clé SSH de {client_machine} déjà présente")

        # Add peer to brain-compose.local.yml
        import yaml
        compose_path = os.path.join(BRAIN_ROOT, "brain-compose.local.yml")
        with open(compose_path) as f:
            compose = yaml.safe_load(f)

        if "peers" not in compose:
            compose["peers"] = {}

        compose["peers"][client_machine] = {
            "url": f"http://{addr[0]}:7700",
            "active": True,
        }

        with open(compose_path, "w") as f:
            yaml.dump(compose, f, default_flow_style=False, allow_unicode=True)

        print(f"  ✅ Peer {client_machine} ajouté à brain-compose.local.yml")
        return True

    except Exception as e:
        print(f"❌ Erreur handshake : {e}")
        return False
    finally:
        conn.close()


def main():
    code = TEST_CODE or f"{random.randint(0, 999999):06d}"
    machine_info = get_machine_info()

    print(f"🔗 brain-pair — en attente de connexion")
    print(f"   Machine : {machine_info['machine']} ({machine_info['ip']})")
    print(f"")
    print(f"   Code : {code}")
    print(f"")
    print(f"   Sur l'autre machine : brain-pair.sh join {code}")
    print(f"   Expire dans {CODE_TTL}s...")
    print()

    # Start broadcast
    stop_event = threading.Event()
    broadcast_thread = threading.Thread(target=broadcast_presence, args=(code, stop_event), daemon=True)
    broadcast_thread.start()

    # Listen for TCP connection
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.settimeout(CODE_TTL)
    server.bind(("0.0.0.0", PAIR_PORT))
    server.listen(1)

    try:
        conn, addr = server.accept()
        success = handle_client(conn, addr, code, machine_info)
        if success:
            print(f"\n✅ Pairing terminé avec succès !")
            print(f"   Vérifier : bash scripts/bsi-query.sh peers")
        else:
            print(f"\n❌ Pairing échoué")
    except socket.timeout:
        print(f"\n⏱  Code expiré ({CODE_TTL}s) — relancer brain-pair.sh start")
    finally:
        stop_event.set()
        server.close()


if __name__ == "__main__":
    main()
