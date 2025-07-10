#!/bin/bash
# Autres APIs (Gallica, WorldCat, Archive.org)

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"  # Fonctions sécurisées
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

# Gallica API
fetch_gallica() {
    local isbn=$1
    local product_id=$2
    local language=$3
    
    if [[ "$language" != "fr" ]]; then
        return 1
    fi
    
    sleep 0.5
    log "  → Gallica API (livre français)..."
    
    local gallica_url="https://gallica.bnf.fr/services/OAIRecord?ark=cb$isbn"
    local gallica_response=$(curl -s --connect-timeout 10 --max-time 30 -H "Accept-Charset: UTF-8" "$gallica_url")
    ((api_calls_gallica++))
    export api_calls_gallica
    
    if [ -n "$gallica_response" ] && [[ "$gallica_response" == *"record"* ]]; then
        local ga_title=$(echo "$gallica_response" | grep -oP '(?<=<dc:title>)[^<]+' | head -1 || echo "")
        local ga_description=$(echo "$gallica_response" | grep -oP '(?<=<dc:description>)[^<]+' | head -1 || echo "")
        
        if [ -n "$ga_title" ]; then
            log "    ✓ Gallica : trouvé '$ga_title'"
            safe_store_meta "$product_id" "_ga_title" "$ga_title"
            safe_store_meta "$product_id" "_ga_description" "$ga_description"
            
            echo "description:$ga_description"
            return 0
        fi
    fi
    
    log "    ✗ Gallica : pas de résultat"
    return 1
}

# WorldCat API
fetch_worldcat() {
    local isbn=$1
    local product_id=$2
    
    sleep 0.5
    log "  → WorldCat API..."
    
    local worldcat_url="http://www.worldcat.org/webservices/catalog/content/isbn/${isbn}?format=json"
    local worldcat_response=$(curl -s --connect-timeout 10 --max-time 30 "$worldcat_url")
    ((api_calls_other++))
    export api_calls_other
    
    if [ -n "$worldcat_response" ] && [[ ! "$worldcat_response" =~ "error" ]]; then
        local wc_description=$(echo "$worldcat_response" | grep -oP '(?<=<summary>)[^<]+' | head -1 || echo "")
        
        if [ -n "$wc_description" ] && [ ${#wc_description} -gt 30 ]; then
            log "    ✓ WorldCat : description trouvée"
            safe_store_meta "$product_id" "_wc_description" "$wc_description"
            echo "description:$wc_description"
            return 0
        fi
    fi
    
    log "    ✗ WorldCat : pas de résultat"
    return 1
}

# Archive.org API
fetch_archive_org() {
    local isbn=$1
    local product_id=$2
    
    sleep 0.5
    log "  → Archive.org API..."
    
    local archive_url="https://archive.org/advancedsearch.php?q=isbn:${isbn}&fl=description,title,creator,publisher&output=json"
    local archive_response=$(curl -s --connect-timeout 10 --max-time 30 "$archive_url")
    ((api_calls_other++))
    export api_calls_other
    
    if [ -n "$archive_response" ] && [[ "$archive_response" == *"docs"* ]]; then
        local arc_description=$(echo "$archive_response" | jq -r '.response.docs[0].description' 2>/dev/null)
        
        if [ -n "$arc_description" ] && [ "$arc_description" != "null" ] && [ ${#arc_description} -gt 30 ]; then
            log "    ✓ Archive.org : description trouvée"
            safe_store_meta "$product_id" "_arc_description" "$arc_description"
            echo "description:$arc_description"
            return 0
        fi
    fi
    
    log "    ✗ Archive.org : pas de résultat"
    return 1
}
