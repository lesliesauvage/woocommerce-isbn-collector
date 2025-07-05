#!/bin/bash
# lib/marketplace/all_requirements.sh - Affiche tous les requirements marketplace d'un coup

# Fonction principale qui appelle toutes les autres
show_all_marketplace_requirements() {
    local product_id=$1
    local isbn=$2
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📋 REQUIREMENTS DÉTAILLÉS PAR MARKETPLACE"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    # Appeler toutes les fonctions marketplace dans l'ordre
    show_amazon_requirements "$product_id" "$isbn"
    show_rakuten_requirements "$product_id" "$isbn"
    show_vinted_requirements "$product_id" "$isbn"
    show_fnac_requirements "$product_id" "$isbn"
    show_cdiscount_requirements "$product_id" "$isbn"
    show_leboncoin_requirements "$product_id" "$isbn"
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
}

# Fonction pour afficher un résumé compact
show_marketplace_summary() {
    local product_id=$1
    local isbn=$2
    
    echo ""
    echo "📊 RÉSUMÉ RAPIDE PAR MARKETPLACE"
    echo "┌──────────────────┬─────────────────┬──────────────────────────────────────────┐"
    echo "│ Marketplace      │ Status          │ Données manquantes                       │"
    echo "├──────────────────┼─────────────────┼──────────────────────────────────────────┤"
    
    # Pour chaque marketplace, vérifier rapidement
    for marketplace in amazon rakuten vinted fnac cdiscount leboncoin; do
        local status="❌ NON PRÊT"
        local missing=""
        
        if check_marketplace_requirements "$product_id" "$marketplace"; then
            status="✅ PRÊT"
            missing="Aucune"
        else
            missing=$(get_missing_data "$product_id" "$marketplace")
        fi
        
        printf "│ %-16s │ %-15s │ %-40s │\n" "$marketplace" "$status" "${missing:0:40}"
    done
    
    echo "└──────────────────┴─────────────────┴──────────────────────────────────────────┘"
}

# Vérifier les requirements d'un marketplace
check_marketplace_requirements() {
    local product_id=$1
    local marketplace=$2
    
    # Utiliser la fonction du module analyze_stats.sh
    check_marketplace_ready "$product_id" "$marketplace"
}

# Obtenir les données manquantes pour un marketplace
get_missing_data() {
    local product_id=$1
    local marketplace=$2
    local missing=""
    
    # Données communes
    local title=$(get_best_value "title" "$product_id")
    local price=$(get_best_value "price" "$product_id")
    local description=$(get_best_value "description" "$product_id")
    local image=$(get_best_value "image" "$product_id")
    local authors=$(get_best_value "authors" "$product_id")
    local publisher=$(get_best_value "publisher" "$product_id")
    
    [ -z "$title" ] && missing="${missing}titre, "
    [ -z "$price" ] || [ "$price" = "0" ] && missing="${missing}prix, "
    
    case "$marketplace" in
        "amazon")
            [ -z "$publisher" ] && missing="${missing}éditeur, "
            [ -z "$description" ] && missing="${missing}description, "
            [ -z "$image" ] && missing="${missing}image, "
            ;;
        "rakuten")
            [ -z "$description" ] || [ ${#description} -lt 20 ] && missing="${missing}description (20 car min), "
            [ -z "$image" ] && missing="${missing}image, "
            ;;
        "vinted")
            [ -z "$description" ] && missing="${missing}description, "
            [ -z "$image" ] && missing="${missing}photo, "
            local condition=$(safe_get_meta "$product_id" "_book_condition")
            [ -z "$condition" ] && missing="${missing}état, "
            ;;
        "fnac")
            [ -z "$authors" ] && missing="${missing}auteur, "
            [ -z "$publisher" ] && missing="${missing}éditeur, "
            ;;
        "cdiscount")
            [ -z "$publisher" ] && missing="${missing}brand, "
            [ -z "$description" ] && missing="${missing}description, "
            [ -z "$image" ] && missing="${missing}image, "
            ;;
        "leboncoin")
            [ -z "$description" ] && missing="${missing}description, "
            [ -z "$image" ] && missing="${missing}photo, "
            local zip=$(safe_get_meta "$product_id" "_location_zip")
            [ -z "$zip" ] && missing="${missing}code postal, "
            ;;
    esac
    
    # Enlever la dernière virgule
    echo "${missing%, }"
}

# Fonction pour exporter vers toutes les marketplaces prêtes
export_to_ready_marketplaces() {
    local product_id=$1
    local isbn=$2
    
    echo ""
    echo "🚀 EXPORT VERS LES MARKETPLACES PRÊTES"
    echo "────────────────────────────────────────"
    
    local exported=0
    
    for marketplace in amazon rakuten vinted fnac cdiscount leboncoin; do
        if check_marketplace_requirements "$product_id" "$marketplace"; then
            echo "✅ Export $marketplace..."
            # Ici on appellerait le script d'export spécifique
            # "$SCRIPT_DIR/exports/export_${marketplace}.sh" "$product_id"
            ((exported++))
        fi
    done
    
    if [ $exported -eq 0 ]; then
        echo "❌ Aucune marketplace n'est prête pour l'export"
    else
        echo ""
        echo "✅ Export terminé vers $exported marketplace(s)"
    fi
}
