#!/bin/bash
echo "[START: best_data.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# lib/best_data.sh - Gestion des meilleures données

# Récupérer la meilleure valeur pour un type de donnée
get_best_value() {
    local data_type=$1
    local product_id=$2
    local value=""
    
    case "$data_type" in
        "title")
            # D'ABORD chercher _best_title
            value=$(safe_get_meta "$product_id" "_best_title")
            if [ -n "$value" ] && [ "$value" != "null" ]; then
                echo "$value"
                return
            fi
            # ENSUITE chercher dans les sources directes
            for key in _g_title _i_title _o_title; do
                value=$(safe_get_meta "$product_id" "$key")
                if [ -n "$value" ] && [ "$value" != "null" ]; then
                    echo "$value"
                    return
                fi
            done
            ;;
            
        "authors")
            # D'ABORD chercher _best_authors
            value=$(safe_get_meta "$product_id" "_best_authors")
            if [ -n "$value" ] && [ "$value" != "null" ]; then
                echo "$value"
                return
            fi
            # ENSUITE chercher dans les sources
            for key in _g_authors _i_authors _o_authors; do
                value=$(safe_get_meta "$product_id" "$key")
                if [ -n "$value" ] && [ "$value" != "null" ]; then
                    echo "$value"
                    return
                fi
            done
            ;;
            
        "publisher")
            # D'ABORD chercher _best_publisher
            value=$(safe_get_meta "$product_id" "_best_publisher")
            if [ -n "$value" ] && [ "$value" != "null" ]; then
                echo "$value"
                return
            fi
            # ENSUITE chercher dans les sources
            for key in _g_publisher _i_publisher _o_publishers; do
                value=$(safe_get_meta "$product_id" "$key")
                if [ -n "$value" ] && [ "$value" != "null" ]; then
                    echo "$value"
                    return
                fi
            done
            ;;
            
        "description")
            # Ordre de priorité pour la description
            for key in _best_description _claude_description _groq_description _g_description _i_synopsis _i_overview _o_description; do
                value=$(safe_get_meta "$product_id" "$key")
                if [ -n "$value" ] && [ "$value" != "null" ] && [ ${#value} -gt 20 ]; then
                    echo "$value"
                    return
                fi
            done
            ;;
            
        "pages")
            # D'ABORD chercher _best_pages
            value=$(safe_get_meta "$product_id" "_best_pages")
            if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0" ]; then
                echo "$value"
                return
            fi
            # ENSUITE chercher dans les sources
            for key in _g_pageCount _i_pages _o_number_of_pages; do
                value=$(safe_get_meta "$product_id" "$key")
                if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0" ]; then
                    echo "$value"
                    return
                fi
            done
            ;;
            
        "language")
            for key in _g_language _i_language; do
                value=$(safe_get_meta "$product_id" "$key")
                if [ -n "$value" ] && [ "$value" != "null" ]; then
                    echo "$value"
                    return
                fi
            done
            echo "fr"  # Défaut français
            ;;
            
        "date")
            for key in _g_publishedDate _i_date_published; do
                value=$(safe_get_meta "$product_id" "$key")
                if [ -n "$value" ] && [ "$value" != "null" ]; then
                    echo "$value"
                    return
                fi
            done
            ;;
            
        "binding")
            for key in _i_binding _o_physical_format; do
                value=$(safe_get_meta "$product_id" "$key")
                if [ -n "$value" ] && [ "$value" != "null" ]; then
                    echo "$value"
                    return
                fi
            done
            ;;
            
        "weight")
            value=$(safe_get_meta "$product_id" "_calculated_weight")
            if [ -n "$value" ] && [ "$value" != "null" ]; then
                echo "$value"
                return
            fi
            ;;
            
        "dimensions")
            value=$(safe_get_meta "$product_id" "_calculated_dimensions")
            if [ -n "$value" ] && [ "$value" != "null" ]; then
                echo "$value"
                return
            fi
            ;;
            
        "price")
            value=$(safe_get_meta "$product_id" "_price")
            if [ -n "$value" ] && [ "$value" != "null" ]; then
                echo "$value"
                return
            fi
            ;;
            
        "image")
            # Ordre de préférence pour les images
            for key in _best_cover_image _g_extraLarge _g_large _g_medium _g_small _g_thumbnail _g_smallThumbnail _i_image _o_cover_large _o_cover_medium _o_cover_small; do
                value=$(safe_get_meta "$product_id" "$key")
                if [ -n "$value" ] && [ "$value" != "null" ] && [[ "$value" =~ ^https?:// ]]; then
                    echo "$value"
                    return
                fi
            done
            ;;
    esac
    
    # Rien trouvé
    echo ""
}

# Stocker la meilleure valeur pour un type de donnée
store_best_data() {
    local product_id=$1
    local data_type=$2
    local value=$3
    local source=$4
    
    if [ -z "$value" ] || [ "$value" = "null" ]; then
        return
    fi
    
    case "$data_type" in
        "title")
            safe_store_meta "$product_id" "_best_title" "$value"
            safe_store_meta "$product_id" "_best_title_source" "$source"
            ;;
        "authors")
            safe_store_meta "$product_id" "_best_authors" "$value"
            safe_store_meta "$product_id" "_best_authors_source" "$source"
            ;;
        "publisher")
            safe_store_meta "$product_id" "_best_publisher" "$value"
            safe_store_meta "$product_id" "_best_publisher_source" "$source"
            ;;
        "description")
            safe_store_meta "$product_id" "_best_description" "$value"
            safe_store_meta "$product_id" "_best_description_source" "$source"
            ;;
        "pages")
            safe_store_meta "$product_id" "_best_pages" "$value"
            safe_store_meta "$product_id" "_best_pages_source" "$source"
            ;;
        "binding")
            safe_store_meta "$product_id" "_best_binding" "$value"
            safe_store_meta "$product_id" "_best_binding_source" "$source"
            ;;
        "cover")
            safe_store_meta "$product_id" "_best_cover_image" "$value"
            safe_store_meta "$product_id" "_best_cover_source" "$source"
            ;;
    esac
}

# Sélectionner la meilleure description parmi plusieurs
select_best_description() {
    local product_id=$1
    shift  # Enlever product_id des arguments
    local descriptions=("$@")
    
    local best_desc=""
    local best_length=0
    local best_source=""
    
    for desc_data in "${descriptions[@]}"; do
        local desc=$(echo "$desc_data" | cut -d'|' -f1)
        local source=$(echo "$desc_data" | cut -d'|' -f2)
        
        if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt $best_length ]; then
            best_desc="$desc"
            best_length=${#desc}
            best_source="$source"
        fi
    done
    
    if [ -n "$best_desc" ]; then
        store_best_data "$product_id" "description" "$best_desc" "$best_source"
        echo "$best_desc"
        return 0
    fi
    
    return 1
}

# Export des fonctions
export -f get_best_value
export -f store_best_data
export -f select_best_description
echo "[END: best_data.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
