#!/bin/bash
# Fonctions d'enrichissement et calculs

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/database.sh"

# Calculer le poids selon le nombre de pages
calculate_weight() {
    local pages=$1
    if [ "$pages" -gt 0 ]; then
        echo $((pages * 25 / 10))  # 2.5g par page
    else
        echo "0"
    fi
}

# Calculer les dimensions selon le format
calculate_dimensions() {
    local binding=$1
    
    case "$binding" in
        "Paperback"|"Broché")
            echo "21 x 14 x 2"
            ;;
        "Hardcover"|"Relié")
            echo "24 x 16 x 3"
            ;;
        "Pocket Book"|"Poche")
            echo "18 x 11 x 2"
            ;;
        *)
            echo "21 x 14 x 2"
            ;;
    esac
}

# Générer l'EAN à partir de l'ISBN-10
generate_ean_from_isbn10() {
    local isbn10=$1
    if [ -z "$isbn10" ] || [ ${#isbn10} -ne 10 ]; then
        return 1
    fi
    
    # Calculer le check digit pour l'EAN
    local ean_base="978${isbn10:0:9}"
    local sum=0
    for (( i=0; i<12; i++ )); do
        local digit=${ean_base:$i:1}
        if [ $((i % 2)) -eq 0 ]; then
            sum=$((sum + digit))
        else
            sum=$((sum + digit * 3))
        fi
    done
    local check_digit=$((10 - (sum % 10)))
    [ $check_digit -eq 10 ] && check_digit=0
    
    echo "${ean_base}${check_digit}"
}

# Générer les bullet points pour Amazon
generate_bullet_points() {
    local product_id=$1
    local authors=$2
    local pages=$3
    local publisher=$4
    local binding=$5
    local isbn=$6
    
    local bullet1=""
    local bullet2=""
    local bullet3=""
    local bullet4=""
    local bullet5=""
    
    if [ -n "$authors" ]; then
        bullet1="Écrit par $authors - Expert reconnu dans son domaine"
    fi
    
    if [ "$pages" -gt 0 ]; then
        bullet2="$pages pages de contenu riche et détaillé"
    fi
    
    if [ -n "$publisher" ]; then
        bullet3="Publié par $publisher - Éditeur de référence"
    fi
    
    if [ -n "$binding" ]; then
        bullet4="Format $binding - Qualité de fabrication supérieure"
    fi
    
    if [ -n "$isbn" ]; then
        bullet5="ISBN: $isbn - Authenticité garantie"
    fi
    
    safe_store_meta "$product_id" "_calculated_bullet1" "$bullet1"
    safe_store_meta "$product_id" "_calculated_bullet2" "$bullet2"
    safe_store_meta "$product_id" "_calculated_bullet3" "$bullet3"
    safe_store_meta "$product_id" "_calculated_bullet4" "$bullet4"
    safe_store_meta "$product_id" "_calculated_bullet5" "$bullet5"
}

# Générer les mots-clés de recherche
generate_search_terms() {
    local title=$1
    local authors=$2
    local publisher=$3
    local categories=$4
    
    local search_terms=""
    [ -n "$title" ] && search_terms="${search_terms} ${title}"
    [ -n "$authors" ] && search_terms="${search_terms} ${authors}"
    [ -n "$publisher" ] && search_terms="${search_terms} ${publisher}"
    [ -n "$categories" ] && search_terms="${search_terms} ${categories}"
    
    echo "$search_terms" | tr ',' ' ' | tr -s ' ' | cut -c1-250
}

# Calculer le prix de vente conseillé
calculate_msrp() {
    local pages=$1
    local binding=$2
    local msrp_isbndb=$3
    local list_price_google=$4
    
    if [ -n "$msrp_isbndb" ] && [ "$msrp_isbndb" != "0" ] && [ "$msrp_isbndb" != "0.00" ]; then
        echo "$msrp_isbndb"
    elif [ -n "$list_price_google" ] && [ "$list_price_google" != "0" ]; then
        echo "$list_price_google"
    else
        # Estimer selon le nombre de pages et le format
        if [ "$pages" -gt 0 ]; then
            case "$binding" in
                "Hardcover"|"Relié")
                    echo "scale=2; 25 + ($pages * 0.05)" | bc
                    ;;
                "Pocket Book"|"Poche")
                    echo "scale=2; 5 + ($pages * 0.02)" | bc
                    ;;
                *)
                    echo "scale=2; 10 + ($pages * 0.03)" | bc
                    ;;
            esac
        fi
    fi
}
