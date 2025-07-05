#!/bin/bash
# lib/analyze_functions.sh - Fonctions d'analyse des données collectées - VERSION CORRIGÉE

# Fonction pour récupérer la meilleure valeur disponible
get_best_value() {
    local field=$1
    local product_id=$2
    local value=""
    
    case $field in
        "title")
            value=$(safe_get_meta "$product_id" "_best_title")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_g_title")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_i_title")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_title")
            ;;
        "authors")
            value=$(safe_get_meta "$product_id" "_best_authors")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_g_authors")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_i_authors")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_authors")
            ;;
        "publisher")
            value=$(safe_get_meta "$product_id" "_best_publisher")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_g_publisher")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_i_publisher")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_publishers")
            ;;
        "description")
            value=$(safe_get_meta "$product_id" "_best_description")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_groq_description")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_g_description")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_i_synopsis")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_description")
            ;;
        "pages")
            value=$(safe_get_meta "$product_id" "_best_pages")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_g_pageCount")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_i_pages")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_number_of_pages")
            ;;
        "image")
            value=$(safe_get_meta "$product_id" "_i_image")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_g_thumbnail")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_g_medium")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_cover_medium")
            ;;
        "date")
            value=$(safe_get_meta "$product_id" "_g_publishedDate")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_i_publishedDate")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_publish_date")
            ;;
        "language")
            value=$(safe_get_meta "$product_id" "_g_language")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_i_language")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_language")
            ;;
        "weight")
            value=$(safe_get_meta "$product_id" "_calculated_weight")
            ;;
        "dimensions")
            value=$(safe_get_meta "$product_id" "_calculated_dimensions")
            ;;
        "price")
            value=$(safe_get_meta "$product_id" "_price")
            ;;
        "binding")
            value=$(safe_get_meta "$product_id" "_i_binding")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_physical_format")
            ;;
        "categories")
            value=$(safe_get_meta "$product_id" "_g_categories")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_i_subjects")
            [ -z "$value" ] && value=$(safe_get_meta "$product_id" "_o_subjects")
            ;;
    esac
    
    echo "$value"
}

