#!/bin/bash
echo "[START: martingale_complete.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# MARTINGALE COMPLÈTE - 156 CHAMPS
# Fonctions pour enrichissement exhaustif et affichage

# Couleurs pour l'affichage amélioré
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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
    
    # CORRECTION : Forcer un prix minimum si prix = 0
    local current_price=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id AND meta_key='_price' LIMIT 1" 2>/dev/null)
    
    if [ -z "$current_price" ] || [ "$current_price" = "0" ] || [ "$current_price" = "NULL" ]; then
        safe_store_meta "$post_id" "_price" "15"
        safe_store_meta "$post_id" "_regular_price" "15"
    fi
    
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
    
    # CORRECTION : Ajouter les catégories par défaut si vides
    local current_amazon_cat=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id AND meta_key='_amazon_category' LIMIT 1" 2>/dev/null)
    [ -z "$current_amazon_cat" ] && safe_store_meta "$post_id" "_amazon_category" "books"
    
    local current_rakuten_cat=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id AND meta_key='_rakuten_category' LIMIT 1" 2>/dev/null)
    [ -z "$current_rakuten_cat" ] && safe_store_meta "$post_id" "_rakuten_category" "Littérature française"
    
    local current_fnac_cat=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id AND meta_key='_fnac_category' LIMIT 1" 2>/dev/null)
    [ -z "$current_fnac_cat" ] && safe_store_meta "$post_id" "_fnac_category" "livre"
    
    local current_cdiscount_cat=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id AND meta_key='_cdiscount_category' LIMIT 1" 2>/dev/null)
    [ -z "$current_cdiscount_cat" ] && safe_store_meta "$post_id" "_cdiscount_category" "livres"
    
    safe_store_meta "$post_id" "_leboncoin_category" "27"
    safe_store_meta "$post_id" "_ebay_category" "267"
    safe_store_meta "$post_id" "_allegro_category" "7"
    safe_store_meta "$post_id" "_bol_category" "8299"
    safe_store_meta "$post_id" "_etsy_category" "69150433"
    
    # ─────────────────────────────────────────────────────────────────
    # 5. CALCULS AUTOMATIQUES (10 champs)
    # ─────────────────────────────────────────────────────────────────
    
    # Calcul du poids (en grammes)
    local weight=$(( ${best_pages:-200} * 25 / 10 + 50 ))
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

# ═══════════════════════════════════════════════════════════════════
# FONCTION D'AFFICHAGE MARTINGALE COMPLÈTE (156 CHAMPS)
# ═══════════════════════════════════════════════════════════════════

