#!/bin/bash
echo "[START: google_books.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# API Google Books - VERSION CORRIGÉE AVEC TOUTES LES IMAGES

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"  # Fonctions sécurisées
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

fetch_google_books() {
    local isbn=$1
    local product_id=$2
    
    log "  → Google Books API..."
    
    local google_url="https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn"
    if [ -n "$GOOGLE_API_KEY" ]; then
        google_url="${google_url}&key=$GOOGLE_API_KEY"
    fi
    
    local google_response=$(curl -s --connect-timeout 10 --max-time 30 -H "Accept-Charset: UTF-8" "$google_url")
    ((api_calls_google++))
	# Marquer la tentative d'appel
    safe_store_meta "$product_id" "_google_last_attempt" "$(date '+%Y-%m-%d %H:%M:%S')"
    export api_calls_google
    
    if [ -n "$google_response" ] && [ "$google_response" != "null" ] && [[ "$google_response" == *"items"* ]]; then
        # Extraction des données principales
        local g_title=$(extract_json_value "$google_response" '.items[0].volumeInfo.title')
        local g_subtitle=$(extract_json_value "$google_response" '.items[0].volumeInfo.subtitle')
        local g_authors=$(extract_json_array "$google_response" '.items[0].volumeInfo.authors[]?')
        local g_publisher=$(extract_json_value "$google_response" '.items[0].volumeInfo.publisher')
        local g_publishedDate=$(extract_json_value "$google_response" '.items[0].volumeInfo.publishedDate')
        local g_description=$(extract_json_value "$google_response" '.items[0].volumeInfo.description')
        local g_pageCount=$(extract_json_value "$google_response" '.items[0].volumeInfo.pageCount' "0")
        local g_categories=$(extract_json_array "$google_response" '.items[0].volumeInfo.categories[]?' ', ')
        local g_language=$(extract_json_value "$google_response" '.items[0].volumeInfo.language' "fr")
        
        # EXTRACTION COMPLÈTE DES IMAGES
        local g_smallThumbnail=$(extract_json_value "$google_response" '.items[0].volumeInfo.imageLinks.smallThumbnail')
        local g_thumbnail=$(extract_json_value "$google_response" '.items[0].volumeInfo.imageLinks.thumbnail')
        local g_small=$(extract_json_value "$google_response" '.items[0].volumeInfo.imageLinks.small')
        local g_medium=$(extract_json_value "$google_response" '.items[0].volumeInfo.imageLinks.medium')
        local g_large=$(extract_json_value "$google_response" '.items[0].volumeInfo.imageLinks.large')
        local g_extraLarge=$(extract_json_value "$google_response" '.items[0].volumeInfo.imageLinks.extraLarge')
        
        # Identifiants supplémentaires
        local g_isbn10=$(extract_json_value "$google_response" '.items[0].volumeInfo.industryIdentifiers[]? | select(.type=="ISBN_10").identifier')
        local g_isbn13=$(extract_json_value "$google_response" '.items[0].volumeInfo.industryIdentifiers[]? | select(.type=="ISBN_13").identifier')
        
        # Dimensions physiques
        local g_height=$(extract_json_value "$google_response" '.items[0].volumeInfo.dimensions.height')
        local g_width=$(extract_json_value "$google_response" '.items[0].volumeInfo.dimensions.width')
        local g_thickness=$(extract_json_value "$google_response" '.items[0].volumeInfo.dimensions.thickness')
        
        # Autres métadonnées
        local g_printType=$(extract_json_value "$google_response" '.items[0].volumeInfo.printType')
        local g_averageRating=$(extract_json_value "$google_response" '.items[0].volumeInfo.averageRating' "0")
        local g_ratingsCount=$(extract_json_value "$google_response" '.items[0].volumeInfo.ratingsCount' "0")
        local g_previewLink=$(extract_json_value "$google_response" '.items[0].volumeInfo.previewLink')
        local g_infoLink=$(extract_json_value "$google_response" '.items[0].volumeInfo.infoLink')
        
        # Prix si disponible
        local g_listPrice=$(extract_json_value "$google_response" '.items[0].saleInfo.listPrice.amount' "0")
        local g_retailPrice=$(extract_json_value "$google_response" '.items[0].saleInfo.retailPrice.amount' "0")
        
        log "    ✓ Google Books : trouvé '$g_title'"
        
        # LOG DES IMAGES TROUVÉES
        local images_found=0
        [ -n "$g_smallThumbnail" ] && [ "$g_smallThumbnail" != "null" ] && ((images_found++))
        [ -n "$g_thumbnail" ] && [ "$g_thumbnail" != "null" ] && ((images_found++))
        [ -n "$g_small" ] && [ "$g_small" != "null" ] && ((images_found++))
        [ -n "$g_medium" ] && [ "$g_medium" != "null" ] && ((images_found++))
        [ -n "$g_large" ] && [ "$g_large" != "null" ] && ((images_found++))
        [ -n "$g_extraLarge" ] && [ "$g_extraLarge" != "null" ] && ((images_found++))
        
        if [ $images_found -gt 0 ]; then
            log "      → $images_found image(s) trouvée(s)"
        fi
        
        # Stocker toutes les données
        safe_store_meta "$product_id" "_g_title" "$g_title"
        [ -n "$g_subtitle" ] && safe_store_meta "$product_id" "_g_subtitle" "$g_subtitle"
        safe_store_meta "$product_id" "_g_authors" "$g_authors"
        safe_store_meta "$product_id" "_g_publisher" "$g_publisher"
        [ -n "$g_publishedDate" ] && safe_store_meta "$product_id" "_g_publishedDate" "$g_publishedDate"
        safe_store_meta "$product_id" "_g_description" "$g_description"
        safe_store_meta "$product_id" "_g_pageCount" "$g_pageCount"
        safe_store_meta "$product_id" "_g_categories" "$g_categories"
        safe_store_meta "$product_id" "_g_language" "$g_language"
        
        # Stocker TOUTES les images disponibles
        [ -n "$g_smallThumbnail" ] && [ "$g_smallThumbnail" != "null" ] && safe_store_meta "$product_id" "_g_smallThumbnail" "$g_smallThumbnail"
        [ -n "$g_thumbnail" ] && [ "$g_thumbnail" != "null" ] && safe_store_meta "$product_id" "_g_thumbnail" "$g_thumbnail"
        [ -n "$g_small" ] && [ "$g_small" != "null" ] && safe_store_meta "$product_id" "_g_small" "$g_small"
        [ -n "$g_medium" ] && [ "$g_medium" != "null" ] && safe_store_meta "$product_id" "_g_medium" "$g_medium"
        [ -n "$g_large" ] && [ "$g_large" != "null" ] && safe_store_meta "$product_id" "_g_large" "$g_large"
        [ -n "$g_extraLarge" ] && [ "$g_extraLarge" != "null" ] && safe_store_meta "$product_id" "_g_extraLarge" "$g_extraLarge"
        
        # Identifiants
        [ -n "$g_isbn10" ] && safe_store_meta "$product_id" "_g_isbn10" "$g_isbn10"
        [ -n "$g_isbn13" ] && safe_store_meta "$product_id" "_g_isbn13" "$g_isbn13"
        
        # Dimensions
        [ -n "$g_height" ] && safe_store_meta "$product_id" "_g_height" "$g_height"
        [ -n "$g_width" ] && safe_store_meta "$product_id" "_g_width" "$g_width"
        [ -n "$g_thickness" ] && safe_store_meta "$product_id" "_g_thickness" "$g_thickness"
        
        # Autres métadonnées
        [ -n "$g_printType" ] && safe_store_meta "$product_id" "_g_printType" "$g_printType"
        [ "$g_averageRating" != "0" ] && safe_store_meta "$product_id" "_g_averageRating" "$g_averageRating"
        [ "$g_ratingsCount" != "0" ] && safe_store_meta "$product_id" "_g_ratingsCount" "$g_ratingsCount"
        [ -n "$g_previewLink" ] && safe_store_meta "$product_id" "_g_previewLink" "$g_previewLink"
        [ -n "$g_infoLink" ] && safe_store_meta "$product_id" "_g_infoLink" "$g_infoLink"
        
        # Prix
        [ "$g_listPrice" != "0" ] && safe_store_meta "$product_id" "_g_listPrice" "$g_listPrice"
        [ "$g_retailPrice" != "0" ] && safe_store_meta "$product_id" "_g_retailPrice" "$g_retailPrice"
        
        # Retourner les données importantes
        echo "title:$g_title|authors:$g_authors|publisher:$g_publisher|description:$g_description|pages:$g_pageCount|language:$g_language|categories:$g_categories|images:$images_found"
        return 0
    else
        log "    ✗ Google Books : pas de résultat"
        return 1
    fi
}

echo "[END: google_books.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
