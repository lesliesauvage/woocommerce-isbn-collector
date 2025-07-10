#!/bin/bash
echo "[START: export_checks.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# lib/export_checks.sh - Vérifications d'exportabilité vers marketplaces

# Calculer le score d'exportabilité d'un livre
calculate_export_score() {
    local product_id=$1
    
    echo "[DEBUG] Calcul du score pour produit #$product_id" >&2
    
    local score=0
    local max_score=0
    local missing_items=""
    
    # CRITÈRES OBLIGATOIRES (5 points chacun)
    local obligatory_weight=5
    
    # 1. Titre
    local title=$(get_best_value "title" "$product_id")
    ((max_score += obligatory_weight))
    if [ -n "$title" ] && [ "$title" != "null" ]; then
        ((score += obligatory_weight))
        echo "[DEBUG] ✓ Titre présent (+$obligatory_weight pts)" >&2
    else
        missing_items="${missing_items}Titre, "
        echo "[DEBUG] ✗ Titre manquant" >&2
    fi
    
    # 2. Prix > 0
    local price=$(safe_get_meta "$product_id" "_price")
    ((max_score += obligatory_weight))
    if [ -n "$price" ] && [ "$price" != "0" ] && [ "$price" != "0.00" ]; then
        ((score += obligatory_weight))
        echo "[DEBUG] ✓ Prix défini: $price € (+$obligatory_weight pts)" >&2
    else
        missing_items="${missing_items}Prix, "
        echo "[DEBUG] ✗ Prix manquant ou zéro" >&2
    fi
    
    # 3. ISBN valide
    local isbn=$(safe_get_meta "$product_id" "_isbn")
    ((max_score += obligatory_weight))
    if [[ "$isbn" =~ ^[0-9]{10}$ ]] || [[ "$isbn" =~ ^[0-9]{13}$ ]]; then
        ((score += obligatory_weight))
        echo "[DEBUG] ✓ ISBN valide: $isbn (+$obligatory_weight pts)" >&2
    else
        missing_items="${missing_items}ISBN valide, "
        echo "[DEBUG] ✗ ISBN invalide: $isbn" >&2
    fi
    
    # 4. Image principale
    local image=$(get_best_value "image" "$product_id")
    ((max_score += obligatory_weight))
    if [ -n "$image" ] && [ "$image" != "null" ]; then
        ((score += obligatory_weight))
        echo "[DEBUG] ✓ Image présente (+$obligatory_weight pts)" >&2
    else
        missing_items="${missing_items}Image, "
        echo "[DEBUG] ✗ Image manquante" >&2
    fi
    
    # 5. Description > 20 caractères
    local description=$(get_best_value "description" "$product_id")
    ((max_score += obligatory_weight))
    if [ -n "$description" ] && [ ${#description} -gt 20 ]; then
        ((score += obligatory_weight))
        echo "[DEBUG] ✓ Description présente: ${#description} car (+$obligatory_weight pts)" >&2
    else
        missing_items="${missing_items}Description, "
        echo "[DEBUG] ✗ Description manquante ou trop courte" >&2
    fi
    
    # CRITÈRES IMPORTANTS (3 points chacun)
    local important_weight=3
    
    # 6. Auteur
    local authors=$(get_best_value "authors" "$product_id")
    ((max_score += important_weight))
    if [ -n "$authors" ] && [ "$authors" != "null" ]; then
        ((score += important_weight))
        echo "[DEBUG] ✓ Auteur(s): $authors (+$important_weight pts)" >&2
    else
        missing_items="${missing_items}Auteur, "
        echo "[DEBUG] ✗ Auteur manquant" >&2
    fi
    
    # 7. Éditeur
    local publisher=$(get_best_value "publisher" "$product_id")
    ((max_score += important_weight))
    if [ -n "$publisher" ] && [ "$publisher" != "null" ]; then
        ((score += important_weight))
        echo "[DEBUG] ✓ Éditeur: $publisher (+$important_weight pts)" >&2
    else
        missing_items="${missing_items}Éditeur, "
        echo "[DEBUG] ✗ Éditeur manquant" >&2
    fi
    
    # 8. État du livre
    local condition=$(safe_get_meta "$product_id" "_book_condition")
    ((max_score += important_weight))
    if [ -n "$condition" ]; then
        ((score += important_weight))
        echo "[DEBUG] ✓ État: $condition (+$important_weight pts)" >&2
    else
        missing_items="${missing_items}État, "
        echo "[DEBUG] ✗ État non défini" >&2
    fi
    
    # 9. Stock défini
    local stock_qty=$(safe_get_meta "$product_id" "_stock_quantity")
    ((max_score += important_weight))
    if [ -n "$stock_qty" ] && [ "$stock_qty" != "" ]; then
        ((score += important_weight))
        echo "[DEBUG] ✓ Stock: $stock_qty (+$important_weight pts)" >&2
    else
        missing_items="${missing_items}Stock, "
        echo "[DEBUG] ✗ Stock non défini" >&2
    fi
    
    # CRITÈRES BONUS (1 point chacun)
    local bonus_weight=1
    
    # 10. Pages
    local pages=$(get_best_value "pages" "$product_id")
    ((max_score += bonus_weight))
    if [ -n "$pages" ] && [ "$pages" != "0" ] && [ "$pages" != "null" ]; then
        ((score += bonus_weight))
        echo "[DEBUG] ✓ Pages: $pages (+$bonus_weight pt)" >&2
    else
        missing_items="${missing_items}Pages, "
    fi
    
    # 11. Poids
    local weight=$(get_best_value "weight" "$product_id")
    ((max_score += bonus_weight))
    if [ -n "$weight" ] && [ "$weight" != "null" ]; then
        ((score += bonus_weight))
        echo "[DEBUG] ✓ Poids: ${weight}g (+$bonus_weight pt)" >&2
    else
        missing_items="${missing_items}Poids, "
    fi
    
    # 12. Dimensions
    local dimensions=$(get_best_value "dimensions" "$product_id")
    ((max_score += bonus_weight))
    if [ -n "$dimensions" ] && [ "$dimensions" != "null" ]; then
        ((score += bonus_weight))
        echo "[DEBUG] ✓ Dimensions: $dimensions (+$bonus_weight pt)" >&2
    else
        missing_items="${missing_items}Dimensions, "
    fi
    
    # 13. Catégorie
    local categories=$(safe_get_meta "$product_id" "_g_categories")
    ((max_score += bonus_weight))
    if [ -n "$categories" ] && [ "$categories" != "null" ]; then
        ((score += bonus_weight))
        echo "[DEBUG] ✓ Catégories: $categories (+$bonus_weight pt)" >&2
    else
        missing_items="${missing_items}Catégories, "
    fi
    
    # 14. Images multiples
    local img_count=0
    for img_key in _g_thumbnail _g_small _g_medium _g_large _g_extraLarge _i_image _o_cover_small _o_cover_medium _o_cover_large; do
        local img_url=$(safe_get_meta "$product_id" "$img_key")
        [ -n "$img_url" ] && [ "$img_url" != "null" ] && ((img_count++))
    done
    ((max_score += bonus_weight))
    if [ $img_count -gt 1 ]; then
        ((score += bonus_weight))
        echo "[DEBUG] ✓ Images multiples: $img_count (+$bonus_weight pt)" >&2
    else
        missing_items="${missing_items}Images supplémentaires, "
    fi
    
    # 15. Description longue
    ((max_score += bonus_weight))
    if [ -n "$description" ] && [ ${#description} -gt 500 ]; then
        ((score += bonus_weight))
        echo "[DEBUG] ✓ Description longue: ${#description} car (+$bonus_weight pt)" >&2
    else
        missing_items="${missing_items}Description détaillée, "
    fi
    
    # Enlever la dernière virgule
    missing_items="${missing_items%, }"
    
    # Stocker les résultats
    safe_store_meta "$product_id" "_export_score" "$score"
    safe_store_meta "$product_id" "_export_max_score" "$max_score"
    safe_store_meta "$product_id" "_missing_data" "$missing_items"
    safe_store_meta "$product_id" "_export_check_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "[DEBUG] Score final: $score/$max_score" >&2
    
    # Retourner score et max
    echo "$score|$max_score|$missing_items"
}

# Vérifier si un livre est prêt pour un marketplace spécifique
check_marketplace_ready() {
    local product_id=$1
    local marketplace=$2
    
    case "$marketplace" in
        "amazon")
            # Amazon : titre, prix, ISBN, image, description, éditeur
            check_required_fields "$product_id" "title|price|isbn|image|description|publisher"
            ;;
        "rakuten")
            # Rakuten : titre, prix, ISBN, image, description(20+)
            if ! check_required_fields "$product_id" "title|price|isbn|image"; then
                return 1
            fi
            # Vérifier description min 20 caractères
            local desc=$(get_best_value "description" "$product_id")
            [ ${#desc} -ge 20 ] && return 0 || return 1
            ;;
        "vinted")
            # Vinted : titre, prix, image, description, état
            check_required_fields "$product_id" "title|price|image|description|condition"
            ;;
        "fnac")
            # Fnac : titre, prix, ISBN, auteur, éditeur
            check_required_fields "$product_id" "title|price|isbn|authors|publisher"
            ;;
        "cdiscount")
            # Cdiscount : titre, prix, ISBN, image, description, éditeur
            check_required_fields "$product_id" "title|price|isbn|image|description|publisher"
            ;;
        "leboncoin")
            # Leboncoin : titre, prix, image, description
            check_required_fields "$product_id" "title|price|image|description"
            ;;
        *)
            return 1
            ;;
    esac
}

