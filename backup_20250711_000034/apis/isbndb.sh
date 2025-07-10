#!/bin/bash
# API ISBNdb - VERSION CORRIGÉE AVEC MESSAGES CLAIRS

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

fetch_isbndb() {
    local isbn=$1
    local product_id=$2
    
    # Vérifier que la clé API est configurée
    if [ -z "$ISBNDB_KEY" ]; then
        log "    ✗ ISBNdb : clé API non configurée"
        return 1
    fi
    
    sleep 0.5
    log "  → ISBNdb API..."
    
    # Appel à l'API avec la bonne URL et les bons headers
    local isbndb_response=$(curl -s --connect-timeout 10 --max-time 30 \
        -H "Authorization: $ISBNDB_KEY" \
        -H "Accept: application/json" \
        -H "Accept-Charset: UTF-8" \
        "https://api2.isbndb.com/book/$isbn")
    
    ((api_calls_isbndb++))
	# Marquer la tentative
    safe_store_meta "$product_id" "_isbndb_last_attempt" "$(date '+%Y-%m-%d %H:%M:%S')"
    export api_calls_isbndb
    
    # Vérifier la réponse
    if [ -z "$isbndb_response" ]; then
        log "    ✗ ISBNdb : API non accessible (timeout ou erreur réseau)"
        return 1
    fi
    
    # Vérifier les erreurs d'authentification
    if [[ "$isbndb_response" =~ "unauthorized" ]] || [[ "$isbndb_response" =~ "Invalid API" ]]; then
        log "    ✗ ISBNdb : erreur d'authentification (vérifiez la clé API)"
        return 1
    fi
    
    # Vérifier si c'est une erreur 404 ou pas de livre
    if [[ "$isbndb_response" =~ "not found" ]] || [[ "$isbndb_response" =~ "404" ]]; then
        log "    ✗ ISBNdb : aucune donnée pour cet ISBN"
        return 1
    fi
    
    # Vérifier la présence de la structure book
    if [[ ! "$isbndb_response" =~ '"book":' ]]; then
        log "    ✗ ISBNdb : réponse invalide (pas de données livre)"
        return 1
    fi
    
    # Extraction des données principales
    local i_title=$(extract_json_value "$isbndb_response" '.book.title')
    local i_authors=$(extract_json_array "$isbndb_response" '.book.authors[]?')
    local i_publisher=$(extract_json_value "$isbndb_response" '.book.publisher')
    local i_synopsis=$(extract_json_value "$isbndb_response" '.book.synopsis')
    local i_overview=$(extract_json_value "$isbndb_response" '.book.overview')
    local i_binding=$(extract_json_value "$isbndb_response" '.book.binding')
    local i_pages=$(extract_json_value "$isbndb_response" '.book.pages' "0")
    local i_subjects=$(extract_json_array "$isbndb_response" '.book.subjects[]?' ', ')
    local i_msrp=$(extract_json_value "$isbndb_response" '.book.msrp' "0")
    local i_language=$(extract_json_value "$isbndb_response" '.book.language')
    local i_date_published=$(extract_json_value "$isbndb_response" '.book.date_published')
    local i_isbn10=$(extract_json_value "$isbndb_response" '.book.isbn')
    local i_isbn13=$(extract_json_value "$isbndb_response" '.book.isbn13')
    local i_dimensions=$(extract_json_value "$isbndb_response" '.book.dimensions')
    local i_image=$(extract_json_value "$isbndb_response" '.book.image')
    
    # Log du succès avec l'info la plus utile (reliure)
    if [ -n "$i_binding" ] && [ "$i_binding" != "null" ]; then
        log "    ✓ ISBNdb : trouvé reliure '$i_binding'"
    elif [ -n "$i_title" ] && [ "$i_title" != "null" ]; then
        log "    ✓ ISBNdb : trouvé '$i_title'"
    else
        log "    ✓ ISBNdb : données partielles trouvées"
    fi
    
    # Stocker toutes les données
    [ -n "$i_title" ] && [ "$i_title" != "null" ] && safe_store_meta "$product_id" "_i_title" "$i_title"
    [ -n "$i_authors" ] && [ "$i_authors" != "null" ] && safe_store_meta "$product_id" "_i_authors" "$i_authors"
    [ -n "$i_publisher" ] && [ "$i_publisher" != "null" ] && safe_store_meta "$product_id" "_i_publisher" "$i_publisher"
    [ -n "$i_synopsis" ] && [ "$i_synopsis" != "null" ] && safe_store_meta "$product_id" "_i_synopsis" "$i_synopsis"
    [ -n "$i_overview" ] && [ "$i_overview" != "null" ] && safe_store_meta "$product_id" "_i_overview" "$i_overview"
    [ -n "$i_binding" ] && [ "$i_binding" != "null" ] && safe_store_meta "$product_id" "_i_binding" "$i_binding"
    [ -n "$i_pages" ] && [ "$i_pages" != "0" ] && [ "$i_pages" != "null" ] && safe_store_meta "$product_id" "_i_pages" "$i_pages"
    [ -n "$i_subjects" ] && [ "$i_subjects" != "null" ] && safe_store_meta "$product_id" "_i_subjects" "$i_subjects"
    [ -n "$i_msrp" ] && [ "$i_msrp" != "0" ] && [ "$i_msrp" != "0.00" ] && [ "$i_msrp" != "null" ] && safe_store_meta "$product_id" "_i_msrp" "$i_msrp"
    [ -n "$i_language" ] && [ "$i_language" != "null" ] && safe_store_meta "$product_id" "_i_language" "$i_language"
    [ -n "$i_date_published" ] && [ "$i_date_published" != "null" ] && safe_store_meta "$product_id" "_i_date_published" "$i_date_published"
    [ -n "$i_isbn10" ] && [ "$i_isbn10" != "null" ] && safe_store_meta "$product_id" "_i_isbn10" "$i_isbn10"
    [ -n "$i_isbn13" ] && [ "$i_isbn13" != "null" ] && safe_store_meta "$product_id" "_i_isbn13" "$i_isbn13"
    [ -n "$i_dimensions" ] && [ "$i_dimensions" != "null" ] && safe_store_meta "$product_id" "_i_dimensions" "$i_dimensions"
    [ -n "$i_image" ] && [ "$i_image" != "null" ] && safe_store_meta "$product_id" "_i_image" "$i_image"
    
    # Retourner les données importantes
    echo "title:$i_title|authors:$i_authors|publisher:$i_publisher|synopsis:$i_synopsis|binding:$i_binding|pages:$i_pages|subjects:$i_subjects|msrp:$i_msrp|language:$i_language"
    return 0
}