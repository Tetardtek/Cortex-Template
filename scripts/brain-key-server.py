#!/usr/bin/env python3
"""
brain-key-server.py — Serveur de validation des cles API brain (Phase 2a)

Ce script est un STUB — la phase 2a (serveur VPS de cles) n'est pas encore implementee.
Il existe pour que brain-launch.sh puisse verifier sa presence sans echouer.

Futur : serveur HTTP minimal qui valide les brain_api_key et retourne les feature_sets.
Deploye sur VPS, jamais dans le repo brain/ (keys.yml = hors versionning).

Usage futur :
  python3 scripts/brain-key-server.py --port 8800
  python3 scripts/brain-key-server.py --config /etc/brain-keys/keys.yml
"""

import sys

def main():
    print("brain-key-server: STUB — phase 2a non implementee.", file=sys.stderr)
    print("Voir scripts/brain-launch.sh section 2a pour le plan d'implementation.", file=sys.stderr)
    sys.exit(1)

if __name__ == "__main__":
    main()
