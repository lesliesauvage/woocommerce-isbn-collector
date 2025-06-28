#!/bin/bash
# APIs des marketplaces et librairies

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

# Amazon France (web scraping)
fetch_amazon() {
    local isbn=$1
    local product_id=$2
    
    sleep 0.5
    log "  → Amazon France (scraping)..."
    
    local amazon_search_url="https://www.amazon.fr/s?k=${isbn}"
    local amazon_search=$(curl -s --connect-timeout 10 --max-time 30 -A "Mozilla/5.0" "$amazon_search_url")
    ((api_calls_other++))
    export api_calls_other
    
    local product_asin=$(echo "$amazon_search" | grep -oP 'data-asin="[A-Z0-9]+"' | head -1 | sed 's/data-asin="//;s/"//')
    
    if [ -n "$product_asin" ]; then
        sleep 1
        local product_url="https://www.amazon.fr/dp/$product_asin"
        local product_page=$(curl -s --connect-timeout 10 --max-time 30 -A "Mozilla/5.0" "$product_url")
        
        local amazon_desc=$(echo "$product_page" | grep -A10 'id="feature-bullets"' | sed 's/<[^>]*>//g' | tr '\n' ' ' | sed 's/^ *//;s/ *$//')
        
        if [ -n "$amazon_desc" ] && [ ${#amazon_desc} -gt 50 ]; then
            log "    ✓ Amazon : description trouvée"
            store_meta "$product_id" "_amazon_description" "$amazon_desc"
            echo "description:$amazon_desc"
            return 0
        fi
    fi
    
    log "    ✗ Amazon : pas de résultat"
    return 1
}

# Les autres fonctions restent identiques...
# Pour économiser de l'espace, je ne les inclus pas toutes ici
# mais elles doivent être ajoutées dans le fichier réel
