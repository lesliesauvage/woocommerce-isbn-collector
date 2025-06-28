#!/bin/bash

echo "=== MARTINGALE COMPLÈTE CORRIGÉE - AVEC IMAGES ET DESCRIPTIONS ==="
echo ""

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

# Catégories Vinted pour les livres
determine_vinted_category() {
    local categories="$1"
    local title="$2"
    local subjects="$3"
    
    # Vérifier les mots-clés dans l'ordre de priorité
    
    # Romans et littérature
    if [[ "$categories" =~ (Fiction|Literature|Literary|Romance|Novel) ]] || \
       [[ "$title" =~ (Roman|roman|Littérature|littérature) ]]; then
        echo "1196|Romans et littérature"
        return
    fi
    
    # BD et mangas
    if [[ "$categories" =~ (Comics|Manga|Graphic) ]] || \
       [[ "$title" =~ (BD|Manga|manga|Bande dessinée) ]]; then
        echo "1197|BD et mangas"
        return
    fi
    
    # Livres pour enfants
    if [[ "$categories" =~ (Children|Juvenile|Young Adult) ]] || \
       [[ "$title" =~ (Enfant|enfant|Jeunesse|jeunesse) ]]; then
        echo "1198|Livres pour enfants"
        return
    fi
    
    # Études et références
    if [[ "$categories" =~ (Reference|Study|Education|Dictionary|Academic) ]] || \
       [[ "$title" =~ (Dictionnaire|dictionnaire|Étude|étude|Manuel|manuel) ]] || \
       [[ "$subjects" =~ (Reference|Dictionary|Study) ]]; then
        echo "1199|Études et références"
        return
    fi
    
    # Non-fiction et documentaires
    if [[ "$categories" =~ (Non-fiction|Biography|History|Science|Documentary) ]] || \
       [[ "$title" =~ (Histoire|histoire|Biographie|biographie|Science|science) ]]; then
        echo "1200|Non-fiction et documentaires"
        return
    fi
    
    # Autres livres (par défaut)
    echo "1201|Autres livres"
}