# Fonction pour afficher les données manuelles WordPress
show_manual_wordpress_data() {
    local product_id=$1
    
    echo ""
    echo "📝 DONNÉES MANUELLES WORDPRESS"
    echo "┌─────────────────────┬─────────────────────────────────────────┬──────────┐"
    echo "│ Champ WordPress     │ Valeur actuelle                         │ Status   │"
    echo "├─────────────────────┼─────────────────────────────────────────┼──────────┤"
    
    # Prix
    value=$(safe_get_meta "$product_id" "_price")
    if [ -n "$value" ] && [ "$value" != "0" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_price" "$value €"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_price" "Non défini"
    fi
    
    # Prix régulier
    value=$(safe_get_meta "$product_id" "_regular_price")
    if [ -n "$value" ] && [ "$value" != "0" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_regular_price" "$value €"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_regular_price" "Non défini"
    fi
    
    # SKU
    value=$(safe_get_meta "$product_id" "_sku")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_sku" "$value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_sku" "Non défini"
    fi
    
    # ISBN
    value=$(safe_get_meta "$product_id" "_isbn")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_isbn" "$value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_isbn" "Non défini"
    fi
    
    # Stock
    value=$(safe_get_meta "$product_id" "_stock")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_stock" "$value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_stock" "Non défini"
    fi
    
    # Stock status
    value=$(safe_get_meta "$product_id" "_stock_status")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_stock_status" "$value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_stock_status" "Non défini"
    fi
    
    # État du livre
    value=$(safe_get_meta "$product_id" "_book_condition")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_book_condition" "$value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_book_condition" "Non défini"
    fi
    
    # Poids
    value=$(safe_get_meta "$product_id" "_weight")
    if [ -n "$value" ] && [ "$value" != "0" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_weight" "$value kg"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_weight" "Non défini"
    fi
    
    # Dimensions
    length=$(safe_get_meta "$product_id" "_length")
    width=$(safe_get_meta "$product_id" "_width")
    height=$(safe_get_meta "$product_id" "_height")
    if [ -n "$length" ] && [ -n "$width" ] && [ -n "$height" ]; then
        dims="${length}x${width}x${height} cm"
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_dimensions" "$dims"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_dimensions" "Non définies"
    fi
    
    # Catégorie Vinted
    value=$(safe_get_meta "$product_id" "_vinted_category_id")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_vinted_category_id" "$value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_vinted_category_id" "Non définie"
    fi
    
    # Code postal
    value=$(safe_get_meta "$product_id" "_location_zip")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_location_zip" "$value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_location_zip" "Non défini"
    fi
    
    # Notes personnelles
    value=$(safe_get_meta "$product_id" "_personal_notes")
    if [ -n "$value" ]; then
        display_value="${value:0:39}"
        [ ${#value} -gt 39 ] && display_value="${display_value:0:36}..."
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_personal_notes" "$display_value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_personal_notes" "Non définies"
    fi
    
    # Image WordPress
    value=$(safe_get_meta "$product_id" "_thumbnail_id")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_thumbnail_id" "Image #$value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_thumbnail_id" "Pas d'image WP"
    fi
    
    # Gestion stock
    value=$(safe_get_meta "$product_id" "_manage_stock")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-39s │ \033[32m✓ OK\033[0m     │\n" "_manage_stock" "$value"
    else
        printf "│ %-19s │ %-39s │ \033[31m✗ VIDE\033[0m   │\n" "_manage_stock" "Non défini"
    fi
    
    echo "└─────────────────────┴─────────────────────────────────────────┴──────────┘"
    
    # Compter les données manuelles présentes
    manual_count=0
    [ -n "$(safe_get_meta "$product_id" "_price")" ] && [ "$(safe_get_meta "$product_id" "_price")" != "0" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_regular_price")" ] && [ "$(safe_get_meta "$product_id" "_regular_price")" != "0" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_sku")" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_stock")" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_stock_status")" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_book_condition")" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_weight")" ] && [ "$(safe_get_meta "$product_id" "_weight")" != "0" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_vinted_category_id")" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_location_zip")" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_personal_notes")" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_thumbnail_id")" ] && ((manual_count++))
    [ -n "$(safe_get_meta "$product_id" "_manage_stock")" ] && ((manual_count++))
    
    echo ""
    echo "📊 Données manuelles renseignées : $manual_count / 14"
    echo ""
}

# Fonction pour analyser les données d'un livre
analyze_book_data() {
    local product_id=$1
    local phase=$2  # "AVANT" ou "APRÈS"
    local isbn="${3:-}"  # ISBN optionnel
    
    # Si l'ISBN n'est pas fourni, le récupérer
    if [ -z "$isbn" ]; then
        isbn=$(safe_get_meta "$product_id" "_isbn")
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 ANALYSE $phase COLLECTE - ISBN: $isbn (ID: $product_id)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Tableau des variables Google Books
    echo ""
    echo "🔹 GOOGLE BOOKS"
    
    # Vérifier si Google Books a répondu
    local g_test=$(safe_get_meta "$product_id" "_g_title")
    if [ -z "$g_test" ]; then
        echo "⚠️  API non disponible ou aucune donnée pour ce livre"
    else
        echo "✅ API connectée - Données disponibles"
    fi
    
    echo "┌──────────────────────────┬────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Variable                 │ Valeur                                                     │ Status   │"
    echo "├──────────────────────────┼────────────────────────────────────────────────────────────┼──────────┤"
    
    for var in title subtitle authors publisher publishedDate description pageCount categories language isbn10 isbn13 thumbnail smallThumbnail medium large extraLarge; do
        full_var="_g_${var}"
        value=$(safe_get_meta "$product_id" "$full_var")
        if [ -n "$value" ] && [ "$value" != "null" ]; then
            # Pour les URLs d'images, afficher sur 2 lignes si nécessaire
            if [[ "$var" =~ (thumbnail|Thumbnail|medium|large|Large) ]] && [ ${#value} -gt 60 ]; then
                display_value="${value:0:60}"
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$display_value"
                printf "│ %-24s │ %-58s │          │\n" "" "${value:60}"
            else
                display_value="${value:0:58}"
                [ ${#value} -gt 58 ] && display_value="${display_value:0:55}..."
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$display_value"
            fi
        else
            printf "│ %-24s │ %-58s │ \033[31m✗ MANQUE\033[0m │\n" "$full_var" "-"
        fi
    done
    echo "└──────────────────────────┴────────────────────────────────────────────────────────────┴──────────┘"
    
    # Tableau des variables ISBNdb
    echo ""
    echo "🔹 ISBNDB"
    
    # Vérifier si ISBNdb a répondu
    local i_test=$(safe_get_meta "$product_id" "_i_title")
    if [ -z "$i_test" ]; then
        echo "⚠️  API non disponible ou aucune donnée pour ce livre"
    else
        echo "✅ API connectée - Données disponibles"
    fi
    
    echo "┌──────────────────────────┬────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Variable                 │ Valeur                                                     │ Status   │"
    echo "├──────────────────────────┼────────────────────────────────────────────────────────────┼──────────┤"
    
    for var in title authors publisher synopsis binding pages subjects msrp language image; do
        full_var="_i_${var}"
        value=$(safe_get_meta "$product_id" "$full_var")
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0.00" ]; then
            # Pour l'URL de l'image, afficher sur 2 lignes si nécessaire
            if [ "$var" = "image" ] && [ ${#value} -gt 60 ]; then
                display_value="${value:0:60}"
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$display_value"
                printf "│ %-24s │ %-58s │          │\n" "" "${value:60}"
            else
                display_value="${value:0:58}"
                [ ${#value} -gt 58 ] && display_value="${display_value:0:55}..."
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$display_value"
            fi
        else
            printf "│ %-24s │ %-58s │ \033[31m✗ MANQUE\033[0m │\n" "$full_var" "-"
        fi
    done
    echo "└──────────────────────────┴────────────────────────────────────────────────────────────┴──────────┘"
    
    # Tableau des variables Open Library
    echo ""
    echo "🔹 OPEN LIBRARY"
    
    # Vérifier si Open Library a répondu
    local o_test=$(safe_get_meta "$product_id" "_o_title")
    if [ -z "$o_test" ]; then
        echo "⚠️  Pas de données pour ce livre (normal, base moins complète)"
    else
        echo "✅ API connectée - Données disponibles"
    fi
    
    echo "┌──────────────────────────┬────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Variable                 │ Valeur                                                     │ Status   │"
    echo "├──────────────────────────┼────────────────────────────────────────────────────────────┼──────────┤"
    
    for var in title authors publishers number_of_pages physical_format subjects description cover_small cover_medium cover_large; do
        full_var="_o_${var}"
        value=$(safe_get_meta "$product_id" "$full_var")
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0" ]; then
            # Pour les URLs de couverture, afficher sur 2 lignes si nécessaire
            if [[ "$var" =~ cover ]] && [ ${#value} -gt 60 ]; then
                display_value="${value:0:60}"
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$display_value"
                printf "│ %-24s │ %-58s │          │\n" "" "${value:60}"
            else
                display_value="${value:0:58}"
                [ ${#value} -gt 58 ] && display_value="${display_value:0:55}..."
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$display_value"
            fi
        else
            printf "│ %-24s │ %-58s │ \033[31m✗ MANQUE\033[0m │\n" "$full_var" "-"
        fi
    done
    echo "└──────────────────────────┴────────────────────────────────────────────────────────────┴──────────┘"
    
    # Tableau des variables calculées et finales
    echo ""
    echo "🔹 VARIABLES FINALES & MARKETPLACE"
    echo "┌──────────────────────────┬────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Variable                 │ Valeur                                                     │ Status   │"
    echo "├──────────────────────────┼────────────────────────────────────────────────────────────┼──────────┤"
    
    # Variables essentielles pour les marketplaces
    local essential_vars=(
        "best_title"
        "best_authors"
        "best_publisher"
        "best_pages"
        "best_description"
        "calculated_weight"
        "calculated_dimensions"
        "price"              # AJOUT DU PRIX
        "book_condition"     # AJOUT DE L'ÉTAT
        "vinted_condition"   # AJOUT ÉTAT VINTED
        "vinted_category_id" # AJOUT CATÉGORIE VINTED
        "wp_categories"      # AJOUT CATÉGORIES WORDPRESS
        "location_zip"       # AJOUT CODE POSTAL
        "api_collect_status"
        "api_collect_date"
        "has_description"
        "best_title_source"
        "best_authors_source"
        "best_description_source"
        "best_publisher_source"
        "api_collect_version"
        "api_calls_made"
        "calculated_bullet1"
        "calculated_bullet2"
        "calculated_bullet3"
        "calculated_bullet4"
        "calculated_bullet5"
        "groq_description"
    )
    
    for var in "${essential_vars[@]}"; do
        full_var="_${var}"
        value=$(safe_get_meta "$product_id" "$full_var")
        
        # Gérer l'affichage selon le type de variable
        if [ "$var" = "price" ]; then
            if [ -n "$value" ] && [ "$value" != "0" ]; then
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$value €"
            else
                printf "│ %-24s │ %-58s │ \033[31m✗ MANQUE\033[0m │\n" "$full_var" "❌ OBLIGATOIRE POUR EXPORT"
            fi
        elif [ "$var" = "book_condition" ]; then
            if [ -n "$value" ]; then
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$value"
            else
                printf "│ %-24s │ %-58s │ \033[33m⚠ MANQUE\033[0m │\n" "$full_var" "Recommandé pour marketplaces"
            fi
        elif [ "$var" = "vinted_condition" ]; then
            if [ -n "$value" ]; then
                condition_text=""
                case "$value" in
                    "5") condition_text="5 (Neuf avec étiquettes)" ;;
                    "4") condition_text="4 (Neuf sans étiquettes)" ;;
                    "3") condition_text="3 (Très bon état)" ;;
                    "2") condition_text="2 (Bon état)" ;;
                    "1") condition_text="1 (Satisfaisant)" ;;
                    *) condition_text="$value" ;;
                esac
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$condition_text"
            else
                printf "│ %-24s │ %-58s │ \033[33m⚠ MANQUE\033[0m │\n" "$full_var" "Requis pour Vinted"
            fi
        elif [ "$var" = "wp_categories" ]; then
            # Récupérer les catégories WordPress du produit
            local wp_cats=$(safe_mysql "
                SELECT GROUP_CONCAT(t.name SEPARATOR ', ')
                FROM wp_${SITE_ID}_term_relationships tr
                JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
                JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
                WHERE tr.object_id = $product_id
                AND tt.taxonomy = 'product_cat'")
            
            if [ -n "$wp_cats" ]; then
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "_wordpress_categories" "$wp_cats"
            else
                printf "│ %-24s │ %-58s │ \033[33m⚠ MANQUE\033[0m │\n" "_wordpress_categories" "Non catégorisé"
            fi
        elif [ "$var" = "location_zip" ]; then
            if [ -n "$value" ]; then
                printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$value"
            else
                printf "│ %-24s │ %-58s │ \033[33m⚠ MANQUE\033[0m │\n" "$full_var" "Requis pour Leboncoin"
            fi
        elif [ -n "$value" ] && [ "$value" != "null" ]; then
            display_value="${value:0:58}"
            [ ${#value} -gt 58 ] && display_value="${display_value:0:55}..."
            printf "│ %-24s │ %-58s │ \033[32m✓ OK\033[0m     │\n" "$full_var" "$display_value"
        else
            printf "│ %-24s │ %-58s │ \033[31m✗ MANQUE\033[0m │\n" "$full_var" "-"
        fi
    done
    echo "└──────────────────────────┴────────────────────────────────────────────────────────────┴──────────┘"
    
    # Statistiques
    echo ""
    echo "📊 STATISTIQUES"
    
    # Compter les variables présentes
    total_vars=0
    present_vars=0
    
    # Google Books (16 vars)
    for var in title subtitle authors publisher publishedDate description pageCount categories language isbn10 isbn13 thumbnail smallThumbnail medium large extraLarge; do
        ((total_vars++))
        value=$(safe_get_meta "$product_id" "_g_${var}")
        [ -n "$value" ] && [ "$value" != "null" ] && ((present_vars++))
    done
    
    # ISBNdb (10 vars)
    for var in title authors publisher synopsis binding pages subjects msrp language image; do
        ((total_vars++))
        value=$(safe_get_meta "$product_id" "_i_${var}")
        [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0.00" ] && ((present_vars++))
    done
    
    # Open Library (10 vars)
    for var in title authors publishers number_of_pages physical_format subjects description cover_small cover_medium cover_large; do
        ((total_vars++))
        value=$(safe_get_meta "$product_id" "_o_${var}")
        [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0" ] && ((present_vars++))
    done
    
    # Variables finales et marketplace (28 vars incluant prix et état)
    for var in "${essential_vars[@]}"; do
        ((total_vars++))
        value=$(safe_get_meta "$product_id" "_${var}")
        [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0" ] && ((present_vars++))
    done
    
    percentage=$((present_vars * 100 / total_vars))
    
    echo "Variables présentes : $present_vars / $total_vars ($percentage%)"
    
    # Afficher les données manuelles WordPress
    show_manual_wordpress_data "$product_id"
    
    # Résumé compatibilité
    _show_compatibility_summary "$product_id"
}

# Fonction pour afficher le résumé de compatibilité
_show_compatibility_summary() {
    local product_id=$1
    
    echo ""
    echo "🛒 COMPATIBILITÉ EXPORT MARKETPLACES"
    echo "┌─────────────────────┬────────────────┬────────────────┬──────────────────────────────────┐"
    echo "│ Donnée requise      │ Variable best  │ Status         │ Marketplaces concernées          │"
    echo "├─────────────────────┼────────────────┼────────────────┼──────────────────────────────────┤"
    
    # Titre
    value=$(safe_get_meta "$product_id" "_best_title")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-14s │ \033[32m✓ DISPONIBLE\033[0m   │ %-32s │\n" "Titre" "_best_title" "TOUTES"
    else
        printf "│ %-19s │ %-14s │ \033[31m✗ MANQUANT\033[0m    │ %-32s │\n" "Titre" "_best_title" "TOUTES - BLOQUANT !"
    fi
    
    # Auteur
    value=$(safe_get_meta "$product_id" "_best_authors")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-14s │ \033[32m✓ DISPONIBLE\033[0m   │ %-32s │\n" "Auteur(s)" "_best_authors" "Amazon Rakuten Fnac Vinted LBC"
    else
        printf "│ %-19s │ %-14s │ \033[33m⚠ MANQUANT\033[0m     │ %-32s │\n" "Auteur(s)" "_best_authors" "Requis sauf Cdiscount"
    fi
    
    # Éditeur
    value=$(safe_get_meta "$product_id" "_best_publisher")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-14s │ \033[32m✓ DISPONIBLE\033[0m   │ %-32s │\n" "Éditeur" "_best_publisher" "Amazon Rakuten Cdiscount Fnac"
    else
        printf "│ %-19s │ %-14s │ \033[33m⚠ MANQUANT\033[0m     │ %-32s │\n" "Éditeur" "_best_publisher" "Requis sauf Vinted/LBC"
    fi
    
    # Description
    value=$(safe_get_meta "$product_id" "_best_description")
    groq=$(safe_get_meta "$product_id" "_groq_description")
    if [ -n "$value" ] || [ -n "$groq" ]; then
        printf "│ %-19s │ %-14s │ \033[32m✓ DISPONIBLE\033[0m   │ %-32s │\n" "Description" "_best_description" "TOUTES"
    else
        printf "│ %-19s │ %-14s │ \033[31m✗ MANQUANT\033[0m    │ %-32s │\n" "Description" "_best_description" "TOUTES - BLOQUANT !"
    fi
    
    # ISBN
    value=$(safe_get_meta "$product_id" "_isbn")
    if [ -n "$value" ]; then
        printf "│ %-19s │ %-14s │ \033[32m✓ DISPONIBLE\033[0m   │ %-32s │\n" "ISBN/EAN" "_isbn" "TOUTES - Obligatoire"
    else
        printf "│ %-19s │ %-14s │ \033[31m✗ MANQUANT\033[0m    │ %-32s │\n" "ISBN/EAN" "_isbn" "TOUTES - BLOQUANT !"
    fi
    
    # Prix
    value=$(safe_get_meta "$product_id" "_price")
    if [ -n "$value" ] && [ "$value" != "0" ]; then
        printf "│ %-19s │ %-14s │ \033[32m✓ DISPONIBLE\033[0m   │ %-32s │\n" "Prix" "_price" "TOUTES - Obligatoire"
    else
        printf "│ %-19s │ %-14s │ \033[31m✗ MANQUANT\033[0m    │ %-32s │\n" "Prix" "_price" "TOUTES - BLOQUANT !"
    fi
    
    echo "└─────────────────────┴────────────────┴────────────────┴──────────────────────────────────┘"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}