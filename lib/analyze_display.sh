#!/bin/bash
# lib/analyze_display.sh - Fonctions d'affichage pour analyze_with_collect.sh

# Fonction pour afficher l'état AVANT (Section 1)
show_before_state() {
    local product_id=$1
    local isbn=$2
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📊 SECTION 1 : ÉTAT ACTUEL DU LIVRE (AVANT COLLECTE)"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    # Informations WordPress de base
    echo ""
    echo "📚 INFORMATIONS WORDPRESS DE BASE"
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    
    # Récupérer toutes les infos WordPress d'un coup
    local wp_data=$(safe_mysql "
        SELECT 
            p.ID,
            p.post_title,
            p.post_status,
            p.post_date,
            p.post_modified,
            GROUP_CONCAT(DISTINCT t.name) as categories
        FROM wp_${SITE_ID}_posts p
        LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
        LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id AND tt.taxonomy = 'product_cat'
        LEFT JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
        WHERE p.ID = $product_id
        GROUP BY p.ID")
    
    # Parser les données WordPress
    IFS=$'\t' read -r wp_id wp_title wp_status wp_date wp_modified wp_categories <<< "$wp_data"
    
    echo "ID Produit        : $product_id"
    echo "ISBN              : $isbn"
    echo "Titre WordPress   : $wp_title"
    echo "Statut            : $wp_status"
    echo "Date création     : $wp_date"
    echo "Dernière modif    : $wp_modified"
    echo "CATÉGORIES WP     : ${wp_categories:-NON CATÉGORISÉ}"
    
    # Tableau des données commerciales et physiques
    echo ""
    echo "💰 DONNÉES COMMERCIALES, PHYSIQUES ET MARKETPLACE"
    echo "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Champ                                        │ Valeur actuelle                                                                                        │ Status   │"
    echo "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤"
    
    # Prix
    local price=$(safe_get_meta "$product_id" "_price")
    if [ -n "$price" ] && [ "$price" != "0" ]; then
        printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "Prix de vente (_price)" "$price €"
    else
        printf "│ %-44s │ %-102s │ \033[31m✗ VIDE\033[0m   │\n" "Prix de vente (_price)" "❌ OBLIGATOIRE POUR EXPORT - À DÉFINIR"
    fi
    
    # État du livre
    local condition=$(safe_get_meta "$product_id" "_book_condition")
    if [ -n "$condition" ]; then
        printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "État du livre (_book_condition)" "$condition"
    else
        printf "│ %-44s │ %-102s │ \033[33m⚠ VIDE\033[0m   │\n" "État du livre (_book_condition)" "Non défini - Recommandé pour marketplaces"
    fi
    
    # État Vinted
    local vinted_condition=$(safe_get_meta "$product_id" "_vinted_condition")
    if [ -n "$vinted_condition" ]; then
        local vinted_text=""
        case "$vinted_condition" in
            "5") vinted_text="5 - Neuf avec étiquettes" ;;
            "4") vinted_text="4 - Neuf sans étiquettes" ;;
            "3") vinted_text="3 - Très bon état" ;;
            "2") vinted_text="2 - Bon état" ;;
            "1") vinted_text="1 - Satisfaisant" ;;
            *) vinted_text="$vinted_condition" ;;
        esac
        printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "Condition Vinted (_vinted_condition)" "$vinted_text"
    else
        printf "│ %-44s │ %-102s │ \033[33m⚠ VIDE\033[0m   │\n" "Condition Vinted (_vinted_condition)" "Non défini - Requis pour Vinted"
    fi
    
    # Catégorie Vinted
    local vinted_cat=$(safe_get_meta "$product_id" "_vinted_category_id")
    if [ -n "$vinted_cat" ]; then
        local cat_name=""
        case "$vinted_cat" in
            "1196") cat_name="1196 - Romans et littérature" ;;
            "1197") cat_name="1197 - BD et mangas" ;;
            "1198") cat_name="1198 - Livres pour enfants" ;;
            "1199") cat_name="1199 - Études et références" ;;
            "1200") cat_name="1200 - Non-fiction et documentaires" ;;
            "1201") cat_name="1201 - Autres livres" ;;
            "1601") cat_name="1601 - Livres (catégorie générale)" ;;
            *) cat_name="$vinted_cat - Catégorie personnalisée" ;;
        esac
        printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "Catégorie Vinted (_vinted_category_id)" "$cat_name"
    else
        printf "│ %-44s │ %-102s │ \033[33m⚠ VIDE\033[0m   │\n" "Catégorie Vinted" "1601 - Livres (défaut)"
    fi
    
    # Stock
    local stock=$(safe_get_meta "$product_id" "_stock")
    local stock_status=$(safe_get_meta "$product_id" "_stock_status")
    printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "Quantité en stock" "${stock:-1}"
    printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "Statut du stock" "${stock_status:-instock}"
    
    # Poids
    local weight=$(safe_get_meta "$product_id" "_weight")
    local calc_weight=$(safe_get_meta "$product_id" "_calculated_weight")
    if [ -n "$weight" ] && [ "$weight" != "0" ]; then
        printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "Poids WooCommerce (_weight)" "$weight kg"
    elif [ -n "$calc_weight" ]; then
        printf "│ %-44s │ %-102s │ \033[33m⚠ CALC\033[0m   │\n" "Poids calculé (_calculated_weight)" "$calc_weight g (estimé d'après le nombre de pages)"
    else
        printf "│ %-44s │ %-102s │ \033[31m✗ VIDE\033[0m   │\n" "Poids" "Non défini"
    fi
    
    # Dimensions
    local length=$(safe_get_meta "$product_id" "_length")
    local width=$(safe_get_meta "$product_id" "_width")
    local height=$(safe_get_meta "$product_id" "_height")
    local calc_dims=$(safe_get_meta "$product_id" "_calculated_dimensions")
    if [ -n "$length" ] && [ -n "$width" ] && [ -n "$height" ]; then
        printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "Dimensions WooCommerce" "${length}×${width}×${height} cm"
    elif [ -n "$calc_dims" ]; then
        printf "│ %-44s │ %-102s │ \033[33m⚠ CALC\033[0m   │\n" "Dimensions calculées" "$calc_dims cm (estimation standard)"
    else
        printf "│ %-44s │ %-102s │ \033[31m✗ VIDE\033[0m   │\n" "Dimensions" "Non définies"
    fi
    
    # Code postal
    local zip=$(safe_get_meta "$product_id" "_location_zip")
    if [ -n "$zip" ]; then
        printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "Code postal (_location_zip)" "$zip"
    else
        printf "│ %-44s │ %-102s │ \033[33m⚠ VIDE\033[0m   │\n" "Code postal" "Non défini - Requis pour Leboncoin"
    fi
    
    echo "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘"
    
    # Tableau des métadonnées livre existantes
    echo ""
    echo "📖 DONNÉES BIBLIOGRAPHIQUES ACTUELLES"
    echo "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Champ                                        │ Valeur actuelle                                                                                        │ Status   │"
    echo "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤"
    
    # Toutes les métadonnées importantes
    local fields=(
        "_best_title|Titre final"
        "_best_authors|Auteur(s)"
        "_best_publisher|Éditeur"
        "_best_pages|Nombre de pages"
        "_best_description|Description"
        "_i_binding|Format/Reliure"
        "_g_language|Langue"
        "_g_publishedDate|Date de publication"
        "_api_collect_status|Statut de collecte"
        "_api_collect_date|Date dernière collecte"
        "_has_description|A une description"
    )
    
    for field_info in "${fields[@]}"; do
        IFS='|' read -r field_key field_name <<< "$field_info"
        local value=$(safe_get_meta "$product_id" "$field_key")
        
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0" ]; then
            # Tronquer si trop long
            if [ ${#value} -gt 102 ]; then
                printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "$field_name" "${value:0:99}..."
            else
                printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "$field_name" "$value"
            fi
        else
            printf "│ %-44s │ %-102s │ \033[31m✗ VIDE\033[0m   │\n" "$field_name" "Pas encore collecté"
        fi
    done
    
    echo "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘"
    
    # Images actuelles
    echo ""
    echo "🖼️  IMAGES ACTUELLES"
    echo "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Source / Type                                │ URL de l'image                                                                                         │ Status   │"
    echo "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤"
    
    # Vérifier toutes les sources d'images
    local image_sources=(
        "_i_image|ISBNdb"
        "_g_extraLarge|Google Extra Large"
        "_g_large|Google Large"
        "_g_medium|Google Medium"
        "_g_thumbnail|Google Thumbnail"
        "_g_smallThumbnail|Google Small Thumbnail"
        "_o_cover_large|Open Library Large"
        "_o_cover_medium|Open Library Medium"
        "_o_cover_small|Open Library Small"
    )
    
    local image_count=0
    for img_info in "${image_sources[@]}"; do
        IFS='|' read -r img_key img_name <<< "$img_info"
        local img_url=$(safe_get_meta "$product_id" "$img_key")
        
        if [ -n "$img_url" ] && [ "$img_url" != "null" ]; then
            ((image_count++))
            printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "$img_name" "$img_url"
        fi
    done
    
    if [ $image_count -eq 0 ]; then
        printf "│ %-44s │ %-102s │ \033[31m✗ VIDE\033[0m   │\n" "AUCUNE IMAGE" "Aucune image trouvée pour ce livre"
    fi
    
    echo "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘"
    
    # Statistiques de l'état actuel
    echo ""
    echo "📊 STATISTIQUES DE L'ÉTAT ACTUEL"
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    
    local google_count=$(count_book_data "$product_id" "_g")
    local isbndb_count=$(count_book_data "$product_id" "_i")
    local ol_count=$(count_book_data "$product_id" "_o")
    local best_count=$(count_book_data "$product_id" "_best")
    local calc_count=$(count_book_data "$product_id" "_calculated")
    local total_count=$((google_count + isbndb_count + ol_count + best_count + calc_count))
    
    echo "Google Books    : $google_count données"
    echo "ISBNdb          : $isbndb_count données"
    echo "Open Library    : $ol_count données"
    echo "Best/Calculées  : $((best_count + calc_count)) données"
    echo "TOTAL           : $total_count données"
    echo "Images          : $image_count trouvée(s)"
    
    # Vérifier l'exportabilité actuelle
    echo ""
    echo "EXPORTABILITÉ ACTUELLE :"
    local exportable=0
    local has_title=0
    local has_price=0
    local has_description=0
    local has_image=0
    
    # Vérifier le prix
    if [ -n "$price" ] && [ "$price" != "0" ]; then
        has_price=1
        ((exportable++))
    else
        echo "  ❌ Prix manquant - BLOQUANT pour tous"
    fi
    
    # Vérifier le titre (soit _best_title soit _g_title)
    local title_check=$(safe_get_meta "$product_id" "_best_title")
    [ -z "$title_check" ] && title_check=$(safe_get_meta "$product_id" "_g_title")
    if [ -n "$title_check" ]; then
        has_title=1
        ((exportable++))
    else
        echo "  ❌ Titre manquant"
    fi
    
    # Vérifier la description
    local desc_check=$(safe_get_meta "$product_id" "_best_description")
    [ -z "$desc_check" ] && desc_check=$(safe_get_meta "$product_id" "_groq_description")
    if [ -n "$desc_check" ]; then
        has_description=1
        ((exportable++))
    else
        echo "  ❌ Description manquante"
    fi
    
    # Vérifier les images
    if [ $image_count -gt 0 ]; then
        has_image=1
        ((exportable++))
    else
        echo "  ❌ Image manquante"
    fi
    
    if [ $exportable -eq 4 ]; then
        echo "  ✅ Prêt pour export vers certaines marketplaces"
    else
        echo "  ⚠️  Données insuffisantes pour export ($exportable/4 critères remplis)"
    fi
}

# Fonction pour afficher les résultats de collecte API (Section 2)
show_api_collection() {
    local product_id=$1
    local isbn=$2
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "🔄 SECTION 2 : COLLECTE DES DONNÉES VIA APIs"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    # Google Books
    echo ""
    echo "🔵 GOOGLE BOOKS API"
    local g_test=$(safe_get_meta "$product_id" "_g_title")
    if [ -z "$g_test" ]; then
        echo "⚠️  Statut : Aucune donnée trouvée pour cet ISBN"
    else
        echo "✅ Statut : Données collectées avec succès"
    fi
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Variable Google Books                        │ Valeur collectée                                                                                       │ Status   │"
    echo "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤"
    
    # Afficher toutes les variables Google Books
    local g_vars=(title subtitle authors publisher publishedDate description pageCount categories language isbn10 isbn13 
                  thumbnail smallThumbnail medium large extraLarge height width thickness printType 
                  averageRating ratingsCount previewLink infoLink listPrice retailPrice)
    
    for var in "${g_vars[@]}"; do
        local value=$(safe_get_meta "$product_id" "_g_$var")
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0" ]; then
            # Pour les URLs, afficher complètement
            if [[ "$var" =~ (Link|thumbnail|Thumbnail|medium|large|Large) ]]; then
                printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "_g_$var" "$value"
            else
                local display_value="${value:0:102}"
                [ ${#value} -gt 102 ] && display_value="${value:0:99}..."
                printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "_g_$var" "$display_value"
            fi
        else
            printf "│ %-44s │ %-102s │ \033[31m✗ MANQUE\033[0m │\n" "_g_$var" "-"
        fi
    done
    
    echo "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘"
    
    # ISBNdb
echo ""
    echo "🟢 ISBNDB API"
    
    # Vérifier si on a des données ISBNdb
    local i_test=$(safe_get_meta "$product_id" "_i_title")
    local i_binding=$(safe_get_meta "$product_id" "_i_binding")
    
    if [ -n "$i_test" ] || [ -n "$i_binding" ]; then
        echo "✅ Statut : Données collectées avec succès"
    else
        # Vérifier si on a une clé API
        if [ -z "$ISBNDB_KEY" ]; then
            echo "❌ Statut : Clé API non configurée"
        else
            # Vérifier si on a tenté l'appel
            local isbndb_attempt=$(safe_get_meta "$product_id" "_isbndb_last_attempt")
            if [ -n "$isbndb_attempt" ]; then
                echo "⚠️  Statut : Aucune donnée trouvée pour cet ISBN"
            else
                echo "❌ Statut : Erreur de connexion à l'API"
            fi
        fi
    fi
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    local i_test=$(safe_get_meta "$product_id" "_i_title")
    if [ -z "$i_test" ]; then
        echo "⚠️  Statut : Aucune donnée trouvée ou API non accessible"
    else
        echo "✅ Statut : Données collectées avec succès"
    fi
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Variable ISBNdb                              │ Valeur collectée                                                                                       │ Status   │"
    echo "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤"
    
    local i_vars=(title authors publisher synopsis overview binding pages subjects msrp language 
                  date_published isbn10 isbn13 dimensions image)
    
    for var in "${i_vars[@]}"; do
        local value=$(safe_get_meta "$product_id" "_i_$var")
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0.00" ] && [ "$value" != "0" ]; then
            if [ "$var" = "image" ]; then
                printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "_i_$var" "$value"
            else
                local display_value="${value:0:102}"
                [ ${#value} -gt 102 ] && display_value="${value:0:99}..."
                printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "_i_$var" "$display_value"
            fi
        else
            printf "│ %-44s │ %-102s │ \033[31m✗ MANQUE\033[0m │\n" "_i_$var" "-"
        fi
    done
    
    echo "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘"
    
    # Open Library
    echo ""
    echo "🟠 OPEN LIBRARY API"
    local o_test=$(safe_get_meta "$product_id" "_o_title")
    if [ -z "$o_test" ]; then
        echo "⚠️  Statut : Pas de données pour ce livre (c'est NORMAL, leur base est moins complète que Google/ISBNdb)"
    else
        echo "✅ Statut : Données collectées avec succès"
    fi
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    echo ""
    echo "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Variable Open Library                        │ Valeur collectée                                                                                       │ Status   │"
    echo "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤"
    
    local o_vars=(title authors publishers number_of_pages physical_format subjects description 
                  first_sentence excerpts cover_small cover_medium cover_large)
    
    for var in "${o_vars[@]}"; do
        local value=$(safe_get_meta "$product_id" "_o_$var")
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0" ]; then
            if [[ "$var" =~ cover ]]; then
                printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "_o_$var" "$value"
            else
                local display_value="${value:0:102}"
                [ ${#value} -gt 102 ] && display_value="${value:0:99}..."
                printf "│ %-44s │ %-102s │ \033[32m✓ OK\033[0m     │\n" "_o_$var" "$display_value"
            fi
        else
            printf "│ %-44s │ %-102s │ \033[31m✗ MANQUE\033[0m │\n" "_o_$var" "-"
        fi
    done
    
    echo "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘"
    
    # Groq IA si utilisé
    local groq_desc=$(safe_get_meta "$product_id" "_groq_description")
    if [ -n "$groq_desc" ]; then
        echo ""
        echo "🤖 GROQ IA"
        echo "✅ Statut : Description générée par intelligence artificielle"
        echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
        echo ""
        echo "Description générée (${#groq_desc} caractères) :"
        echo "$groq_desc" | fold -s -w 150
    fi
}