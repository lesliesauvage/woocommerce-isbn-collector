#!/bin/bash
# API ISBNdb

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

fetch_isbndb() {
    local isbn=$1
    local product_id=$2
    
    sleep 0.5
    log "  → ISBNdb API..."
    
    local isbndb_response=$(curl -s --connect-timeout 10 --max-time 30 -H "Authorization: $ISBNDB_KEY" -H "Accept-Charset: UTF-8" "https://api2.isbndb.com/book/$isbn")
    ((api_calls_isbndb++))
    export api_calls_isbndb
    
    if [ -n "$isbndb_response" ] && [[ ! "$isbndb_response" =~ "unauthorized" ]] && [[ "$isbndb_response" == *"book"* ]]; then
        # Extraction des données principales
        local i_title=$(extract_json_value "$isbndb_response" '.book.title')
        local i_authors=$(extract_json_array "$isbndb_response" '.book.authors[]?')
        local i_publisher=$(extract_json_value "$isbndb_response" '.book.publisher')
        local i_synopsis=$(extract_json_value "$isbndb_response" '.book.synopsis')
        local i_binding=$(extract_json_value "$isbndb_response" '.book.binding')
        local i_pages=$(extract_json_value "$isbndb_response" '.book.pages' "0")
        local i_subjects=$(extract_json_array "$isbndb_response" '.book.subjects[]?' ', ')
        local i_msrp=$(extract_json_value "$isbndb_response" '.book.msrp' "0")
        local i_language=$(extract_json_value "$isbndb_response" '.book.language')
        
        log "    ✓ ISBNdb : trouvé reliure '$i_binding'"
        
        # Stocker les données
        store_meta "$product_id" "_i_title" "$i_title"
        store_meta "$product_id" "_i_authors" "$i_authors"
        store_meta "$product_id" "_i_publisher" "$i_publisher"
        store_meta "$product_id" "_i_synopsis" "$i_synopsis"
        store_meta "$product_id" "_i_binding" "$i_binding"
        store_meta "$product_id" "_i_pages" "$i_pages"
        store_meta "$product_id" "_i_subjects" "$i_subjects"
        store_meta "$product_id" "_i_msrp" "$i_msrp"
        store_meta "$product_id" "_i_language" "$i_language"
        
        # Retourner les données importantes
        echo "title:$i_title|authors:$i_authors|publisher:$i_publisher|synopsis:$i_synopsis|binding:$i_binding|pages:$i_pages|subjects:$i_subjects|msrp:$i_msrp|language:$i_language"
        return 0
    else
        log "    ✗ ISBNdb : pas de résultat"
        return 1
    fi
}
