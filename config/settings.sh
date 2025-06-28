#!/bin/bash

# Configuration encodage
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export LC_CTYPE=C.UTF-8

# Configuration base de données
export DB_HOST="localhost"
export DB_USER="wordpress"
export DB_PASSWORD="e96e30c154b7a661211a793bbac6416dcbaf9843ff19fb54"
export DB_NAME="savoir"
export TABLE_PREFIX="wp_28_"

# Site WordPress
export SITE_ID="28"
export SITE_URL="https://ecolivre.fr"

# Clés API
export ISBNDB_API_KEY="YOUR_ISBNDB_KEY"
export GOOGLE_BOOKS_API_KEY=""
export GROQ_API_KEY="YOUR_GROQ_KEY"

# Chemins
export LOG_DIR="/var/www/scripts-home-root/isbn/logs"
export JSON_DIR="/var/www/scripts-home-root/isbn"

# Options
export DEBUG="0"
export MAX_RETRIES="3"
export TIMEOUT="30"
