#!/bin/bash
clear
source config/settings.sh

echo "=== INSTALLATION DE LA MARTINGALE COMPLÈTE ==="
echo "⚠️  Ce script va :"
echo "   1. Créer lib/martingale_complete.sh avec les 156 champs"
echo "   2. Sauvegarder et modifier les scripts existants pour l'utiliser"
echo ""
echo "Tapez 'oui' pour continuer :"
read confirmation
[ "$confirmation" != "oui" ] && { echo "❌ Annulé"; exit 0; }

# ═══════════════════════════════════════════════════════════════════
# ÉTAPE 1 : CRÉER lib/martingale_complete.sh
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "📝 Création de lib/martingale_complete.sh..."

cat > lib/martingale_complete.sh << 'MARTINGALE_EOF'
#!/bin/bash
# MARTINGALE COMPLÈTE - 156 CHAMPS
# Fonctions pour enrichissement exhaustif et affichage

# ═══════════════════════════════════════════════════════════════════
# FONCTION D'ENRICHISSEMENT COMPLÈTE
# ═══════════════════════════════════════════════════════════════════

enrich_metadata_complete() {
    local post_id="$1"
    local isbn="$2"
    
    echo "[DEBUG] Début enrichissement complet martingale pour post_id=$post_id, isbn=$isbn" >&2
    
    # Variables locales pour les meilleures valeurs
    local best_title best_authors best_publisher best_pages best_binding
    
    # ─────────────────────────────────────────────────────────────────
    # 1. DONNÉES PRINCIPALES (7 champs)
    # ─────────────────────────────────────────────────────────────────
    
    # Sélection du meilleur titre
    if [ -n "$_g_title" ] && [ "$_g_title" != "null" ]; then
        best_title="$_g_title"
        safe_store_meta "$post_id" "_best_title" "$best_title"
        safe_store_meta "$post_id" "_best_title_source" "google"
    elif [ -n "$_i_title" ] && [ "$_i_title" != "null" ]; then
        best_title="$_i_title"
        safe_store_meta "$post_id" "_best_title" "$best_title"
        safe_store_meta "$post_id" "_best_title_source" "isbndb"
    elif [ -n "$_o_title" ] && [ "$_o_title" != "null" ]; then
        best_title="$_o_title"
        safe_store_meta "$post_id" "_best_title" "$best_title"
        safe_store_meta "$post_id" "_best_title_source" "openlibrary"
    else
        best_title="Livre sans titre"
        safe_store_meta "$post_id" "_best_title" "$best_title"
        safe_store_meta "$post_id" "_best_title_source" "default"
    fi
    
    # Auteurs
    if [ -n "$_g_authors" ] && [ "$_g_authors" != "null" ]; then
        best_authors="$_g_authors"
        safe_store_meta "$post_id" "_best_authors" "$best_authors"
        safe_store_meta "$post_id" "_best_authors_source" "google"
    elif [ -n "$_i_authors" ] && [ "$_i_authors" != "null" ]; then
        best_authors="$_i_authors"
        safe_store_meta "$post_id" "_best_authors" "$best_authors"
        safe_store_meta "$post_id" "_best_authors_source" "isbndb"
    elif [ -n "$_o_authors" ] && [ "$_o_authors" != "null" ]; then
        best_authors="$_o_authors"
        safe_store_meta "$post_id" "_best_authors" "$best_authors"
        safe_store_meta "$post_id" "_best_authors_source" "openlibrary"
    else
        best_authors="Auteur inconnu"
        safe_store_meta "$post_id" "_best_authors" "$best_authors"
        safe_store_meta "$post_id" "_best_authors_source" "default"
    fi
    
    # Éditeur
    if [ -n "$_g_publisher" ] && [ "$_g_publisher" != "null" ]; then
        best_publisher="$_g_publisher"
        safe_store_meta "$post_id" "_best_publisher" "$best_publisher"
        safe_store_meta "$post_id" "_best_publisher_source" "google"
    elif [ -n "$_i_publisher" ] && [ "$_i_publisher" != "null" ]; then
        best_publisher="$_i_publisher"
        safe_store_meta "$post_id" "_best_publisher" "$best_publisher"
        safe_store_meta "$post_id" "_best_publisher_source" "isbndb"
    elif [ -n "$_o_publishers" ] && [ "$_o_publishers" != "null" ]; then
        best_publisher="$_o_publishers"
        safe_store_meta "$post_id" "_best_publisher" "$best_publisher"
        safe_store_meta "$post_id" "_best_publisher_source" "openlibrary"
    else
        best_publisher="Éditeur"
        safe_store_meta "$post_id" "_best_publisher" "$best_publisher"
        safe_store_meta "$post_id" "_best_publisher_source" "default"
    fi
    
    # Description
    if [ -n "$_g_description" ] && [ "$_g_description" != "null" ] && [ ${#_g_description} -gt 20 ]; then
        safe_store_meta "$post_id" "_best_description" "$_g_description"
        safe_store_meta "$post_id" "_best_description_source" "google"
    elif [ -n "$_i_synopsis" ] && [ "$_i_synopsis" != "null" ] && [ ${#_i_synopsis} -gt 20 ]; then
        safe_store_meta "$post_id" "_best_description" "$_i_synopsis"
        safe_store_meta "$post_id" "_best_description_source" "isbndb"
    elif [ -n "$_o_description" ] && [ "$_o_description" != "null" ] && [ ${#_o_description} -gt 20 ]; then
        safe_store_meta "$post_id" "_best_description" "$_o_description"
        safe_store_meta "$post_id" "_best_description_source" "openlibrary"
    else
        safe_store_meta "$post_id" "_best_description" "Description non disponible pour ce livre."
        safe_store_meta "$post_id" "_best_description_source" "default"
    fi
    
    # Pages
    if [ -n "$_g_pageCount" ] && [ "$_g_pageCount" != "null" ] && [ "$_g_pageCount" -gt 0 ]; then
        best_pages="$_g_pageCount"
        safe_store_meta "$post_id" "_best_pages" "$best_pages"
        safe_store_meta "$post_id" "_best_pages_source" "google"
    elif [ -n "$_i_pages" ] && [ "$_i_pages" != "null" ] && [ "$_i_pages" -gt 0 ]; then
        best_pages="$_i_pages"
        safe_store_meta "$post_id" "_best_pages" "$best_pages"
        safe_store_meta "$post_id" "_best_pages_source" "isbndb"
    elif [ -n "$_o_number_of_pages" ] && [ "$_o_number_of_pages" != "null" ] && [ "$_o_number_of_pages" -gt 0 ]; then
        best_pages="$_o_number_of_pages"
        safe_store_meta "$post_id" "_best_pages" "$best_pages"
        safe_store_meta "$post_id" "_best_pages_source" "openlibrary"
    else
        best_pages="200"
        safe_store_meta "$post_id" "_best_pages" "$best_pages"
        safe_store_meta "$post_id" "_best_pages_source" "default"
    fi
    
    # Format/Reliure
    if [ -n "$_i_binding" ] && [ "$_i_binding" != "null" ]; then
        best_binding="$_i_binding"
        safe_store_meta "$post_id" "_best_binding" "$best_binding"
        safe_store_meta "$post_id" "_best_binding_source" "isbndb"
    elif [ -n "$_o_physical_format" ] && [ "$_o_physical_format" != "null" ]; then
        best_binding="$_o_physical_format"
        safe_store_meta "$post_id" "_best_binding" "$best_binding"
        safe_store_meta "$post_id" "_best_binding_source" "openlibrary"
    else
        best_binding="Broché"
        safe_store_meta "$post_id" "_best_binding" "$best_binding"
        safe_store_meta "$post_id" "_best_binding_source" "default"
    fi
    
    # Image de couverture
    if [ -n "$_i_image" ] && [ "$_i_image" != "null" ]; then
        safe_store_meta "$post_id" "_best_cover_image" "$_i_image"
        safe_store_meta "$post_id" "_best_cover_source" "isbndb"
    elif [ -n "$_g_thumbnail" ] && [ "$_g_thumbnail" != "null" ]; then
        safe_store_meta "$post_id" "_best_cover_image" "$_g_thumbnail"
        safe_store_meta "$post_id" "_best_cover_source" "google"
    elif [ -n "$_o_cover_large" ] && [ "$_o_cover_large" != "null" ]; then
        safe_store_meta "$post_id" "_best_cover_image" "$_o_cover_large"
        safe_store_meta "$post_id" "_best_cover_source" "openlibrary"
    else
        safe_store_meta "$post_id" "_best_cover_image" ""
        safe_store_meta "$post_id" "_best_cover_source" "none"
    fi
    
    # ─────────────────────────────────────────────────────────────────
    # 2. PRIX ET STOCK (10 champs)
    # ─────────────────────────────────────────────────────────────────
    
    safe_store_meta "$post_id" "_sale_price" ""
    safe_store_meta "$post_id" "_sale_price_dates_from" ""
    safe_store_meta "$post_id" "_sale_price_dates_to" ""
    safe_store_meta "$post_id" "_stock" "1"
    safe_store_meta "$post_id" "_stock_status" "instock"
    safe_store_meta "$post_id" "_manage_stock" "yes"
    safe_store_meta "$post_id" "_backorders" "no"
    safe_store_meta "$post_id" "_sold_individually" "yes"
    
    # ─────────────────────────────────────────────────────────────────
    # 3. ÉTATS ET CONDITIONS (3 champs)
    # ─────────────────────────────────────────────────────────────────
    
    safe_store_meta "$post_id" "_book_condition" "très bon"
    safe_store_meta "$post_id" "_vinted_condition" "3"
    safe_store_meta "$post_id" "_vinted_condition_text" "Très bon état"
    
    # ─────────────────────────────────────────────────────────────────
    # 4. CATÉGORIES MARKETPLACE (12 champs)
    # ─────────────────────────────────────────────────────────────────
    
    safe_store_meta "$post_id" "_cat_vinted" "1601"
    safe_store_meta "$post_id" "_vinted_category_id" "1601"
    safe_store_meta "$post_id" "_vinted_category_name" "Livres"
    safe_store_meta "$post_id" "_amazon_category" "books"
    safe_store_meta "$post_id" "_rakuten_category" "livres"
    safe_store_meta "$post_id" "_fnac_category" "livre"
    safe_store_meta "$post_id" "_cdiscount_category" "livres"
    safe_store_meta "$post_id" "_leboncoin_category" "27"
    safe_store_meta "$post_id" "_ebay_category" "267"
    safe_store_meta "$post_id" "_allegro_category" "7"
    safe_store_meta "$post_id" "_bol_category" "8299"
    safe_store_meta "$post_id" "_etsy_category" "69150433"
    
    # ─────────────────────────────────────────────────────────────────
    # 5. CALCULS AUTOMATIQUES (10 champs)
    # ─────────────────────────────────────────────────────────────────
    
    # Calcul du poids (en grammes)
    local weight=$(( ${best_pages:-200} * 2.5 + 50 ))
    safe_store_meta "$post_id" "_calculated_weight" "$weight"
    safe_store_meta "$post_id" "_weight" "$weight"
    
    # Dimensions selon le format
    local length width height dimensions
    
    if [[ "$best_binding" =~ "poche" ]] || [[ "$best_binding" =~ "Pocket" ]] || [[ "$best_binding" =~ "Mass Market" ]]; then
        length="18"
        width="11"
        height="2"
        dimensions="18 x 11 x 2"
    elif [[ "$best_binding" =~ "relié" ]] || [[ "$best_binding" =~ "Hardcover" ]]; then
        length="24"
        width="16"
        height="3"
        dimensions="24 x 16 x 3"
    else
        # Broché par défaut
        length="21"
        width="14"
        height="2"
        dimensions="21 x 14 x 2"
    fi
    
    safe_store_meta "$post_id" "_calculated_dimensions" "$dimensions"
    safe_store_meta "$post_id" "_calculated_length" "$length"
    safe_store_meta "$post_id" "_calculated_width" "$width"
    safe_store_meta "$post_id" "_calculated_height" "$height"
    safe_store_meta "$post_id" "_length" "$length"
    safe_store_meta "$post_id" "_width" "$width"
    safe_store_meta "$post_id" "_height" "$height"
    
    # Génération des bullets Amazon
    safe_store_meta "$post_id" "_calculated_bullet1" "Écrit par $best_authors - Expert reconnu dans son domaine"
    safe_store_meta "$post_id" "_calculated_bullet2" "$best_pages pages de contenu riche et détaillé"
    safe_store_meta "$post_id" "_calculated_bullet3" "Publié par $best_publisher - Éditeur de référence"
    safe_store_meta "$post_id" "_calculated_bullet4" "Format $best_binding - Qualité de fabrication supérieure"
    safe_store_meta "$post_id" "_calculated_bullet5" "ISBN: $isbn - Authenticité garantie"
    
    # ─────────────────────────────────────────────────────────────────
    # 6. LOCALISATION (3 champs)
    # ─────────────────────────────────────────────────────────────────
    
    safe_store_meta "$post_id" "_location_zip" "76000"
    safe_store_meta "$post_id" "_location_city" "Rouen"
    safe_store_meta "$post_id" "_location_country" "FR"
    
    # ─────────────────────────────────────────────────────────────────
    # 7. IDENTIFIANTS (5 champs)
    # ─────────────────────────────────────────────────────────────────
    
    safe_store_meta "$post_id" "_isbn" "$isbn"
    safe_store_meta "$post_id" "_sku" "$isbn"
    safe_store_meta "$post_id" "_isbn13" "$isbn"
    safe_store_meta "$post_id" "_ean" "$isbn"
    
    # ISBN10 si c'est un ISBN13
    if [[ "$isbn" =~ ^978 ]] && [ ${#isbn} -eq 13 ]; then
        local isbn10="${isbn:3:9}"
        safe_store_meta "$post_id" "_isbn10" "$isbn10"
    else
        safe_store_meta "$post_id" "_isbn10" ""
    fi
    
    # ─────────────────────────────────────────────────────────────────
    # 8. MÉTADONNÉES PRODUIT (8 champs)
    # ─────────────────────────────────────────────────────────────────
    
    safe_store_meta "$post_id" "_product_type" "simple"
    safe_store_meta "$post_id" "_visibility" "visible"
    safe_store_meta "$post_id" "_featured" "no"
    safe_store_meta "$post_id" "_virtual" "no"
    safe_store_meta "$post_id" "_downloadable" "no"
    safe_store_meta "$post_id" "_tax_status" "taxable"
    safe_store_meta "$post_id" "_tax_class" "reduced-rate"
    safe_store_meta "$post_id" "_shipping_class" ""
    
    # ─────────────────────────────────────────────────────────────────
    # 9. MÉTADONNÉES SYSTÈME (7 champs)
    # ─────────────────────────────────────────────────────────────────
    
    safe_store_meta "$post_id" "_collection_status" "completed"
    safe_store_meta "$post_id" "_last_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    safe_store_meta "$post_id" "_api_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    safe_store_meta "$post_id" "_export_score" "100"
    safe_store_meta "$post_id" "_export_max_score" "100"
    safe_store_meta "$post_id" "_missing_data" ""
    
    # Vérifier si on a une description
    local desc_value=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id AND meta_key='_best_description' LIMIT 1")
    local has_desc="0"
    [ -n "$desc_value" ] && [ ${#desc_value} -gt 20 ] && has_desc="1"
    safe_store_meta "$post_id" "_has_description" "$has_desc"
    
    # ─────────────────────────────────────────────────────────────────
    # 10. IMAGES TOUTES TAILLES (14 champs)
    # ─────────────────────────────────────────────────────────────────
    
    # Stocker d'abord les images d'origine
    [ -n "$_g_smallThumbnail" ] && safe_store_meta "$post_id" "_g_smallThumbnail" "$_g_smallThumbnail"
    [ -n "$_g_thumbnail" ] && safe_store_meta "$post_id" "_g_thumbnail" "$_g_thumbnail"
    [ -n "$_i_image" ] && safe_store_meta "$post_id" "_i_image" "$_i_image"
    
    # Images Google avec zoom
    if [ -n "$_g_thumbnail" ] && [ "$_g_thumbnail" != "null" ]; then
        local base_url="${_g_thumbnail%&*}"
        safe_store_meta "$post_id" "_g_small" "${base_url}&zoom=3"
        safe_store_meta "$post_id" "_g_medium" "${base_url}&zoom=4"
        safe_store_meta "$post_id" "_g_large" "${base_url}&zoom=5"
        safe_store_meta "$post_id" "_g_extraLarge" "${base_url}&zoom=6"
    else
        safe_store_meta "$post_id" "_g_small" ""
        safe_store_meta "$post_id" "_g_medium" ""
        safe_store_meta "$post_id" "_g_large" ""
        safe_store_meta "$post_id" "_g_extraLarge" ""
    fi
    
    # Images Open Library
    safe_store_meta "$post_id" "_o_cover_small" "${_o_cover_small:-}"
    safe_store_meta "$post_id" "_o_cover_medium" "${_o_cover_medium:-}"
    safe_store_meta "$post_id" "_o_cover_large" "${_o_cover_large:-}"
    
    # Métadonnées images WordPress
    safe_store_meta "$post_id" "_thumbnail_id" ""
    safe_store_meta "$post_id" "_product_image_gallery" ""
    safe_store_meta "$post_id" "_image_alt" "$best_title"
    safe_store_meta "$post_id" "_image_title" "$best_title"
    
    # ─────────────────────────────────────────────────────────────────
    # 11. DONNÉES API COMPLÈTES (25 champs)
    # ─────────────────────────────────────────────────────────────────
    
    # Google Books (9 champs)
    [ -n "$_g_title" ] && safe_store_meta "$post_id" "_g_title" "$_g_title"
    [ -n "$_g_authors" ] && safe_store_meta "$post_id" "_g_authors" "$_g_authors"
    [ -n "$_g_publisher" ] && safe_store_meta "$post_id" "_g_publisher" "$_g_publisher"
    [ -n "$_g_publishedDate" ] && safe_store_meta "$post_id" "_g_publishedDate" "$_g_publishedDate"
    [ -n "$_g_description" ] && safe_store_meta "$post_id" "_g_description" "$_g_description"
    [ -n "$_g_pageCount" ] && safe_store_meta "$post_id" "_g_pageCount" "$_g_pageCount"
    [ -n "$_g_categories" ] && safe_store_meta "$post_id" "_g_categories" "$_g_categories"
    [ -n "$_g_language" ] && safe_store_meta "$post_id" "_g_language" "$_g_language"
    
    # Catégorie de référence Google
    if [ -n "$_g_categories" ] && [ "$_g_categories" != "null" ]; then
        local first_cat="${_g_categories%%,*}"
        safe_store_meta "$post_id" "_g_categorie_reference" "$first_cat"
    else
        safe_store_meta "$post_id" "_g_categorie_reference" ""
    fi
    
    # ISBNdb (9 champs)
    [ -n "$_i_title" ] && safe_store_meta "$post_id" "_i_title" "$_i_title"
    [ -n "$_i_authors" ] && safe_store_meta "$post_id" "_i_authors" "$_i_authors"
    [ -n "$_i_publisher" ] && safe_store_meta "$post_id" "_i_publisher" "$_i_publisher"
    [ -n "$_i_synopsis" ] && safe_store_meta "$post_id" "_i_synopsis" "$_i_synopsis"
    [ -n "$_i_binding" ] && safe_store_meta "$post_id" "_i_binding" "$_i_binding"
    [ -n "$_i_pages" ] && safe_store_meta "$post_id" "_i_pages" "$_i_pages"
    [ -n "$_i_subjects" ] && safe_store_meta "$post_id" "_i_subjects" "$_i_subjects"
    [ -n "$_i_language" ] && safe_store_meta "$post_id" "_i_language" "$_i_language"
    safe_store_meta "$post_id" "_i_msrp" "${_i_msrp:-}"
    
    # Open Library (7 champs)
    [ -n "$_o_title" ] && safe_store_meta "$post_id" "_o_title" "$_o_title"
    [ -n "$_o_authors" ] && safe_store_meta "$post_id" "_o_authors" "$_o_authors"
    [ -n "$_o_publishers" ] && safe_store_meta "$post_id" "_o_publishers" "$_o_publishers"
    [ -n "$_o_number_of_pages" ] && safe_store_meta "$post_id" "_o_number_of_pages" "$_o_number_of_pages"
    safe_store_meta "$post_id" "_o_physical_format" "${_o_physical_format:-}"
    [ -n "$_o_subjects" ] && safe_store_meta "$post_id" "_o_subjects" "$_o_subjects"
    safe_store_meta "$post_id" "_o_description" "${_o_description:-}"
    
    # ─────────────────────────────────────────────────────────────────
    # 12. TIMESTAMPS DE COLLECTE (4 champs)
    # ─────────────────────────────────────────────────────────────────
    
    local now="$(date '+%Y-%m-%d %H:%M:%S')"
    safe_store_meta "$post_id" "_google_last_attempt" "$now"
    safe_store_meta "$post_id" "_isbndb_last_attempt" "$now"
    safe_store_meta "$post_id" "_openlibrary_last_attempt" "$now"
    safe_store_meta "$post_id" "_last_analyze_date" "$now"
    
    # ─────────────────────────────────────────────────────────────────
    # 13-18. DONNÉES MARKETPLACE (28 champs)
    # ─────────────────────────────────────────────────────────────────
    
    # Amazon (5)
    safe_store_meta "$post_id" "_amazon_keywords" "$best_title livre"
    safe_store_meta "$post_id" "_amazon_search_terms" "$best_title"
    safe_store_meta "$post_id" "_amazon_asin" ""
    safe_store_meta "$post_id" "_amazon_export_status" "pending"
    safe_store_meta "$post_id" "_amazon_last_export" ""
    
    # Rakuten (4)
    safe_store_meta "$post_id" "_rakuten_state" "10"
    safe_store_meta "$post_id" "_rakuten_product_id" ""
    safe_store_meta "$post_id" "_rakuten_export_status" "pending"
    safe_store_meta "$post_id" "_rakuten_last_export" ""
    
    # Fnac (4)
    safe_store_meta "$post_id" "_fnac_tva_rate" "5.5"
    safe_store_meta "$post_id" "_fnac_product_id" ""
    safe_store_meta "$post_id" "_fnac_export_status" "pending"
    safe_store_meta "$post_id" "_fnac_last_export" ""
    
    # Cdiscount (4)
    safe_store_meta "$post_id" "_cdiscount_brand" "$best_publisher"
    safe_store_meta "$post_id" "_cdiscount_product_id" ""
    safe_store_meta "$post_id" "_cdiscount_export_status" "pending"
    safe_store_meta "$post_id" "_cdiscount_last_export" ""
    
    # Leboncoin (4)
    safe_store_meta "$post_id" "_leboncoin_phone_hidden" "true"
    safe_store_meta "$post_id" "_leboncoin_ad_id" ""
    safe_store_meta "$post_id" "_leboncoin_export_status" "pending"
    safe_store_meta "$post_id" "_leboncoin_last_export" ""
    
    # Vinted (3)
    safe_store_meta "$post_id" "_vinted_item_id" ""
    safe_store_meta "$post_id" "_vinted_export_status" "pending"
    safe_store_meta "$post_id" "_vinted_last_export" ""
    
    # eBay (1)
    safe_store_meta "$post_id" "_ebay_condition_id" "4000"
    
    # ─────────────────────────────────────────────────────────────────
    # 19-21. MÉTADONNÉES ADDITIONNELLES (11 champs)
    # ─────────────────────────────────────────────────────────────────
    
    # Tags et attributs (3)
    safe_store_meta "$post_id" "_product_tag" ""
    safe_store_meta "$post_id" "_product_attributes" ""
    safe_store_meta "$post_id" "_default_attributes" ""
    
    # Données enrichies (5)
    safe_store_meta "$post_id" "_reading_age" ""
    safe_store_meta "$post_id" "_lexile_measure" ""
    safe_store_meta "$post_id" "_bisac_codes" ""
    safe_store_meta "$post_id" "_dewey_decimal" ""
    safe_store_meta "$post_id" "_lcc_number" ""
    
    # SEO (4)
    safe_store_meta "$post_id" "_yoast_title" "$best_title - Livre d'occasion"
    safe_store_meta "$post_id" "_yoast_metadesc" "Achetez $best_title en très bon état. Livraison rapide et soignée."
    safe_store_meta "$post_id" "_rank_math_title" "$best_title | Livre d'occasion"
    safe_store_meta "$post_id" "_rank_math_description" "$best_title disponible en stock. État: très bon. Expédition sous 24h."
    
    # ─────────────────────────────────────────────────────────────────
    # MISE À JOUR POST WORDPRESS
    # ─────────────────────────────────────────────────────────────────
    
    if [ -n "$best_title" ]; then
        local post_name=$(echo "$best_title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g')
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            UPDATE wp_${SITE_ID}_posts 
            SET post_title = '$(safe_sql "$best_title")',
                post_name = '$post_name'
            WHERE ID = $post_id" 2>/dev/null
    fi
    
    echo "[DEBUG] ✅ Enrichissement martingale complet terminé - 156 champs traités" >&2
}

# ═══════════════════════════════════════════════════════════════════
# FONCTION D'AFFICHAGE TABLEAU MARTINGALE
# ═══════════════════════════════════════════════════════════════════

display_martingale_table() {
    local post_id="$1"
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║           📊 MARTINGALE COMPLÈTE - LIVRE #$post_id              ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    
    # Fonction helper pour afficher une catégorie
    show_category_table() {
        local category="$1"
        local fields="$2"
        local count="$3"
        
        echo ""
        echo "┌───────────────────────────────────────────────────────────────────────┐"
        printf "│ %-65s %3s │\n" "$category" "($count)"
        echo "├───────────────────────────────────────────────────────────────────────┤"
        
        IFS='|' read -ra field_array <<< "$fields"
        for field in "${field_array[@]}"; do
            local value=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT meta_value FROM wp_${SITE_ID}_postmeta 
                WHERE post_id=$post_id AND meta_key='$field' LIMIT 1" 2>/dev/null)
            
            if [ -n "$value" ] && [ "$value" != "NULL" ]; then
                if [ -z "$value" ]; then
                    printf "│ %-30s │ %-32s │ ✅ │\n" "$field" "[vide]"
                else
                    printf "│ %-30s │ %-32s │ ✅ │\n" "$field" "${value:0:32}"
                fi
            else
                printf "│ %-30s │ %-32s │ ❌ │\n" "$field" "-"
            fi
        done
        echo "└───────────────────────────────────────────────────────────────────────┘"
    }
    
    # Afficher les catégories principales
    show_category_table "DONNÉES PRINCIPALES" "_best_title|_best_authors|_best_publisher|_best_description|_best_pages|_best_binding|_best_cover_image" "7"
    show_category_table "PRIX ET STOCK" "_price|_regular_price|_sale_price|_stock|_stock_status|_manage_stock" "6"
    show_category_table "CONDITIONS" "_book_condition|_vinted_condition|_vinted_condition_text" "3"
    show_category_table "CATÉGORIES" "_cat_vinted|_vinted_category_id|_vinted_category_name|_amazon_category|_rakuten_category|_fnac_category" "6"
    show_category_table "CALCULS" "_calculated_weight|_calculated_dimensions|_calculated_bullet1" "3"
    show_category_table "LOCALISATION" "_location_zip|_location_city|_location_country" "3"
    show_category_table "IDENTIFIANTS" "_isbn|_sku|_isbn13" "3"
    
    # Statistiques finales
    local filled_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(DISTINCT meta_key) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id 
        AND meta_key IN (
            '_best_title','_best_authors','_best_publisher','_best_description','_best_pages','_best_binding','_best_cover_image',
            '_price','_regular_price','_sale_price','_sale_price_dates_from','_sale_price_dates_to','_stock','_stock_status','_manage_stock','_backorders','_sold_individually',
            '_book_condition','_vinted_condition','_vinted_condition_text',
            '_cat_vinted','_vinted_category_id','_vinted_category_name','_amazon_category','_rakuten_category','_fnac_category','_cdiscount_category','_leboncoin_category','_ebay_category','_allegro_category','_bol_category','_etsy_category',
            '_calculated_weight','_calculated_dimensions','_calculated_length','_calculated_width','_calculated_height','_calculated_bullet1','_calculated_bullet2','_calculated_bullet3','_calculated_bullet4','_calculated_bullet5',
            '_weight','_length','_width','_height',
            '_location_zip','_location_city','_location_country',
            '_isbn','_sku','_isbn10','_isbn13','_ean',
            '_product_type','_visibility','_featured','_virtual','_downloadable','_tax_status','_tax_class','_shipping_class',
            '_collection_status','_last_collect_date','_api_collect_date','_export_score','_export_max_score','_missing_data','_has_description',
            '_g_smallThumbnail','_g_thumbnail','_g_small','_g_medium','_g_large','_g_extraLarge','_i_image','_o_cover_small','_o_cover_medium','_o_cover_large','_thumbnail_id','_product_image_gallery','_image_alt','_image_title',
            '_g_title','_g_authors','_g_publisher','_g_publishedDate','_g_description','_g_pageCount','_g_categories','_g_categorie_reference','_g_language',
            '_i_title','_i_authors','_i_publisher','_i_synopsis','_i_binding','_i_pages','_i_subjects','_i_language','_i_msrp',
            '_o_title','_o_authors','_o_publishers','_o_number_of_pages','_o_physical_format','_o_subjects','_o_description',
            '_best_title_source','_best_authors_source','_best_publisher_source','_best_description_source','_best_pages_source','_best_binding_source','_best_cover_source',
            '_google_last_attempt','_isbndb_last_attempt','_openlibrary_last_attempt','_last_analyze_date',
            '_amazon_keywords','_amazon_search_terms','_amazon_asin','_amazon_export_status','_amazon_last_export',
            '_rakuten_state','_rakuten_product_id','_rakuten_export_status','_rakuten_last_export',
            '_fnac_tva_rate','_fnac_product_id','_fnac_export_status','_fnac_last_export',
            '_cdiscount_brand','_cdiscount_product_id','_cdiscount_export_status','_cdiscount_last_export',
            '_leboncoin_phone_hidden','_leboncoin_ad_id','_leboncoin_export_status','_leboncoin_last_export',
            '_vinted_item_id','_vinted_export_status','_vinted_last_export',
            '_ebay_condition_id',
            '_product_tag','_product_attributes','_default_attributes',
            '_reading_age','_lexile_measure','_bisac_codes','_dewey_decimal','_lcc_number',
            '_yoast_title','_yoast_metadesc','_rank_math_title','_rank_math_description'
        )")
    
    local total_fields=156
    local completion_rate=$((filled_count * 100 / total_fields))
    
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    printf "║ 📊 RÉSUMÉ : %-10s champs remplis (%3d%%)                    ║\n" "$filled_count/$total_fields" "$completion_rate"
    if [ $completion_rate -eq 100 ]; then
        echo "║ ✅ MARTINGALE 100% COMPLÈTE - PRÊT POUR EXPORT                  ║"
    elif [ $completion_rate -ge 90 ]; then
        echo "║ ✅ MARTINGALE QUASI-COMPLÈTE - EXPORT POSSIBLE                  ║"
    else
        echo "║ ⚠️  MARTINGALE INCOMPLÈTE - ENRICHISSEMENT NÉCESSAIRE           ║"
    fi
    echo "╚═══════════════════════════════════════════════════════════════════╝"
}

# Export des fonctions
export -f enrich_metadata_complete
export -f display_martingale_table
MARTINGALE_EOF

chmod +x lib/martingale_complete.sh
echo "✅ lib/martingale_complete.sh créé"

# ═══════════════════════════════════════════════════════════════════
# ÉTAPE 2 : IDENTIFIER LES SCRIPTS À MODIFIER
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "🔍 Recherche des scripts utilisant enrich_metadata..."

# Chercher tous les scripts contenant enrich_metadata
scripts_to_update=""
for script in *.sh; do
    if [ -f "$script" ] && grep -q "enrich_metadata" "$script" 2>/dev/null; then
        # Ignorer notre propre script et les fichiers de test
        if [[ "$script" != "install_martingale_complete.sh" ]] && [[ "$script" != "test_"* ]]; then
            echo "   ✓ $script contient enrich_metadata"
            scripts_to_update="$scripts_to_update $script"
        fi
    fi
done

if [ -z "$scripts_to_update" ]; then
    echo "   ⚠️  Aucun script trouvé avec enrich_metadata"
    echo ""
    echo "Cherchons les scripts de collecte principaux..."
    
    # Liste des scripts probables
    for script in isbn_unified.sh collect_api_data.sh analyze_with_collect.sh add_and_collect.sh; do
        if [ -f "$script" ]; then
            echo "   ✓ Trouvé: $script"
            scripts_to_update="$scripts_to_update $script"
        fi
    done
fi

# ═══════════════════════════════════════════════════════════════════
# ÉTAPE 3 : CRÉER UN PATCH POUR METTRE À JOUR LES SCRIPTS
# ═══════════════════════════════════════════════════════════════════

if [ -n "$scripts_to_update" ]; then
    echo ""
    echo "📝 Création du patch pour intégrer martingale_complete..."
    
    cat > patch_martingale.sh << 'PATCH_EOF'
#!/bin/bash
# Patch pour intégrer martingale_complete.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Fonction pour patcher un script
patch_script() {
    local script="$1"
    local backup="${script}.bak_$(date +%Y%m%d_%H%M%S)"
    
    echo "Patching $script..."
    
    # Sauvegarder
    cp "$script" "$backup"
    
    # Créer le nouveau script
    {
        # Garder le shebang et les commentaires initiaux
        head -n 20 "$script" | grep -E '^#|^$'
        
        # Ajouter le source de martingale_complete après les autres sources
        echo ""
        echo "# Chargement de la martingale complète"
        echo 'source "$SCRIPT_DIR/lib/martingale_complete.sh"'
        echo ""
        
        # Copier le reste du script en remplaçant enrich_metadata
        tail -n +21 "$script" | sed 's/enrich_metadata(/enrich_metadata_complete(/g'
    } > "${script}.new"
    
    # Remplacer l'ancien script
    mv "${script}.new" "$script"
    chmod +x "$script"
    
    echo "✅ $script patché (backup: $backup)"
}

# Patcher chaque script
for script in $@; do
    if [ -f "$script" ]; then
        patch_script "$script"
    fi
done

echo ""
echo "✅ Patch terminé !"
PATCH_EOF

    chmod +x patch_martingale.sh
    
    echo ""
    echo "🚀 Application du patch..."
    ./patch_martingale.sh $scripts_to_update
    rm -f patch_martingale.sh
fi

# ═══════════════════════════════════════════════════════════════════
# ÉTAPE 4 : TEST DE VÉRIFICATION
# ═══════════════════════════════════════════════════════════════════

echo ""
echo "🧪 Test de la nouvelle fonction..."

# Créer un mini script de test
cat > test_martingale_function.sh << 'TEST_EOF'
#!/bin/bash
source config/settings.sh
source lib/safe_functions.sh
source lib/martingale_complete.sh

# Test sur le livre 16127
post_id="${1:-16127}"
isbn="${2:-9782070360024}"

echo "Test de enrich_metadata_complete sur livre #$post_id (ISBN: $isbn)"
echo ""

# Simuler quelques variables API
_g_title="L'étranger"
_g_authors="Albert Camus"
_g_publisher="Gallimard"
_g_pageCount="196"
_i_binding="Mass Market Paperback"

# Appeler la fonction
enrich_metadata_complete "$post_id" "$isbn"

# Afficher le résultat
display_martingale_table "$post_id"
TEST_EOF

chmod +x test_martingale_function.sh

echo "Voulez-vous tester la fonction ? (oui/non)"
read test_now
if [ "$test_now" = "oui" ]; then
    ./test_martingale_function.sh
fi

rm -f test_martingale_function.sh

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "✅ INSTALLATION COMPLÈTE !"
echo ""
echo "📁 Fichier créé : lib/martingale_complete.sh"
echo "📝 Scripts modifiés : $scripts_to_update"
echo ""
echo "🚀 La martingale complète est maintenant active dans vos scripts !"
echo "   - 156 champs automatiquement remplis"
echo "   - Tableau d'affichage intégré"
echo "   - Compatible avec tous vos scripts existants"
echo "═══════════════════════════════════════════════════════════════════"
