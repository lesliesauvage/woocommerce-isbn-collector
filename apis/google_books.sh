#!/bin/bash
# API Google Books

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

fetch_google_books() {
    local isbn=$1
    local product_id=$2
    
    log "  → Google Books API..."
    
    local google_url="https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn"
    if [ -n "$GOOGLE_API_KEY" ]; then
        google_url="${google_url}&key=$GOOGLE_API_KEY"
    fi
    
    local google_response=$(curl -s --connect-timeout 10 --max-time 30 -H "Accept-Charset: UTF-8" "$google_url")
    ((api_calls_google++))
    export api_calls_google
    
    if [ -n "$google_response" ] && [ "$google_response" != "null" ] && [[ "$google_response" == *"items"* ]]; then
        # Extraction des données principales
        local g_title=$(extract_json_value "$google_response" '.items[0].volumeInfo.title')
        local g_authors=$(extract_json_array "$google_response" '.items[0].volumeInfo.authors[]?')
        local g_publisher=$(extract_json_value "$google_response" '.items[0].volumeInfo.publisher')
        local g_description=$(extract_json_value "$google_response" '.items[0].volumeInfo.description')
        local g_pageCount=$(extract_json_value "$google_response" '.items[0].volumeInfo.pageCount' "0")
        local g_categories=$(extract_json_array "$google_response" '.items[0].volumeInfo.categories[]?' ', ')
        local g_language=$(extract_json_value "$google_response" '.items[0].volumeInfo.language' "fr")
        
        log "    ✓ Google Books : trouvé '$g_title'"
        
        # Stocker les données
        store_meta "$product_id" "_g_title" "$g_title"
        store_meta "$product_id" "_g_authors" "$g_authors"
        store_meta "$product_id" "_g_publisher" "$g_publisher"
        store_meta "$product_id" "_g_description" "$g_description"
        store_meta "$product_id" "_g_pageCount" "$g_pageCount"
        store_meta "$product_id" "_g_categories" "$g_categories"
        store_meta "$product_id" "_g_language" "$g_language"
        
        # Retourner les données importantes
        echo "title:$g_title|authors:$g_authors|publisher:$g_publisher|description:$g_description|pages:$g_pageCount|language:$g_language|categories:$g_categories"
        return 0
    else
        log "    ✗ Google Books : pas de résultat"
        return 1
    fi
}
