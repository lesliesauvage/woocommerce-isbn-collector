#!/bin/bash
echo "[START: isbn_collect.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# Bibliothèque de fonctions de collecte pour isbn_unified.sh
# Gère la collecte des données via APIs et validation

# Fonction pour valider un ISBN
validate_isbn_format() {
    local isbn="$1"
    
    # Nettoyer l'ISBN (garder seulement les chiffres)
    isbn="${isbn//[^0-9]/}"
    
    # Vérifier la longueur
    if [ ${#isbn} -eq 10 ] || [ ${#isbn} -eq 13 ]; then
        echo "$isbn"
        return 0
    else
        return 1
    fi
}

# Fonction pour marquer une tentative de collecte
mark_collection_attempt() {
    local post_id="$1"
    local api_name="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    case "$api_name" in
        "google")
            safe_store_meta "$post_id" "_google_last_attempt" "$timestamp"
            ;;
        "isbndb")
            safe_store_meta "$post_id" "_isbndb_last_attempt" "$timestamp"
            ;;
        "openlibrary")
            safe_store_meta "$post_id" "_openlibrary_last_attempt" "$timestamp"
            ;;
        "claude")
            safe_store_meta "$post_id" "_claude_ai_date" "$timestamp"
            ;;
        "groq")
            safe_store_meta "$post_id" "_groq_ai_date" "$timestamp"
            ;;
    esac
}

# Fonction pour vérifier si une collecte est nécessaire
needs_collection() {
    local post_id="$1"
    local force="${2:-0}"
    
    # Si mode force, toujours collecter
    if [ "$force" -eq 1 ]; then
        return 0
    fi
    
    # Vérifier le statut de collection
    local status=$(get_meta_value "$post_id" "_collection_status")
    if [ "$status" = "completed" ]; then
        return 1
    fi
    
    # Vérifier la date de dernière collecte
    local last_collect=$(get_meta_value "$post_id" "_last_collect_date")
    if [ -n "$last_collect" ]; then
        # Calculer l'âge en jours
        local last_timestamp=$(date -d "$last_collect" +%s 2>/dev/null || echo 0)
        local now_timestamp=$(date +%s)
        local age_days=$(((now_timestamp - last_timestamp) / 86400))
        
        # Si collecté il y a moins de 7 jours, pas besoin
        if [ $age_days -lt 7 ]; then
            return 1
        fi
    fi
    
    return 0
}

# Fonction pour collecter toutes les APIs
collect_all_apis() {
    local isbn="$1"
    local post_id="$2"
    local results=0
    
    echo "[DEBUG] Début collecte toutes APIs pour ISBN: $isbn, ID: $post_id" >&2
    
    # Google Books
    if [ -f "$SCRIPT_DIR/apis/google_books.sh" ]; then
        echo "  → Appel Google Books API..."
        mark_collection_attempt "$post_id" "google"
        source "$SCRIPT_DIR/apis/google_books.sh"
        if fetch_google_books "$isbn" "$post_id"; then
            ((results++))
            echo "    ✓ Google Books : données récupérées"
        else
            echo "    ✗ Google Books : aucune donnée"
        fi
    fi
    
    # ISBNdb
    if [ -f "$SCRIPT_DIR/apis/isbndb.sh" ]; then
        echo "  → Appel ISBNdb API..."
        mark_collection_attempt "$post_id" "isbndb"
        source "$SCRIPT_DIR/apis/isbndb.sh"
        if fetch_isbndb "$isbn" "$post_id"; then
            ((results++))
            echo "    ✓ ISBNdb : données récupérées"
        else
            echo "    ✗ ISBNdb : aucune donnée"
        fi
    fi
    
    # Open Library
    if [ -f "$SCRIPT_DIR/apis/open_library.sh" ]; then
        echo "  → Appel Open Library API..."
        mark_collection_attempt "$post_id" "openlibrary"
        source "$SCRIPT_DIR/apis/open_library.sh"
        if fetch_open_library "$isbn" "$post_id"; then
            ((results++))
            echo "    ✓ Open Library : données récupérées"
        else
            echo "    ✗ Open Library : aucune donnée"
        fi
    fi
    
    echo "[DEBUG] Collecte terminée : $results API(s) avec données" >&2
    
    return $((3 - results))  # Retourne le nombre d'échecs
}

