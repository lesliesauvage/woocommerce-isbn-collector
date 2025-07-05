#!/bin/bash
# Ce fichier charge les clés depuis settings.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"

# Les clés sont déjà définies dans settings.sh
# Ce fichier existe juste pour compatibilité
