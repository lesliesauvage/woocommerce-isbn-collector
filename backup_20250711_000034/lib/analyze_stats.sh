#!/bin/bash
# lib/analyze_stats.sh - Fonctions de statistiques et tableaux comparatifs

# Afficher le tableau comparatif des gains
show_gains_table() {
    local before_google=$1
    local after_google=$2
    local before_isbndb=$3
    local after_isbndb=$4
    local before_ol=$5
    local after_ol=$6
    local before_best=$7
    local after_best=$8
    local before_calc=$9
    local after_calc=${10}
    local before_total=${11}
    local after_total=${12}
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📈 RÉSUMÉ DES GAINS DE LA COLLECTE"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "┌──────────────────────────────────────────────┬─────────────┬─────────────┬─────────────┬─────────────────┐"
    echo "│ Source                                       │    AVANT    │    APRÈS    │    GAIN     │ Progression     │"
    echo "├──────────────────────────────────────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤"
    
    # Google Books
    local gain_g=$((after_google - before_google))
    local prog_g="="
    [ $gain_g -gt 0 ] && prog_g="📈 +$gain_g"
    printf "│ %-44s │ %11d │ %11d │ %11d │ %-15s │\n" "Google Books" "$before_google" "$after_google" "$gain_g" "$prog_g"
    
    # ISBNdb
    local gain_i=$((after_isbndb - before_isbndb))
    local prog_i="="
    [ $gain_i -gt 0 ] && prog_i="📈 +$gain_i"
    printf "│ %-44s │ %11d │ %11d │ %11d │ %-15s │\n" "ISBNdb" "$before_isbndb" "$after_isbndb" "$gain_i" "$prog_i"
    
    # Open Library
    local gain_o=$((after_ol - before_ol))
    local prog_o="="
    [ $gain_o -gt 0 ] && prog_o="📈 +$gain_o"
    printf "│ %-44s │ %11d │ %11d │ %11d │ %-15s │\n" "Open Library" "$before_ol" "$after_ol" "$gain_o" "$prog_o"
    
    # Best/Calc
    local gain_bc=$((after_best + after_calc - before_best - before_calc))
    local prog_bc="="
    [ $gain_bc -gt 0 ] && prog_bc="📈 +$gain_bc"
    printf "│ %-44s │ %11d │ %11d │ %11d │ %-15s │\n" "Meilleures données & Calculs" "$((before_best + before_calc))" "$((after_best + after_calc))" "$gain_bc" "$prog_bc"
    
    echo "├──────────────────────────────────────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤"
    
    # Total
    local gain_total=$((after_total - before_total))
    local prog_total="="
    [ $gain_total -gt 0 ] && prog_total="✅ +$gain_total données"
    [ $gain_total -eq 0 ] && prog_total="➖ Aucun gain"
    printf "│ %-44s │ %11d │ %11d │ %11d │ %-15s │\n" "TOTAL" "$before_total" "$after_total" "$gain_total" "$prog_total"
    
    echo "└──────────────────────────────────────────────┴─────────────┴─────────────┴─────────────┴─────────────────┘"
    
    return $gain_total
}

# Afficher les statistiques finales
show_final_stats() {
    local product_id=$1
    local gain_total=$2
    
    echo ""
    if [ $gain_total -gt 0 ]; then
        local api_calls=$(safe_get_meta "$product_id" "_api_calls_made")
        echo "✅ Collecte réussie : $gain_total nouvelles données ajoutées"
        [ -n "$api_calls" ] && echo "📡 Appels API effectués : $api_calls"
    else
        echo "ℹ️  Aucune nouvelle donnée collectée"
        echo "   Causes possibles :"
        echo "   • Le livre a déjà toutes les données disponibles"
        echo "   • Les APIs n'ont pas d'informations supplémentaires"
        echo "   • Problème de connexion aux APIs"
    fi
}

# Afficher le prompt pour nouvelle session
show_new_session_prompt() {
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "🔄 OUVRIR UNE NOUVELLE SESSION"
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "Pour analyser un autre livre dans une nouvelle fenêtre, copiez cette commande :"
    echo ""
    echo "cd /var/www/scripts-home-root/isbn/ && ./analyze_with_collect.sh"
    echo ""
    echo "Ou avec un ISBN spécifique :"
    echo "cd /var/www/scripts-home-root/isbn/ && ./analyze_with_collect.sh 9782070368228 5.99 'très bon'"
    echo ""
}

# Calculer les statistiques par source
calculate_source_stats() {
    local product_id=$1
    local source=$2
    
    local count=$(safe_mysql "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $product_id 
        AND meta_key LIKE '${source}_%'
        AND meta_value IS NOT NULL 
        AND meta_value != ''
        AND meta_value != 'null'
        AND meta_value != '0'")
    
    echo "${count:-0}"
}

# Afficher un résumé d'exportabilité
show_exportability_summary() {
    local product_id=$1
    
    echo ""
    echo "📤 RÉSUMÉ D'EXPORTABILITÉ"
    echo "─────────────────────────"
    
    local ready_count=0
    local total_marketplaces=6
    
    # Vérifier chaque marketplace
    for marketplace in amazon rakuten vinted fnac cdiscount leboncoin; do
        if check_marketplace_ready "$product_id" "$marketplace"; then
            echo "✅ $marketplace : Prêt"
            ((ready_count++))
        else
            echo "❌ $marketplace : Données manquantes"
        fi
    done
    
    echo ""
    echo "Score : $ready_count/$total_marketplaces marketplaces prêtes"
}

# Vérifier si un marketplace est prêt
check_marketplace_ready() {
    local product_id=$1
    local marketplace=$2
    
    # Données communes requises
    local title=$(get_best_value "title" "$product_id")
    local price=$(get_best_value "price" "$product_id")
    local has_image=$(get_best_value "image" "$product_id")
    
    [ -z "$title" ] && return 1
    [ -z "$price" ] || [ "$price" = "0" ] && return 1
    
    case "$marketplace" in
        "amazon")
            local publisher=$(get_best_value "publisher" "$product_id")
            local description=$(get_best_value "description" "$product_id")
            [ -z "$publisher" ] || [ -z "$description" ] || [ -z "$has_image" ] && return 1
            ;;
        "rakuten")
            local description=$(get_best_value "description" "$product_id")
            [ -z "$description" ] || [ ${#description} -lt 20 ] || [ -z "$has_image" ] && return 1
            ;;
        "vinted")
            local description=$(get_best_value "description" "$product_id")
            local condition=$(safe_get_meta "$product_id" "_book_condition")
            [ -z "$description" ] || [ -z "$has_image" ] || [ -z "$condition" ] && return 1
            ;;
        "fnac")
            local authors=$(get_best_value "authors" "$product_id")
            local publisher=$(get_best_value "publisher" "$product_id")
            [ -z "$authors" ] || [ -z "$publisher" ] && return 1
            ;;
        "cdiscount")
            local publisher=$(get_best_value "publisher" "$product_id")
            local description=$(get_best_value "description" "$product_id")
            [ -z "$publisher" ] || [ -z "$description" ] || [ -z "$has_image" ] && return 1
            ;;
        "leboncoin")
            local description=$(get_best_value "description" "$product_id")
            local zip=$(safe_get_meta "$product_id" "_location_zip")
            [ -z "$description" ] || [ -z "$has_image" ] || [ -z "$zip" ] && return 1
            ;;
    esac
    
    return 0
}
