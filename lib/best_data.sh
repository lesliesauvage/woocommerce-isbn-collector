#!/bin/bash
# Sélection des meilleures données

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/database.sh"

# Stocker les meilleures données avec leur source
store_best_data() {
    local product_id=$1
    local field=$2
    local value=$3
    local source=$4
    
    if [ -n "$value" ]; then
        store_meta "$product_id" "_best_$field" "$value"
        store_meta "$product_id" "_best_${field}_source" "$source"
    fi
}

# Sélectionner la meilleure description
select_best_description() {
    local product_id=$1
    local descriptions=("$@")
    
    local best_desc=""
    local best_source=""
    
    # Parcourir les descriptions dans l'ordre de préférence
    for desc_entry in "${descriptions[@]:1}"; do
        IFS='|' read -r desc source <<< "$desc_entry"
        if [ -n "$desc" ] && [ "$desc" != "Text: French" ] && [ ${#desc} -gt 30 ]; then
            best_desc="$desc"
            best_source="$source"
            break
        fi
    done
    
    if [ -n "$best_desc" ]; then
        store_best_data "$product_id" "description" "$best_desc" "$best_source"
        store_meta "$product_id" "_has_description" "1"
        echo "$best_desc"
        return 0
    else
        store_meta "$product_id" "_has_description" "0"
        return 1
    fi
}

# Fusionner toutes les catégories
merge_all_categories() {
    local g_categories=$1
    local i_subjects=$2
    local o_subjects=$3
    
    local all_categories=""
    [ -n "$g_categories" ] && all_categories="${all_categories}${g_categories}, "
    [ -n "$i_subjects" ] && [ "$i_subjects" != "Subjects," ] && all_categories="${all_categories}${i_subjects}, "
    [ -n "$o_subjects" ] && all_categories="${all_categories}${o_subjects}, "
    
    echo "$all_categories" | sed 's/, $//' | sed 's/,\+/, /g'
}

# Déterminer la meilleure image
select_best_image() {
    local g_extraLarge=$1
    local g_large=$2
    local g_medium=$3
    local g_thumbnail=$4
    local i_image=$5
    local o_cover_large=$6
    local o_cover_medium=$7
    local o_cover_small=$8
    
    local best_image="${g_extraLarge:-${g_large:-${g_medium:-${g_thumbnail:-${i_image:-${o_cover_large:-${o_cover_medium:-$o_cover_small}}}}}}}"
    
    if [ -n "$best_image" ]; then
        local source="unknown"
        if [[ "$best_image" == *"books.google"* ]]; then
            source="google"
        elif [[ "$best_image" == *"isbndb"* ]]; then
            source="isbndb"
        elif [[ "$best_image" == *"openlibrary"* ]] || [[ "$best_image" == *"covers.openlibrary"* ]]; then
            source="openlibrary"
        fi
        
        echo "$best_image|$source"
    fi
}
