#!/bin/bash
# ================================================
# COLLECTE DES DONNÉES VIA APIs - VERSION FINALE V2
# Utilise des fichiers pour stocker les compteurs
# ================================================

# Obtenir le répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger la configuration
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"  # Fonctions sécurisées

# Répertoire pour les compteurs
COUNTER_DIR="$SCRIPT_DIR/counters"
mkdir -p "$COUNTER_DIR"

# Initialiser les fichiers de compteurs
echo "0" > "$COUNTER_DIR/google"
echo "0" > "$COUNTER_DIR/isbndb"
echo "0" > "$COUNTER_DIR/ol"
echo "0" > "$COUNTER_DIR/gallica"
echo "0" > "$COUNTER_DIR/other"
echo "0" > "$COUNTER_DIR/groq"
echo "0" > "$COUNTER_DIR/processed"
echo "0" > "$COUNTER_DIR/enriched"
echo "0" > "$COUNTER_DIR/errors"

# Fonctions pour gérer les compteurs
increment_counter() {
    local counter_name=$1
    local current=$(cat "$COUNTER_DIR/$counter_name" 2>/dev/null || echo "0")
    echo $((current + 1)) > "$COUNTER_DIR/$counter_name"
}

get_counter() {
    local counter_name=$1
    cat "$COUNTER_DIR/$counter_name" 2>/dev/null || echo "0"
}

# Charger les librairies
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"
source "$SCRIPT_DIR/lib/enrichment.sh"
source "$SCRIPT_DIR/lib/best_data.sh"

# Créer le répertoire de logs si nécessaire
mkdir -p "$LOG_DIR"

# Modifier temporairement les fonctions API pour incrémenter les compteurs
original_fetch_google_books=$(declare -f fetch_google_books)
original_fetch_isbndb=$(declare -f fetch_isbndb)
original_fetch_open_library=$(declare -f fetch_open_library)

