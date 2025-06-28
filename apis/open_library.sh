#!/bin/bash
# API Open Library

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

fetch_open_library() {
    local isbn=$1
    local product_id=$2
    
    sleep 0.5
    log "  → Open Library API..."
    
    local ol_response=$(curl -s --connect-timeout 10 --max-time 30 -H "Accept-Charset: UTF-8" "https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data")
    ((api_calls_ol++))
    export api_calls_ol
    
    if [ -n "$ol_response" ] && [ "$ol_response" != "{}" ]; then
        local ol_key="ISBN:$isbn"
        
        if [[ "$ol_response" == *"\"$ol_key\""* ]]; then
            # Extraction des données principales
            local o_title=$(extract_json_value "$ol_response" ".\"$ol_key\".title")
            local o_authors=$(extract_json_array "$ol_response" ".\"$ol_key\".authors[].name")
            local o_publishers=$(extract_json_value "$ol_response" ".\"$ol_key\".publishers[0].name")
            local o_number_of_pages=$(extract_json_value "$ol_response" ".\"$ol_key\".number_of_pages" "0")
            local o_physical_format=$(extract_json_value "$ol_response" ".\"$ol_key\".physical_format")
            local o_subjects=$(extract_json_array "$ol_response" ".\"$ol_key\".subjects[].name" ', ')
            local o_description=$(extract_json_value "$ol_response" ".\"$ol_key\".description")
            local o_first_sentence=$(extract_json_value "$ol_response" ".\"$ol_key\".first_sentence.value")
            local o_excerpts=$(extract_json_value "$ol_response" ".\"$ol_key\".excerpts[0].text")
            
            log "    ✓ Open Library : trouvé '$o_title'"
            
            # Stocker les données
            store_meta "$product_id" "_o_title" "$o_title"
            store_meta "$product_id" "_o_authors" "$o_authors"
            store_meta "$product_id" "_o_publishers" "$o_publishers"
            store_meta "$product_id" "_o_number_of_pages" "$o_number_of_pages"
            store_meta "$product_id" "_o_physical_format" "$o_physical_format"
            store_meta "$product_id" "_o_subjects" "$o_subjects"
            store_meta "$product_id" "_o_description" "$o_description"
            store_meta "$product_id" "_o_first_sentence" "$o_first_sentence"
            store_meta "$product_id" "_o_excerpts" "$o_excerpts"
            
            # Déterminer la meilleure description
            local best_desc=""
            if [ -n "$o_description" ] && [ ${#o_description} -gt 30 ]; then
                best_desc="$o_description"
            elif [ -n "$o_first_sentence" ] && [ ${#o_first_sentence} -gt 30 ]; then
                best_desc="$o_first_sentence"
            elif [ -n "$o_excerpts" ] && [ ${#o_excerpts} -gt 30 ]; then
                best_desc="$o_excerpts"
            fi
            
            # Retourner les données importantes
            echo "title:$o_title|authors:$o_authors|publisher:$o_publishers|description:$best_desc|pages:$o_number_of_pages|format:$o_physical_format|subjects:$o_subjects"
            return 0
        else
            log "    ✗ Open Library : pas de résultat"
            return 1
        fi
    else
        log "    ✗ Open Library : pas de résultat"
        return 1
    fi
}