# Fonction pour afficher toutes les données d'un livre
show_complete_book_data() {
    local product_id=$1
    local isbn=$2
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 FICHE COMPLÈTE - ISBN: $isbn"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Récupérer TOUTES les données en une seule requête
    local all_data=$(mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "
        SELECT meta_key, meta_value 
        FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $product_id 
        AND meta_key LIKE '_%'
        AND meta_key NOT LIKE '_wp_%'
        AND meta_key NOT LIKE '_edit_%'
        AND meta_key NOT LIKE '_sku'
        AND meta_key NOT LIKE '_price'
        AND meta_key NOT LIKE '_stock%'
        AND meta_key NOT LIKE '_regular_price'
        AND meta_key NOT LIKE '_sale_price'
        AND meta_key NOT LIKE '_manage%'
        AND meta_key NOT LIKE '_backorders'
        AND meta_key NOT LIKE '_sold_individually'
        AND meta_key NOT LIKE '_virtual'
        AND meta_key NOT LIKE '_downloadable'
        AND meta_key NOT LIKE '_product_%'
        AND meta_key NOT LIKE '_weight'
        AND meta_key NOT LIKE '_length'
        AND meta_key NOT LIKE '_width'
        AND meta_key NOT LIKE '_height'
        ORDER BY meta_key;")
    
    # Créer un tableau associatif avec toutes les données
    declare -A book_data
    while IFS=$'\t' read -r key value; do
        book_data["$key"]="$value"
    done <<< "$all_data"
    
    # Afficher les données par source
    echo "🔍 DONNÉES COLLECTÉES PAR API"
    echo "─────────────────────────────"
    
    # Google Books
    echo ""
    echo "1️⃣ GOOGLE BOOKS"
    local google_found=0
    for key in "${!book_data[@]}"; do
        if [[ $key == _g_* ]]; then
            ((google_found++))
            local display_key=${key:3}
            local display_value="${book_data[$key]:0:60}"
            [ ${#book_data[$key]} -gt 60 ] && display_value="${display_value}..."
            echo "   ✓ $display_key: $display_value"
        fi
    done
    [ $google_found -eq 0 ] && echo "   ✗ Aucune donnée"
    
    # ISBNdb
    echo ""
    echo "2️⃣ ISBNDB"
    local isbndb_found=0
    for key in "${!book_data[@]}"; do
        if [[ $key == _i_* ]]; then
            ((isbndb_found++))
            local display_key=${key:3}
            local display_value="${book_data[$key]:0:60}"
            [ ${#book_data[$key]} -gt 60 ] && display_value="${display_value}..."
            echo "   ✓ $display_key: $display_value"
        fi
    done
    [ $isbndb_found -eq 0 ] && echo "   ✗ Aucune donnée"
    
    # Open Library
    echo ""
    echo "3️⃣ OPEN LIBRARY"
    local ol_found=0
    for key in "${!book_data[@]}"; do
        if [[ $key == _o_* ]]; then
            ((ol_found++))
            local display_key=${key:3}
            local display_value="${book_data[$key]:0:60}"
            [ ${#book_data[$key]} -gt 60 ] && display_value="${display_value}..."
            echo "   ✓ $display_key: $display_value"
        fi
    done
    [ $ol_found -eq 0 ] && echo "   ✗ Aucune donnée"
    
    # CONSTRUCTION DE LA FICHE FINALE
    echo ""
    echo "🎯 FICHE FINALE AVEC MARTINGALE"
    echo "───────────────────────────────"
    
    # Titre et auteurs
    local title="${book_data[_best_title]:-${book_data[_g_title]:-${book_data[_i_title]:-${book_data[_o_title]:-}}}}"
    local subtitle="${book_data[_g_subtitle]:-${book_data[_o_subtitle]:-}}"
    local authors="${book_data[_best_authors]:-${book_data[_g_authors]:-${book_data[_i_authors]:-${book_data[_o_authors]:-}}}}"
    
    # Éditeur et dates
    local publisher="${book_data[_best_publisher]:-${book_data[_g_publisher]:-${book_data[_i_publisher]:-${book_data[_o_publishers]:-}}}}"
    local publish_date="${book_data[_g_publishedDate]:-${book_data[_i_date_published]:-${book_data[_o_publish_date]:-}}}"
    
    # Caractéristiques physiques
    local pages="${book_data[_best_pages]:-${book_data[_g_pageCount]:-${book_data[_i_pages]:-${book_data[_o_number_of_pages]:-0}}}}"
    local binding="${book_data[_best_binding]:-${book_data[_i_binding]:-${book_data[_o_physical_format]:-Broché}}}"
    local weight="${book_data[_calculated_weight]:-${book_data[_o_weight]:-}}"
    local dimensions="${book_data[_calculated_dimensions]:-${book_data[_i_dimensions]:-${book_data[_o_physical_dimensions]:-}}}"
    
    # Langue et catégories
    local language="${book_data[_best_language]:-${book_data[_g_language]:-${book_data[_i_language]:-fr}}}"
    local categories="${book_data[_all_categories]:-${book_data[_best_categories]:-${book_data[_g_categories]:-}}}"
    
    # Prix
    local price="${book_data[_calculated_msrp]:-${book_data[_best_msrp]:-${book_data[_i_msrp]:-${book_data[_g_listPrice]:-}}}}"
    
    # Description - Prendre la meilleure disponible
    local description=""
    if [ -n "${book_data[_best_description]}" ]; then
        # Nettoyer la description des logs Groq
        description=$(echo "${book_data[_best_description]}" | sed 's/\[2025-[^]]*\].*description générée //')
    elif [ -n "${book_data[_g_description]}" ]; then
        description="${book_data[_g_description]}"
    elif [ -n "${book_data[_i_synopsis]}" ] && [ "${book_data[_i_synopsis]}" != "Text: French" ]; then
        description="${book_data[_i_synopsis]}"
    elif [ -n "${book_data[_i_overview]}" ]; then
        description="${book_data[_i_overview]}"
    elif [ -n "${book_data[_o_description]}" ]; then
        description="${book_data[_o_description]}"
    elif [ -n "${book_data[_o_first_sentence]}" ]; then
        description="${book_data[_o_first_sentence]}"
    elif [ -n "${book_data[_groq_description]}" ]; then
        description=$(echo "${book_data[_groq_description]}" | sed 's/\[2025-[^]]*\].*description générée //')
    fi
    
    # IMAGES - Récupérer TOUTES les images disponibles
    echo ""
    echo "🖼️ IMAGES DISPONIBLES"
    echo "────────────────────"
    local best_image=""
    
    # Google Books images (du plus grand au plus petit)
    if [ -n "${book_data[_g_extraLarge]}" ]; then
        echo "   ✓ Google Extra Large: ${book_data[_g_extraLarge]}"
        best_image="${book_data[_g_extraLarge]}"
    fi
    if [ -n "${book_data[_g_large]}" ]; then
        echo "   ✓ Google Large: ${book_data[_g_large]}"
        [ -z "$best_image" ] && best_image="${book_data[_g_large]}"
    fi
    if [ -n "${book_data[_g_medium]}" ]; then
        echo "   ✓ Google Medium: ${book_data[_g_medium]}"
        [ -z "$best_image" ] && best_image="${book_data[_g_medium]}"
    fi
    if [ -n "${book_data[_g_small]}" ]; then
        echo "   ✓ Google Small: ${book_data[_g_small]}"
        [ -z "$best_image" ] && best_image="${book_data[_g_small]}"
    fi
    if [ -n "${book_data[_g_thumbnail]}" ]; then
        echo "   ✓ Google Thumbnail: ${book_data[_g_thumbnail]}"
        [ -z "$best_image" ] && best_image="${book_data[_g_thumbnail]}"
    fi
    if [ -n "${book_data[_g_smallThumbnail]}" ]; then
        echo "   ✓ Google Small Thumbnail: ${book_data[_g_smallThumbnail]}"
        [ -z "$best_image" ] && best_image="${book_data[_g_smallThumbnail]}"
    fi
    
    # ISBNdb image
    if [ -n "${book_data[_i_image]}" ]; then
        echo "   ✓ ISBNdb: ${book_data[_i_image]}"
        [ -z "$best_image" ] && best_image="${book_data[_i_image]}"
    fi
    
    # Open Library images
    if [ -n "${book_data[_o_cover_large]}" ]; then
        echo "   ✓ Open Library Large: ${book_data[_o_cover_large]}"
        [ -z "$best_image" ] && best_image="${book_data[_o_cover_large]}"
    fi
    if [ -n "${book_data[_o_cover_medium]}" ]; then
        echo "   ✓ Open Library Medium: ${book_data[_o_cover_medium]}"
        [ -z "$best_image" ] && best_image="${book_data[_o_cover_medium]}"
    fi
    if [ -n "${book_data[_o_cover_small]}" ]; then
        echo "   ✓ Open Library Small: ${book_data[_o_cover_small]}"
        [ -z "$best_image" ] && best_image="${book_data[_o_cover_small]}"
    fi
    
    # Image stockée comme meilleure
    if [ -n "${book_data[_best_cover_image]}" ]; then
        echo "   ✓ Meilleure image stockée: ${book_data[_best_cover_image]}"
        [ -z "$best_image" ] && best_image="${book_data[_best_cover_image]}"
    fi
    
    [ -z "$best_image" ] && echo "   ✗ AUCUNE IMAGE TROUVÉE"
    
    # Déterminer la catégorie Vinted
    local vinted_category=$(determine_vinted_category "$categories" "$title" "${book_data[_i_subjects]:-}")
    local vinted_id=$(echo "$vinted_category" | cut -d'|' -f1)
    local vinted_name=$(echo "$vinted_category" | cut -d'|' -f2)
    
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "📖 FICHE COMPLÈTE DU LIVRE"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "📚 INFORMATIONS PRINCIPALES"
    echo "──────────────────────────"
    echo "Titre         : $title"
    [ -n "$subtitle" ] && echo "Sous-titre    : $subtitle"
    echo "Auteur(s)     : ${authors:-Non renseigné}"
    echo "Éditeur       : ${publisher:-Non renseigné}"
    echo "Date          : ${publish_date:-Non renseignée}"
    echo ""
    
    echo "📏 CARACTÉRISTIQUES"
    echo "──────────────────"
    echo "Pages         : $pages"
    echo "Reliure       : $binding"
    echo "Dimensions    : ${dimensions:-Non renseignées}"
    echo "Poids         : ${weight:-Non renseigné}g"
    echo "Langue        : $language"
    echo ""
    
    echo "🏷️ IDENTIFIANTS"
    echo "───────────────"
    echo "ISBN          : $isbn"
    [ -n "${book_data[_g_isbn10]}" ] && echo "ISBN-10       : ${book_data[_g_isbn10]}"
    [ -n "${book_data[_g_isbn13]}" ] && echo "ISBN-13       : ${book_data[_g_isbn13]}"
    [ -n "${book_data[_calculated_ean]}" ] && echo "EAN calculé   : ${book_data[_calculated_ean]}"
    echo ""
    
    echo "💰 PRIX"
    echo "───────"
    echo "Prix conseillé: ${price:-Non renseigné}€"
    echo ""
    
    echo "📂 CATÉGORIES"
    echo "─────────────"
    echo "Catégories    : ${categories:-Non renseignées}"
    echo ""
    echo "Vinted ID     : $vinted_id"
    echo "Vinted Cat.   : $vinted_name"
    echo ""
    
    if [ -n "$best_image" ]; then
        echo "🖼️ MEILLEURE IMAGE"
        echo "─────────────────"
        echo "$best_image"
        echo ""
    fi
    
    echo "📝 DESCRIPTION"
    echo "─────────────"
    if [ -n "$description" ]; then
        echo "$description" | fold -w 70 -s
    else
        echo "⚠️ AUCUNE DESCRIPTION DISPONIBLE"
    fi
    echo ""
    
    # Points de vente Amazon
    if [ -n "${book_data[_calculated_bullet1]}" ]; then
        echo "📍 POINTS DE VENTE AMAZON"
        echo "────────────────────────"
        [ -n "${book_data[_calculated_bullet1]}" ] && echo "• ${book_data[_calculated_bullet1]}"
        [ -n "${book_data[_calculated_bullet2]}" ] && echo "• ${book_data[_calculated_bullet2]}"
        [ -n "${book_data[_calculated_bullet3]}" ] && echo "• ${book_data[_calculated_bullet3]}"
        [ -n "${book_data[_calculated_bullet4]}" ] && echo "• ${book_data[_calculated_bullet4]}"
        [ -n "${book_data[_calculated_bullet5]}" ] && echo "• ${book_data[_calculated_bullet5]}"
        echo ""
    fi
    
    # Données manquantes
    echo "⚠️ ANALYSE DES DONNÉES"
    echo "─────────────────────"
    local missing=0
    [ -z "$publish_date" ] && echo "❌ Date de publication manquante" && ((missing++))
    [ -z "$best_image" ] && echo "❌ Image de couverture manquante" && ((missing++))
    [ -z "$description" ] && echo "❌ Description manquante" && ((missing++))
    [ -z "${book_data[_g_isbn13]}" ] && [ -z "${book_data[_g_isbn10]}" ] && echo "❌ ISBN-10/13 manquant" && ((missing++))
    [ "$weight" = "${book_data[_calculated_weight]}" ] && echo "⚠️ Poids calculé (non réel)" && ((missing++))
    [ "$dimensions" = "${book_data[_calculated_dimensions]}" ] && echo "⚠️ Dimensions calculées (non réelles)" && ((missing++))
    [ $missing -eq 0 ] && echo "✅ Toutes les données importantes sont présentes !"
    
    # Statistiques de collecte
    echo ""
    echo "📊 STATISTIQUES"
    echo "──────────────"
    echo "Date collecte : ${book_data[_api_collect_date]:-Non renseignée}"
    echo "Appels API    : ${book_data[_api_calls_made]:-0}"
    echo "Version       : ${book_data[_api_collect_version]:-Non renseignée}"
    
    # Créer un fichier JSON complet
    local json_file="$SCRIPT_DIR/book_${isbn}_complete.json"
    cat > "$json_file" << EOF
{
    "isbn": "$isbn",
    "title": "$(echo "$title" | sed 's/"/\\"/g')",
    "subtitle": "$(echo "$subtitle" | sed 's/"/\\"/g')",
    "authors": "$(echo "$authors" | sed 's/"/\\"/g')",
    "publisher": "$(echo "$publisher" | sed 's/"/\\"/g')",
    "publishDate": "$publish_date",
    "pages": "$pages",
    "binding": "$binding",
    "dimensions": "$dimensions",
    "weight": "$weight",
    "language": "$language",
    "categories": "$(echo "$categories" | sed 's/"/\\"/g')",
    "vintedId": "$vinted_id",
    "vintedCategory": "$vinted_name",
    "price": "$price",
    "description": "$(echo "$description" | sed 's/"/\\"/g' | tr '\n' ' ')",
    "image": "$best_image",
    "images": {
        "googleExtraLarge": "${book_data[_g_extraLarge]:-}",
        "googleLarge": "${book_data[_g_large]:-}",
        "googleMedium": "${book_data[_g_medium]:-}",
        "googleSmall": "${book_data[_g_small]:-}",
        "googleThumbnail": "${book_data[_g_thumbnail]:-}",
        "isbndb": "${book_data[_i_image]:-}",
        "openLibraryLarge": "${book_data[_o_cover_large]:-}",
        "openLibraryMedium": "${book_data[_o_cover_medium]:-}"
    }
}
EOF
    
    echo ""
    echo "💾 Fichier JSON créé : $json_file"
}

# Menu principal
echo "Que voulez-vous faire ?"
echo "1) Afficher les fiches complètes des 3 livres de test"
echo "2) Afficher la fiche d'un livre spécifique"
echo "3) Récollecter les données manquantes"
echo ""
read -p "Votre choix (1-3) : " choice

case $choice in
    1)
        for isbn in "2040120815" "2850760854" "2901821030"; do
            product_id=$(mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key = '_isbn' AND meta_value = '$isbn' LIMIT 1;")
            
            if [ -n "$product_id" ]; then
                show_complete_book_data "$product_id" "$isbn"
                echo ""
                echo ""
            fi
        done
        ;;
    2)
        read -p "Entrez l'ISBN : " isbn
        product_id=$(mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "
            SELECT post_id FROM wp_${SITE_ID}_postmeta 
            WHERE meta_key = '_isbn' AND meta_value = '$isbn' LIMIT 1;")
        
        if [ -n "$product_id" ]; then
            show_complete_book_data "$product_id" "$isbn"
        else
            echo "Erreur : Aucun produit trouvé avec l'ISBN $isbn"
        fi
        ;;
    3)
        echo "Pour récollecter les données manquantes, lancez :"
        echo "./collect_api_data_final_v2.sh"
        ;;
esac
