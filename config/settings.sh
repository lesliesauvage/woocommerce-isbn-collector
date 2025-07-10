#!/bin/bash
echo "[START: settings.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# Configuration générale du projet ISBN

# Base de données WordPress
DB_HOST="localhost"
DB_USER="wordpress"
DB_PASSWORD="e96e30c154b7a661211a793bbac6416dcbaf9843ff19fb54"
DB_NAME="savoir"
SITE_ID="28"

# Répertoires
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
LOG_DIR="$SCRIPT_DIR/logs"

# Charger les credentials (si le fichier existe)
CREDENTIALS_FILE="$SCRIPT_DIR/config/credentials.sh"
if [ -f "$CREDENTIALS_FILE" ]; then
    source "$CREDENTIALS_FILE"
else
    echo "⚠️  Fichier credentials.sh manquant !"
    echo "Créez config/credentials.sh avec vos clés API"
    exit 1
fi

# URLs des APIs
GOOGLE_BOOKS_API="https://www.googleapis.com/books/v1/volumes"
ISBNDB_API_URL="https://api2.isbndb.com"
GROQ_API_URL="https://api.groq.com/openai/v1/chat/completions"

# Modèle Groq
GROQ_MODEL="llama-3.2-90b-text-preview"

# Configuration par défaut
DEFAULT_STATE="très bon"
DEFAULT_ZIPCODE="76000"

# Mode debug (0=non, 1=oui)
DEBUG="${DEBUG:-0}"

echo "[END: settings.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