# Vérifier les champs requis
check_required_fields() {
    local product_id=$1
    local required_fields=$2
    
    IFS='|' read -ra fields <<< "$required_fields"
    for field in "${fields[@]}"; do
        case "$field" in
            "title")
                local value=$(get_best_value "title" "$product_id")
                [ -z "$value" ] || [ "$value" = "null" ] && return 1
                ;;
            "price")
                local value=$(safe_get_meta "$product_id" "_price")
                [ -z "$value" ] || [ "$value" = "0" ] || [ "$value" = "0.00" ] && return 1
                ;;
            "isbn")
                local value=$(safe_get_meta "$product_id" "_isbn")
                [[ ! "$value" =~ ^[0-9]{10}$ ]] && [[ ! "$value" =~ ^[0-9]{13}$ ]] && return 1
                ;;
            "image")
                local value=$(get_best_value "image" "$product_id")
                [ -z "$value" ] || [ "$value" = "null" ] && return 1
                ;;
            "description")
                local value=$(get_best_value "description" "$product_id")
                [ -z "$value" ] || [ "$value" = "null" ] && return 1
                ;;
            "authors")
                local value=$(get_best_value "authors" "$product_id")
                [ -z "$value" ] || [ "$value" = "null" ] && return 1
                ;;
            "publisher")
                local value=$(get_best_value "publisher" "$product_id")
                [ -z "$value" ] || [ "$value" = "null" ] && return 1
                ;;
            "condition")
                local value=$(safe_get_meta "$product_id" "_book_condition")
                [ -z "$value" ] && return 1
                ;;
        esac
    done
    
    return 0
}