# Fonction principale de collecte
collect_book_data() {
    local product_id=$1
    local isbn=$2
    local current_price=$3
    
    log "Collecte données pour produit #$product_id - ISBN: $isbn"
    
    # Marquer comme en cours
    safe_store_meta "$product_id" "_api_collect_status" "processing"
    
    # Variables pour stocker les résultats des APIs
    local google_data=""
    local isbndb_data=""
    local openlibrary_data=""
    
    # Tableaux pour stocker les descriptions
    local descriptions=()
    
    # === 1. GOOGLE BOOKS API ===
    if [ -f "$SCRIPT_DIR/apis/google_books.sh" ]; then
        source "$SCRIPT_DIR/apis/google_books.sh"
        if google_data=$(fetch_google_books "$isbn" "$product_id"); then
            increment_counter "google"
            
            # Parser les données Google
            local g_title=$(parse_api_data "$google_data" "title")
            local g_authors=$(parse_api_data "$google_data" "authors")
            local g_description=$(parse_api_data "$google_data" "description")
            local g_pages=$(parse_api_data "$google_data" "pages")
            local g_language=$(parse_api_data "$google_data" "language")
            local g_categories=$(parse_api_data "$google_data" "categories")
            local g_publisher=$(parse_api_data "$google_data" "publisher")
            
            if [ -n "$g_description" ] && [ "$g_description" != "null" ]; then
                descriptions+=("$g_description|google")
            fi
        fi
    fi
    
    # === 2. ISBNDB API ===
    if [ -f "$SCRIPT_DIR/apis/isbndb.sh" ]; then
        source "$SCRIPT_DIR/apis/isbndb.sh"
        if isbndb_data=$(fetch_isbndb "$isbn" "$product_id"); then
            increment_counter "isbndb"
            
            # Parser les données ISBNdb
            local i_title=$(parse_api_data "$isbndb_data" "title")
            local i_authors=$(parse_api_data "$isbndb_data" "authors")
            local i_synopsis=$(parse_api_data "$isbndb_data" "synopsis")
            local i_binding=$(parse_api_data "$isbndb_data" "binding")
            local i_pages=$(parse_api_data "$isbndb_data" "pages")
            local i_subjects=$(parse_api_data "$isbndb_data" "subjects")
            local i_msrp=$(parse_api_data "$isbndb_data" "msrp")
            local i_publisher=$(parse_api_data "$isbndb_data" "publisher")
            local i_language=$(parse_api_data "$isbndb_data" "language")
            
            if [ -n "$i_synopsis" ] && [ "$i_synopsis" != "null" ]; then
                descriptions+=("$i_synopsis|isbndb")
            fi
        fi
    fi
    
    # === 3. OPEN LIBRARY API ===
    if [ -f "$SCRIPT_DIR/apis/open_library.sh" ]; then
        source "$SCRIPT_DIR/apis/open_library.sh"
        if openlibrary_data=$(fetch_open_library "$isbn" "$product_id"); then
            increment_counter "ol"
            
            # Parser les données Open Library
            local o_title=$(parse_api_data "$openlibrary_data" "title")
            local o_authors=$(parse_api_data "$openlibrary_data" "authors")
            local o_description=$(parse_api_data "$openlibrary_data" "description")
            local o_pages=$(parse_api_data "$openlibrary_data" "pages")
            local o_format=$(parse_api_data "$openlibrary_data" "format")
            local o_subjects=$(parse_api_data "$openlibrary_data" "subjects")
            local o_publisher=$(parse_api_data "$openlibrary_data" "publisher")
            
            if [ -n "$o_description" ] && [ "$o_description" != "null" ] && [ ${#o_description} -gt 30 ]; then
                descriptions+=("$o_description|openlibrary")
            fi
        fi
    fi
    
    # Récupérer les meilleures données disponibles
    local final_title="${g_title:-${i_title:-${o_title:-}}}"
    local final_authors="${g_authors:-${i_authors:-${o_authors:-}}}"
    local final_publisher="${g_publisher:-${i_publisher:-${o_publisher:-}}}"
    local final_pages="${g_pages:-${i_pages:-${o_pages:-0}}}"
    local final_binding="${i_binding:-${o_format:-Broché}}"
    local final_language="${g_language:-${i_language:-fr}}"
    
    # === 4. APIS SECONDAIRES SI PAS DE DESCRIPTION ===
    if [ ${#descriptions[@]} -eq 0 ]; then
        # Charger les APIs secondaires si elles existent
        if [ -f "$SCRIPT_DIR/apis/other_apis.sh" ]; then
            source "$SCRIPT_DIR/apis/other_apis.sh"
            
            # Gallica (pour les livres français)
            if [[ "$final_language" == "fr" ]]; then
                if type fetch_gallica &>/dev/null; then
                    if gallica_data=$(fetch_gallica "$isbn" "$product_id" "$final_language"); then
                        increment_counter "gallica"
                        local ga_desc=$(parse_api_data "$gallica_data" "description")
                        [ -n "$ga_desc" ] && [ "$ga_desc" != "null" ] && descriptions+=("$ga_desc|gallica")
                    fi
                fi
            fi
        fi
    fi
    
    # === 5. GROQ IA - EN DERNIER RECOURS ===
    local best_description=""
    if ! best_description=$(select_best_description "$product_id" "${descriptions[@]}"); then
        if [ -f "$SCRIPT_DIR/apis/groq_ai.sh" ]; then
            source "$SCRIPT_DIR/apis/groq_ai.sh"
            if type generate_description_groq &>/dev/null; then
                if groq_desc=$(generate_description_groq "$isbn" "$product_id" "$final_title" "$final_authors" "$final_publisher" "$final_pages" "$final_binding" "${g_categories:-}"); then
                    increment_counter "groq"
                    best_description="$groq_desc"
                    store_best_data "$product_id" "description" "$best_description" "groq_ai"
                    safe_store_meta "$product_id" "_has_description" "1"
                fi
            fi
        fi
    fi
    
    # === CALCULS ET ENRICHISSEMENTS ===
    
    # Calculer le poids
    if [ "$final_pages" -gt 0 ]; then
        local calculated_weight=$(calculate_weight "$final_pages")
        safe_store_meta "$product_id" "_calculated_weight" "$calculated_weight"
        log "      → Poids calculé : ${calculated_weight}g"
    fi
    
    # Calculer les dimensions
    local dimensions=$(calculate_dimensions "$final_binding")
    safe_store_meta "$product_id" "_calculated_dimensions" "$dimensions"
    
    # Générer les bullet points
    generate_bullet_points "$product_id" "$final_authors" "$final_pages" "$final_publisher" "$final_binding" "$isbn"
    
    # Stocker les meilleures données
    if [ -n "$final_title" ]; then
        store_best_data "$product_id" "title" "$final_title" \
            "$([ -n "$g_title" ] && echo "google" || ([ -n "$i_title" ] && echo "isbndb" || echo "openlibrary"))"
    fi
    
    if [ -n "$final_authors" ]; then
        store_best_data "$product_id" "authors" "$final_authors" \
            "$([ -n "$g_authors" ] && echo "google" || ([ -n "$i_authors" ] && echo "isbndb" || echo "openlibrary"))"
    fi
    
    if [ -n "$final_pages" ] && [ "$final_pages" != "0" ]; then
        store_best_data "$product_id" "pages" "$final_pages" \
            "$([ "$final_pages" = "$g_pages" ] && echo "google" || ([ "$final_pages" = "$i_pages" ] && echo "isbndb" || echo "openlibrary"))"
    fi
    
    # Métadonnées de collecte
    safe_store_meta "$product_id" "_api_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    safe_store_meta "$product_id" "_api_collect_status" "completed"
    safe_store_meta "$product_id" "_api_collect_version" "v2_with_counters"
    
    # Calculer le total d'appels
    local total_calls=$(($(get_counter "google") + $(get_counter "isbndb") + $(get_counter "ol") + $(get_counter "gallica") + $(get_counter "other") + $(get_counter "groq")))
    safe_store_meta "$product_id" "_api_calls_made" "$total_calls"
    
    increment_counter "enriched"
    log "  ✓ Enrichissement terminé avec succès"
    log "      → Appels API : Google=$(get_counter "google"), ISBNdb=$(get_counter "isbndb"), OL=$(get_counter "ol"), Groq=$(get_counter "groq")"
}

# === PROGRAMME PRINCIPAL ===

log "========================================="
log "DÉBUT COLLECTE DE DONNÉES VIA APIs V2"
log "========================================="
log "Configuration :"
log "  - Base de données : $DB_NAME"
log "  - Site ID : $SITE_ID"
log "  - ISBNdb : $([ -n "$ISBNDB_KEY" ] && echo "Configuré" || echo "Non configuré")"
log "  - Google Books : $([ -n "$GOOGLE_API_KEY" ] && echo "Clé API" || echo "Sans clé")"
log "  - Groq API : $([ -n "$GROQ_API_KEY" ] && echo "Configuré" || echo "Non configuré")"
log ""

# Test connexion MySQL
if ! test_mysql_connection; then
    log "ERREUR : Impossible de se connecter à MySQL"
    exit 1
fi

# Récupérer les livres à traiter
log "Recherche des livres à enrichir..."
books=$(get_books_to_process "$1")

if [ -z "$books" ]; then
    log "Aucun livre à enrichir trouvé"
    exit 0
fi

# Compter le nombre de livres
total_books=$(echo "$books" | wc -l)
log "Livres à traiter : $total_books"
log ""

# Traiter chaque livre
current=0
while IFS=$'\t' read -r product_id isbn price; do
    ((current++))
    increment_counter "processed"
    log "[$current/$total_books] ---"
    
    # Gérer les erreurs par livre
    {
        collect_book_data "$product_id" "$isbn" "$price"
    } || {
        increment_counter "errors"
        local enriched_count=$(get_counter "enriched")
        echo $((enriched_count - 1)) > "$COUNTER_DIR/enriched"
        log "  ✗ Erreur lors du traitement"
        safe_store_meta "$product_id" "_api_collect_status" "error"
        echo "Erreur pour produit $product_id - ISBN: $isbn" >> "$ERROR_FILE"
    }
    
    # Pause entre les livres
    if [ $current -lt $total_books ]; then
        sleep 1
    fi
done <<< "$books"

# === RAPPORT FINAL ===
log ""
log "========================================="
log "COLLECTE TERMINÉE"
log "========================================="
log "Résultats :"
log "  - Livres traités : $(get_counter "processed")"
log "  - Livres enrichis : $(get_counter "enriched")"
log "  - Erreurs : $(get_counter "errors")"
log ""
log "Appels API :"
log "  - Google Books : $(get_counter "google")"
log "  - ISBNdb : $(get_counter "isbndb")"
log "  - Open Library : $(get_counter "ol")"
log "  - Gallica : $(get_counter "gallica")"
log "  - Autres APIs : $(get_counter "other")"
log "  - Groq IA : $(get_counter "groq")"
log "  - TOTAL : $(($(get_counter "google") + $(get_counter "isbndb") + $(get_counter "ol") + $(get_counter "gallica") + $(get_counter "other") + $(get_counter "groq")))"
log ""
log "Fichier de log : $LOG_FILE"

# Nettoyer les fichiers de compteurs
rm -rf "$COUNTER_DIR"

log ""
log "Script terminé avec succès !"
