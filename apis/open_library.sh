#!/bin/bash
# API Open Library

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"  # Fonctions sécurisées
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
            
            # Extraction des images de couverture
            local o_cover_small=$(extract_json_value "$ol_response" ".\"$ol_key\".cover.small")
            local o_cover_medium=$(extract_json_value "$ol_response" ".\"$ol_key\".cover.medium")
            local o_cover_large=$(extract_json_value "$ol_response" ".\"$ol_key\".cover.large")
            
            log "    ✓ Open Library : trouvé '$o_title'"
            
            # Stocker les données principales
            safe_store_meta "$product_id" "_o_title" "$o_title"
            safe_store_meta "$product_id" "_o_authors" "$o_authors"
            safe_store_meta "$product_id" "_o_publishers" "$o_publishers"
            safe_store_meta "$product_id" "_o_number_of_pages" "$o_number_of_pages"
            safe_store_meta "$product_id" "_o_physical_format" "$o_physical_format"
            safe_store_meta "$product_id" "_o_subjects" "$o_subjects"
            safe_store_meta "$product_id" "_o_description" "$o_description"
            safe_store_meta "$product_id" "_o_first_sentence" "$o_first_sentence"
            safe_store_meta "$product_id" "_o_excerpts" "$o_excerpts"
            
            # Stocker les images si disponibles
            [ -n "$o_cover_small" ] && [ "$o_cover_small" != "null" ] && safe_store_meta "$product_id" "_o_cover_small" "$o_cover_small"
            [ -n "$o_cover_medium" ] && [ "$o_cover_medium" != "null" ] && safe_store_meta "$product_id" "_o_cover_medium" "$o_cover_medium"
            [ -n "$o_cover_large" ] && [ "$o_cover_large" != "null" ] && safe_store_meta "$product_id" "_o_cover_large" "$o_cover_large"
            
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