# Obtenir la liste des marketplaces prêtes pour un livre
get_ready_marketplaces() {
    local product_id=$1
    local ready_list=""
    
    for marketplace in amazon rakuten vinted fnac cdiscount leboncoin; do
        if check_marketplace_ready "$product_id" "$marketplace"; then
            ready_list="${ready_list}${marketplace}, "
        fi
    done
    
    # Enlever la dernière virgule
    echo "${ready_list%, }"
}

# Afficher le résumé d'exportabilité
show_export_summary() {
    local product_id=$1
    local isbn=$2
    
    # Calculer le score
    local score_data=$(calculate_export_score "$product_id")
    local score=$(echo "$score_data" | cut -d'|' -f1)
    local max_score=$(echo "$score_data" | cut -d'|' -f2)
    local missing=$(echo "$score_data" | cut -d'|' -f3)
    
    echo ""
    echo "📊 EXPORTABILITÉ : $score/$max_score points"
    
    if [ "$score" -eq "$max_score" ]; then
        echo "✅ Toutes les données sont complètes !"
    else
        echo ""
        echo "❌ Données manquantes pour export complet :"
        # Afficher chaque élément manquant sur une ligne
        IFS=', ' read -ra missing_array <<< "$missing"
        for item in "${missing_array[@]}"; do
            echo "   - $item"
        done
    fi
    
    # Marketplaces prêtes
    local ready_markets=$(get_ready_marketplaces "$product_id")
    if [ -n "$ready_markets" ]; then
        echo ""
        echo "✅ Prêt pour export vers : $ready_markets"
    else
        echo ""
        echo "❌ Aucune marketplace n'est prête pour l'export"
    fi
    
    # Suggestion de relance
    if [ "$score" -lt "$max_score" ]; then
        echo ""
        echo "💡 Relancer avec : ./isbn_unified.sh -force $isbn"
    fi
}

# Export des fonctions
export -f calculate_export_score
export -f check_marketplace_ready
export -f check_required_fields
export -f get_ready_marketplaces
export -f show_export_summary

echo "[END: export_checks.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
