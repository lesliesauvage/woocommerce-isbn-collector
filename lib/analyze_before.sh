#!/bin/bash
echo "[START: analyze_before.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# lib/analyze_before.sh - Affichage de l'état AVANT collecte

# Couleurs ANSI
GREEN='\033[0;32m'
BOLD='\033[1m'
NC='\033[0m'

# Fonction pour obtenir la hiérarchie complète d'une catégorie
get_full_category_hierarchy() {
    local term_id="$1"
    local hierarchy=""
    
    while [ -n "$term_id" ] && [ "$term_id" != "0" ]; do
        local cat_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT t.name, tt.parent
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE t.term_id = $term_id AND tt.taxonomy = 'product_cat'
        " 2>/dev/null)
        
        if [ -n "$cat_info" ]; then
            local cat_name=$(echo "$cat_info" | cut -f1)
            local parent_id=$(echo "$cat_info" | cut -f2)
            
            if [ -z "$hierarchy" ]; then
                hierarchy="$cat_name"
            else
                hierarchy="$cat_name > $hierarchy"
            fi
            
            term_id="$parent_id"
        else
            break
        fi
    done
    
    echo "$hierarchy"
}

# Fonction pour afficher l'état avant collecte
show_before_state() {
    local id=$1
    local isbn=$2

    # Récupérer les informations de base
    local title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_title FROM wp_${SITE_ID}_posts WHERE ID=$id")

    local status=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_status FROM wp_${SITE_ID}_posts WHERE ID=$id")

    local created=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_date FROM wp_${SITE_ID}_posts WHERE ID=$id")

    local modified=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_modified FROM wp_${SITE_ID}_posts WHERE ID=$id")

    # Récupérer les catégories avec hiérarchie complète
    local categories_hierarchy=""
    local category_ids=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT tt.term_id
        FROM wp_${SITE_ID}_term_relationships tr
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        WHERE tr.object_id = $id 
        AND tt.taxonomy = 'product_cat'
        AND tt.term_id NOT IN (3088, 3089)
        " 2>/dev/null)

    if [ -n "$category_ids" ]; then
        local first=1
        while read cat_id; do
            local full_hierarchy=$(get_full_category_hierarchy "$cat_id")
            if [ $first -eq 1 ]; then
                categories_hierarchy="$full_hierarchy"
                first=0
            else
                categories_hierarchy="$categories_hierarchy, $full_hierarchy"
            fi
        done <<< "$category_ids"
    else
        categories_hierarchy="NON CATÉGORISÉ"
    fi

    echo "📚 INFORMATIONS WORDPRESS DE BASE"
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    echo "ID Produit        : $id"
    echo "ISBN              : $isbn"
    echo "Titre WordPress   : $title"
    echo "Statut            : $status"
    echo "Date création     : $created"
    echo "Dernière modif    : $modified"
    echo -e "CATÉGORIES WP     : ${GREEN}${BOLD}$categories_hierarchy${NC}"

    # Tableau des données commerciales et physiques
    echo ""
    echo "💰 DONNÉES COMMERCIALES, PHYSIQUES ET MARKETPLACE"
    printf "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐\n"
    printf "│ %-44s │ %-102s │ %-8s │\n" "Champ" "Valeur actuelle" "Status"
    printf "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤\n"

    # Prix
    local price=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_price' LIMIT 1")
    if [ -n "$price" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Prix de vente (_price)" "$price €" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Prix de vente (_price)" "Non défini" "✗ VIDE"
    fi

    # État du livre
    local condition=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_book_condition' LIMIT 1")
    if [ -n "$condition" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "État du livre (_book_condition)" "$condition" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "État du livre (_book_condition)" "Non défini" "✗ VIDE"
    fi

    # Condition Vinted
    local vinted_condition=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_vinted_condition' LIMIT 1")
    if [ -n "$vinted_condition" ]; then
        # Mapper la valeur numérique au texte
        case "$vinted_condition" in
            1) vinted_text="1 - Neuf avec étiquette" ;;
            2) vinted_text="2 - Neuf sans étiquette" ;;
            3) vinted_text="3 - Très bon état" ;;
            4) vinted_text="4 - Bon état" ;;
            5) vinted_text="5 - Satisfaisant" ;;
            *) vinted_text="$vinted_condition" ;;
        esac
        printf "│ %-44s │ %-102s │ %-8s │\n" "Condition Vinted (_vinted_condition)" "$vinted_text" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Condition Vinted (_vinted_condition)" "Non défini" "✗ VIDE"
    fi

    # Catégorie Vinted - UTILISER _cat_vinted au lieu de _vinted_category
    local vinted_cat=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_cat_vinted' LIMIT 1")
    if [ -n "$vinted_cat" ]; then
        # Mapper l'ID de catégorie Vinted
        case "$vinted_cat" in
            1601) vinted_cat_text="1601 - Livres (défaut)" ;;
            57) vinted_cat_text="57 - Bandes dessinées" ;;
            *) vinted_cat_text="$vinted_cat" ;;
        esac
        printf "│ %-44s │ %-102s │ %-8s │\n" "Catégorie Vinted" "$vinted_cat_text" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Catégorie Vinted" "1601 - Livres (défaut)" "⚠ VIDE"
    fi

    # Stock
    local stock=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_stock' LIMIT 1")
    local stock_status=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_stock_status' LIMIT 1")

    if [ -n "$stock" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Quantité en stock" "$stock" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Quantité en stock" "Non défini" "✗ VIDE"
    fi

    if [ -n "$stock_status" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Statut du stock" "$stock_status" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Statut du stock" "Non défini" "✗ VIDE"
    fi

    # Poids et dimensions
    local weight=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_calculated_weight' LIMIT 1")
    if [ -n "$weight" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Poids calculé (_calculated_weight)" "$weight g (estimé d'après le nombre de pages)" "⚠ CALC"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Poids calculé (_calculated_weight)" "Non calculé" "✗ VIDE"
    fi

    local dimensions=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_calculated_dimensions' LIMIT 1")
    if [ -n "$dimensions" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Dimensions calculées" "$dimensions cm (estimation standard)" "⚠ CALC"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Dimensions calculées" "Non calculées" "✗ VIDE"
    fi

    # Code postal
    local zip=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_location_zip' LIMIT 1")
    if [ -n "$zip" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Code postal (_location_zip)" "$zip" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Code postal (_location_zip)" "Non défini" "✗ VIDE"
    fi

    printf "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘\n"

    # Tableau des données bibliographiques
    echo ""
    echo "📖 DONNÉES BIBLIOGRAPHIQUES ACTUELLES"
    printf "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐\n"
    printf "│ %-44s │ %-102s │ %-8s │\n" "Champ" "Valeur actuelle" "Status"
    printf "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤\n"

    # Titre final
    local best_title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_title' LIMIT 1")
    if [ -n "$best_title" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Titre final" "$best_title" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Titre final" "Non défini" "✗ VIDE"
    fi

    # Auteur(s)
    local best_authors=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_authors' LIMIT 1")
    if [ -n "$best_authors" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Auteur(s)" "$best_authors" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Auteur(s)" "Non défini" "✗ VIDE"
    fi

    # Éditeur
    local best_publisher=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_publisher' LIMIT 1")
    if [ -n "$best_publisher" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Éditeur" "$best_publisher" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Éditeur" "Non défini" "✗ VIDE"
    fi

    # Nombre de pages
    local best_pages=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_pages' LIMIT 1")
    if [ -n "$best_pages" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Nombre de pages" "$best_pages" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Nombre de pages" "Non défini" "✗ VIDE"
    fi

    # Description
    local best_description=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_description' LIMIT 1")
    if [ -n "$best_description" ]; then
        # Tronquer si trop long
        if [ ${#best_description} -gt 97 ]; then
            best_description="${best_description:0:97}..."
        fi
        printf "│ %-44s │ %-102s │ %-8s │\n" "Description" "$best_description" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Description" "Non définie" "✗ VIDE"
    fi

    # Format/Reliure
    local binding=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_i_binding' LIMIT 1")
    if [ -n "$binding" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Format/Reliure" "$binding" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Format/Reliure" "Pas encore collecté" "✗ VIDE"
    fi

    # Langue
    local language=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_g_language' LIMIT 1")
    if [ -n "$language" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Langue" "$language" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Langue" "Non définie" "✗ VIDE"
    fi

    # Date de publication
    local pub_date=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_g_publishedDate' LIMIT 1")
    if [ -n "$pub_date" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Date de publication" "$pub_date" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Date de publication" "Non définie" "✗ VIDE"
    fi

    # Statut de collecte
    local collection_status=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_collection_status' LIMIT 1")
    if [ "$collection_status" = "completed" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Statut de collecte" "completed" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Statut de collecte" "Non collecté" "✗ VIDE"
    fi

    # Date de dernière collecte
    local last_collected=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_last_collected' LIMIT 1")
    if [ -n "$last_collected" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Date dernière collecte" "$last_collected" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Date dernière collecte" "Jamais collecté" "✗ VIDE"
    fi

    # A une description
    local has_description=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_has_description' LIMIT 1")
    if [ "$has_description" = "1" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "A une description" "1" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "A une description" "0" "✗ VIDE"
    fi

    printf "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘\n"

    # Tableau des images
    echo ""
    echo "🖼️  IMAGES ACTUELLES"
    printf "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐\n"
    printf "│ %-44s │ %-102s │ %-8s │\n" "Source / Type" "URL de l'image" "Status"
    printf "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤\n"

    # Images Google
    local g_thumb=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_g_thumbnail' LIMIT 1")
    if [ -n "$g_thumb" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Google Thumbnail" "$g_thumb" "✓ OK"
    fi

    local g_small=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_g_smallThumbnail' LIMIT 1")
    if [ -n "$g_small" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Google Small Thumbnail" "$g_small" "✓ OK"
    fi

    # Images Open Library
    local o_large=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_o_cover_large' LIMIT 1")
    if [ -n "$o_large" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Open Library Large" "$o_large" "✓ OK"
    fi

    local o_medium=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_o_cover_medium' LIMIT 1")
    if [ -n "$o_medium" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Open Library Medium" "$o_medium" "✓ OK"
    fi

    local o_small=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_o_cover_small' LIMIT 1")
    if [ -n "$o_small" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Open Library Small" "$o_small" "✓ OK"
    fi

    printf "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘\n"

    # Statistiques
    echo ""
    echo "📊 STATISTIQUES DE L'ÉTAT ACTUEL"
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"

    local g_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key LIKE '_g_%'")
    local i_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key LIKE '_i_%'")
    local o_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key LIKE '_o_%'")
    local best_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND (meta_key LIKE '_best_%' OR meta_key LIKE '_calculated_%')")

    local total_count=$((g_count + i_count + o_count + best_count))

    echo "Google Books    : $g_count données"
    echo "ISBNdb          : $i_count données"
    echo "Open Library    : $o_count données"
    echo "Best/Calculées  : $best_count données"
    echo "TOTAL           : $total_count données"

    # Compter les images
    local image_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta
        WHERE post_id=$id
        AND (meta_key LIKE '%thumbnail%' OR meta_key LIKE '%cover_%' OR meta_key LIKE '%image%')
        AND meta_value != ''")
    echo "Images          : $image_count trouvée(s)"

    echo ""
    echo "EXPORTABILITÉ ACTUELLE :"

    # Vérifier l'exportabilité
    if [ -n "$best_title" ] && [ -n "$price" ] && [ -n "$best_description" ] && [ $image_count -gt 0 ]; then
        echo "  ✅ Prêt pour export vers certaines marketplaces"
    else
        echo "  ⚠️  Données manquantes pour l'export complet"
    fi
}

echo "[END: analyze_before.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2