# Fonction pour générer une description IA
generate_ai_description() {
    local post_id="$1"
    local isbn="$2"
    
    # Récupérer les données pour l'IA
    local title=$(get_meta_value "$post_id" "_best_title")
    local authors=$(get_meta_value "$post_id" "_best_authors")
    local publisher=$(get_meta_value "$post_id" "_best_publisher")
    local pages=$(get_meta_value "$post_id" "_best_pages")
    local binding=$(get_meta_value "$post_id" "_best_binding")
    local categories=$(get_meta_value "$post_id" "_g_categories")
    
    # Vérifier qu'on a au moins le titre
    if [ -z "$title" ]; then
        echo "[ERROR] Pas de titre pour générer la description" >&2
        return 1
    fi
    
    local description_generated=0
    
    # Essayer Claude d'abord
    if [ -f "$SCRIPT_DIR/apis/claude_ai.sh" ]; then
        echo "  → Génération description avec Claude AI..."
        mark_collection_attempt "$post_id" "claude"
        source "$SCRIPT_DIR/apis/claude_ai.sh"
        
        if claude_desc=$(generate_description_claude "$isbn" "$post_id" "$title" "$authors" "$publisher" "$pages" "$binding" "$categories" 2>&1); then
            if [ -n "$claude_desc" ] && [ ${#claude_desc} -gt 20 ]; then
                safe_store_meta "$post_id" "_claude_description" "$claude_desc"
                safe_store_meta "$post_id" "_best_description" "$claude_desc"
                safe_store_meta "$post_id" "_best_description_source" "claude_ai"
                safe_store_meta "$post_id" "_has_description" "1"
                echo "    ✓ Claude AI : description générée (${#claude_desc} caractères)"
                description_generated=1
            else
                echo "    ✗ Claude AI : description trop courte"
            fi
        else
            echo "    ✗ Claude AI : échec génération"
        fi
    fi
    
    # Si Claude a échoué, essayer Groq
    if [ $description_generated -eq 0 ] && [ -f "$SCRIPT_DIR/apis/groq_ai.sh" ]; then
        echo "  → Génération description avec Groq AI (fallback)..."
        mark_collection_attempt "$post_id" "groq"
        source "$SCRIPT_DIR/apis/groq_ai.sh"
        
        if groq_desc=$(generate_description_groq "$isbn" "$post_id" "$title" "$authors" "$publisher" "$pages" "$binding" "$categories" 2>&1); then
            if [ -n "$groq_desc" ] && [ ${#groq_desc} -gt 20 ]; then
                safe_store_meta "$post_id" "_groq_description" "$groq_desc"
                safe_store_meta "$post_id" "_best_description" "$groq_desc"
                safe_store_meta "$post_id" "_best_description_source" "groq_ai"
                safe_store_meta "$post_id" "_has_description" "1"
                echo "    ✓ Groq AI : description générée (${#groq_desc} caractères)"
                description_generated=1
            else
                echo "    ✗ Groq AI : description trop courte"
            fi
        else
            echo "    ✗ Groq AI : échec génération"
        fi
    fi
    
    return $((1 - description_generated))
}

# Fonction pour marquer la collection comme complète
mark_collection_complete() {
    local post_id="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    safe_store_meta "$post_id" "_collection_status" "completed"
    safe_store_meta "$post_id" "_last_collect_date" "$timestamp"
    safe_store_meta "$post_id" "_api_collect_date" "$timestamp"
    safe_store_meta "$post_id" "_last_analyze_date" "$timestamp"
    
    echo "[DEBUG] Collection marquée comme complète pour #$post_id" >&2
}

# Fonction pour vérifier la qualité des données collectées
check_data_quality() {
    local post_id="$1"
    local quality_score=0
    local max_score=10
    local issues=""
    
    # Vérifier titre
    local title=$(get_meta_value "$post_id" "_best_title")
    if [ -n "$title" ] && [ "$title" != "null" ]; then
        ((quality_score += 2))
    else
        issues="${issues}Titre manquant. "
    fi
    
    # Vérifier auteurs
    local authors=$(get_meta_value "$post_id" "_best_authors")
    if [ -n "$authors" ] && [ "$authors" != "null" ]; then
        ((quality_score += 1))
    else
        issues="${issues}Auteurs manquants. "
    fi
    
    # Vérifier description
    local description=$(get_meta_value "$post_id" "_best_description")
    if [ -n "$description" ] && [ ${#description} -gt 50 ]; then
        ((quality_score += 2))
    else
        issues="${issues}Description insuffisante. "
    fi
    
    # Vérifier image
    local image=$(get_meta_value "$post_id" "_best_cover_image")
    if [ -n "$image" ] && [[ "$image" =~ ^https?:// ]]; then
        ((quality_score += 2))
    else
        issues="${issues}Image manquante. "
    fi
    
    # Vérifier prix
    local price=$(get_meta_value "$post_id" "_price")
    if [ -n "$price" ] && [ "$price" != "0" ]; then
        ((quality_score += 2))
    else
        issues="${issues}Prix non défini. "
    fi
    
    # Vérifier ISBN
    local isbn=$(get_meta_value "$post_id" "_isbn")
    if [ -n "$isbn" ]; then
        ((quality_score += 1))
    else
        issues="${issues}ISBN manquant. "
    fi
    
    # Calculer le pourcentage
    local percentage=$((quality_score * 100 / max_score))
    
    # Sauvegarder le score de qualité
    safe_store_meta "$post_id" "_data_quality_score" "$quality_score"
    safe_store_meta "$post_id" "_data_quality_max" "$max_score"
    safe_store_meta "$post_id" "_data_quality_issues" "$issues"
    
    echo "[DEBUG] Score qualité : $quality_score/$max_score ($percentage%)" >&2
    [ -n "$issues" ] && echo "[DEBUG] Problèmes : $issues" >&2
    
    return $((percentage < 70))  # Retourne 1 si qualité < 70%
}

# Fonction pour nettoyer les données invalides
cleanup_invalid_data() {
    local post_id="$1"
    local cleaned=0
    
    echo "[DEBUG] Nettoyage des données invalides pour #$post_id..." >&2
    
    # Liste des métadonnées à vérifier
    local meta_keys=(
        "_g_title" "_g_authors" "_g_publisher" "_g_description"
        "_i_title" "_i_authors" "_i_publisher" "_i_synopsis"
        "_o_title" "_o_authors" "_o_publishers" "_o_description"
        "_best_title" "_best_authors" "_best_publisher" "_best_description"
    )
    
    for key in "${meta_keys[@]}"; do
        local value=$(get_meta_value "$post_id" "$key")
        
        # Nettoyer si vide, null, ou juste des espaces
        if [ -z "$value" ] || [ "$value" = "null" ] || [ "$value" = "NULL" ] || [[ "$value" =~ ^[[:space:]]*$ ]]; then
            mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
                DELETE FROM wp_${SITE_ID}_postmeta 
                WHERE post_id=$post_id AND meta_key='$key'" 2>/dev/null
            ((cleaned++))
        fi
    done
    
    echo "[DEBUG] $cleaned métadonnées invalides nettoyées" >&2
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
    
    return 0
}

# Fonction pour récupérer les métadonnées depuis le cache
get_from_cache() {
    local isbn="$1"
    local cache_file="$SCRIPT_DIR/cache/isbn_${isbn}.json"
    
    if [ -f "$cache_file" ]; then
        # Vérifier l'âge du cache (7 jours)
        local file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        if [ $file_age -lt 604800 ]; then  # 7 jours en secondes
            echo "[DEBUG] Utilisation du cache pour ISBN $isbn" >&2
            cat "$cache_file"
            return 0
        fi
    fi
    
    return 1
}

# Fonction pour sauvegarder dans le cache
save_to_cache() {
    local isbn="$1"
    local data="$2"
    local cache_dir="$SCRIPT_DIR/cache"
    
    mkdir -p "$cache_dir"
    echo "$data" > "$cache_dir/isbn_${isbn}.json"
    echo "[DEBUG] Données mises en cache pour ISBN $isbn" >&2
}

echo "[END: isbn_collect.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