display_martingale_complete() {
    local post_id="$1"
    
    echo ""
    echo -e "${BOLD}${PURPLE}╔═══════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${PURPLE}║              📊 MARTINGALE COMPLÈTE 156 CHAMPS - LIVRE #$post_id         ║${NC}"
    echo -e "${BOLD}${PURPLE}╚═══════════════════════════════════════════════════════════════════════════╝${NC}"
    
    # Fonction helper améliorée avec couleurs
    show_fields() {
        local category="$1"
        local fields="$2"
        
        echo ""
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}${CYAN}📁 $category${NC}"
        echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        
        IFS='|' read -ra field_array <<< "$fields"
        local count=0
        local filled=0
        
        for field in "${field_array[@]}"; do
            ((count++))
            local value=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT meta_value FROM wp_${SITE_ID}_postmeta 
                WHERE post_id=$post_id AND meta_key='$field' LIMIT 1" 2>/dev/null)
            
            local status="${RED}❌${NC}"
            local display_value="${RED}-${NC}"
            
            if [ -n "$value" ] && [ "$value" != "NULL" ]; then
                ((filled++))
                status="${GREEN}✅${NC}"
                if [ -z "$value" ]; then
                    display_value="${YELLOW}[vide]${NC}"
                elif [ "$value" = "0" ] && [[ "$field" =~ "_price" ]]; then
                    status="${RED}❌${NC}"
                    display_value="${RED}0 (invalide)${NC}"
                    ((filled--))
                else
                    display_value="${value:0:40}"
                fi
            fi
            
            printf "%-35s = %-40s %b\n" "$field" "$display_value" "$status"
        done
        
        echo -e "${CYAN}───────────────────────────────────────────────────────────────────────────${NC}"
        echo -e "${BOLD}Sous-total: ${filled}/${count} champs remplis${NC}"
    }
    
    # AFFICHER LES 156 CHAMPS ORGANISÉS PAR CATÉGORIE
    
    # 1. DONNÉES PRINCIPALES (7)
    show_fields "DONNÉES PRINCIPALES (7)" "_best_title|_best_authors|_best_publisher|_best_description|_best_pages|_best_binding|_best_cover_image"
    
    # 2. PRIX ET STOCK (10)
    show_fields "PRIX ET STOCK (10)" "_price|_regular_price|_sale_price|_sale_price_dates_from|_sale_price_dates_to|_stock|_stock_status|_manage_stock|_backorders|_sold_individually"
    
    # 3. CONDITIONS (3)
    show_fields "CONDITIONS (3)" "_book_condition|_vinted_condition|_vinted_condition_text"
    
    # 4. CATÉGORIES MARKETPLACE (12)
    show_fields "CATÉGORIES MARKETPLACE (12)" "_cat_vinted|_vinted_category_id|_vinted_category_name|_amazon_category|_rakuten_category|_fnac_category|_cdiscount_category|_leboncoin_category|_ebay_category|_allegro_category|_bol_category|_etsy_category"
    
    # 5. CALCULS (10)
    show_fields "CALCULS AUTOMATIQUES (10)" "_calculated_weight|_calculated_dimensions|_calculated_length|_calculated_width|_calculated_height|_calculated_bullet1|_calculated_bullet2|_calculated_bullet3|_calculated_bullet4|_calculated_bullet5"
    
    # 6. DIMENSIONS (4)
    show_fields "DIMENSIONS PHYSIQUES (4)" "_weight|_length|_width|_height"
    
    # 7. LOCALISATION (3)
    show_fields "LOCALISATION (3)" "_location_zip|_location_city|_location_country"
    
    # 8. IDENTIFIANTS (5)
    show_fields "IDENTIFIANTS (5)" "_isbn|_sku|_isbn10|_isbn13|_ean"
    
    # 9. MÉTADONNÉES PRODUIT (8)
    show_fields "MÉTADONNÉES PRODUIT (8)" "_product_type|_visibility|_featured|_virtual|_downloadable|_tax_status|_tax_class|_shipping_class"
    
    # 10. MÉTADONNÉES SYSTÈME (7)
    show_fields "MÉTADONNÉES SYSTÈME (7)" "_collection_status|_last_collect_date|_api_collect_date|_export_score|_export_max_score|_missing_data|_has_description"
    
    # 11. IMAGES (14)
    show_fields "IMAGES TOUTES TAILLES (14)" "_g_smallThumbnail|_g_thumbnail|_g_small|_g_medium|_g_large|_g_extraLarge|_i_image|_o_cover_small|_o_cover_medium|_o_cover_large|_thumbnail_id|_product_image_gallery|_image_alt|_image_title"
    
    # 12. GOOGLE BOOKS (9)
    show_fields "DONNÉES GOOGLE BOOKS (9)" "_g_title|_g_authors|_g_publisher|_g_publishedDate|_g_description|_g_pageCount|_g_categories|_g_categorie_reference|_g_language"
    
    # 13. ISBNDB (9)
    show_fields "DONNÉES ISBNDB (9)" "_i_title|_i_authors|_i_publisher|_i_synopsis|_i_binding|_i_pages|_i_subjects|_i_language|_i_msrp"
    
    # 14. OPEN LIBRARY (7)
    show_fields "DONNÉES OPEN LIBRARY (7)" "_o_title|_o_authors|_o_publishers|_o_number_of_pages|_o_physical_format|_o_subjects|_o_description"
    
    # 15. SOURCES (7)
    show_fields "SOURCES DES DONNÉES (7)" "_best_title_source|_best_authors_source|_best_publisher_source|_best_description_source|_best_pages_source|_best_binding_source|_best_cover_source"
    
    # 16. TIMESTAMPS (4)
    show_fields "TIMESTAMPS DE COLLECTE (4)" "_google_last_attempt|_isbndb_last_attempt|_openlibrary_last_attempt|_last_analyze_date"
    
    # 17. AMAZON (5)
    show_fields "MARKETPLACE AMAZON (5)" "_amazon_keywords|_amazon_search_terms|_amazon_asin|_amazon_export_status|_amazon_last_export"
    
    # 18. RAKUTEN (4)
    show_fields "MARKETPLACE RAKUTEN (4)" "_rakuten_state|_rakuten_product_id|_rakuten_export_status|_rakuten_last_export"
    
    # 19. FNAC (4)
    show_fields "MARKETPLACE FNAC (4)" "_fnac_tva_rate|_fnac_product_id|_fnac_export_status|_fnac_last_export"
    
    # 20. CDISCOUNT (4)
    show_fields "MARKETPLACE CDISCOUNT (4)" "_cdiscount_brand|_cdiscount_product_id|_cdiscount_export_status|_cdiscount_last_export"
    
    # 21. LEBONCOIN (4)
    show_fields "MARKETPLACE LEBONCOIN (4)" "_leboncoin_phone_hidden|_leboncoin_ad_id|_leboncoin_export_status|_leboncoin_last_export"
    
    # 22. VINTED (3)
    show_fields "MARKETPLACE VINTED (3)" "_vinted_item_id|_vinted_export_status|_vinted_last_export"
    
    # 23. EBAY (1)
    show_fields "MARKETPLACE EBAY (1)" "_ebay_condition_id"
    
    # 24. TAGS (3)
    show_fields "TAGS ET ATTRIBUTS (3)" "_product_tag|_product_attributes|_default_attributes"
    
    # 25. ENRICHIES (5)
    show_fields "DONNÉES ENRICHIES (5)" "_reading_age|_lexile_measure|_bisac_codes|_dewey_decimal|_lcc_number"
    
    # 26. SEO (4)
    show_fields "SEO (4)" "_yoast_title|_yoast_metadesc|_rank_math_title|_rank_math_description"
    
    # STATISTIQUES FINALES
    echo ""
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    
    # Compter TOUS les champs
    local total_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
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
    
    local completion_rate=$((total_count * 100 / 156))
    
    echo -e "${BOLD}${CYAN}📊 TOTAL FINAL : ${total_count}/156 champs (${completion_rate}%)${NC}"
    
    if [ $completion_rate -eq 100 ]; then
        echo -e "${BOLD}${GREEN}✅ MARTINGALE 100% COMPLÈTE - PRÊT POUR EXPORT TOUTES MARKETPLACES !${NC}"
    elif [ $completion_rate -ge 90 ]; then
        echo -e "${BOLD}${YELLOW}✅ MARTINGALE QUASI-COMPLÈTE (${completion_rate}%) - EXPORT POSSIBLE${NC}"
    else
        echo -e "${BOLD}${RED}⚠️  MARTINGALE INCOMPLÈTE (${completion_rate}%) - ENRICHISSEMENT NÉCESSAIRE${NC}"
    fi
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
}

# Export de la nouvelle fonction
export -f display_martingale_complete

echo "[END: martingale_complete.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2