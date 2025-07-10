#!/bin/bash
# Fonctions d'enrichissement et calculs

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/database.sh"

# Calculer le poids selon le nombre de pages
calculate_weight() {
    local pages=$1
    if [ "$pages" -gt 0 ]; then
        echo $((pages * 25 / 10))  # 2.5g par page
    else
        echo "0"
    fi
}

# Calculer les dimensions selon le format
calculate_dimensions() {
    local binding=$1
    
    case "$binding" in
        "Paperback"|"Broché")
            echo "21 x 14 x 2"
            ;;
        "Hardcover"|"Relié")
            echo "24 x 16 x 3"
            ;;
        "Pocket Book"|"Poche")
            echo "18 x 11 x 2"
            ;;
        *)
            echo "21 x 14 x 2"
            ;;
    esac
}

# Générer l'EAN à partir de l'ISBN-10
generate_ean_from_isbn10() {
    local isbn10=$1
    if [ -z "$isbn10" ] || [ ${#isbn10} -ne 10 ]; then
        return 1
    fi
    
    # Calculer le check digit pour l'EAN
    local ean_base="978${isbn10:0:9}"
    local sum=0
    for (( i=0; i<12; i++ )); do
        local digit=${ean_base:$i:1}
        if [ $((i % 2)) -eq 0 ]; then
            sum=$((sum + digit))
        else
            sum=$((sum + digit * 3))
        fi
    done
    local check_digit=$((10 - (sum % 10)))
    [ $check_digit -eq 10 ] && check_digit=0
    
    echo "${ean_base}${check_digit}"
}

# Générer les bullet points pour Amazon
generate_bullet_points() {
    local product_id=$1
    local authors=$2
    local pages=$3
    local publisher=$4
    local binding=$5
    local isbn=$6
    
    local bullet1=""
    local bullet2=""
    local bullet3=""
    local bullet4=""
    local bullet5=""
    
    if [ -n "$authors" ]; then
        bullet1="Écrit par $authors - Expert reconnu dans son domaine"
    fi
    
    if [ "$pages" -gt 0 ]; then
        bullet2="$pages pages de contenu riche et détaillé"
    fi
    
    if [ -n "$publisher" ]; then
        bullet3="Publié par $publisher - Éditeur de référence"
    fi
    
    if [ -n "$binding" ]; then
        bullet4="Format $binding - Qualité de fabrication supérieure"
    fi
    
    if [ -n "$isbn" ]; then
        bullet5="ISBN: $isbn - Authenticité garantie"
    fi
    
    safe_store_meta "$product_id" "_calculated_bullet1" "$bullet1"
    safe_store_meta "$product_id" "_calculated_bullet2" "$bullet2"
    safe_store_meta "$product_id" "_calculated_bullet3" "$bullet3"
    safe_store_meta "$product_id" "_calculated_bullet4" "$bullet4"
    safe_store_meta "$product_id" "_calculated_bullet5" "$bullet5"
}

# Générer les mots-clés de recherche
generate_search_terms() {
    local title=$1
    local authors=$2
    local publisher=$3
    local categories=$4
    
    local search_terms=""
    [ -n "$title" ] && search_terms="${search_terms} ${title}"
    [ -n "$authors" ] && search_terms="${search_terms} ${authors}"
    [ -n "$publisher" ] && search_terms="${search_terms} ${publisher}"
    [ -n "$categories" ] && search_terms="${search_terms} ${categories}"
    
    echo "$search_terms" | tr ',' ' ' | tr -s ' ' | cut -c1-250
}

# Calculer le prix de vente conseillé
calculate_msrp() {
    local pages=$1
    local binding=$2
    local msrp_isbndb=$3
    local list_price_google=$4
    
    if [ -n "$msrp_isbndb" ] && [ "$msrp_isbndb" != "0" ] && [ "$msrp_isbndb" != "0.00" ]; then
        echo "$msrp_isbndb"
    elif [ -n "$list_price_google" ] && [ "$list_price_google" != "0" ]; then
        echo "$list_price_google"
    else
        # Estimer selon le nombre de pages et le format
        if [ "$pages" -gt 0 ]; then
            case "$binding" in
                "Hardcover"|"Relié")
                    echo "scale=2; 25 + ($pages * 0.05)" | bc
                    ;;
                "Pocket Book"|"Poche")
                    echo "scale=2; 5 + ($pages * 0.02)" | bc
                    ;;
                *)
                    echo "scale=2; 10 + ($pages * 0.03)" | bc
                    ;;
            esac
        fi
    fi
}

# ===== NOUVELLES FONCTIONS POUR ISBN_UNIFIED =====

# Fonction principale de collecte unifiée
collect_all_apis() {
    local product_id=$1
    local isbn=$2
    local use_groq=${3:-0}  # 0=Claude, 1=Groq
    
    echo "[DEBUG] Début collecte pour produit #$product_id - ISBN: $isbn" >&2
    
    # Marquer comme en cours
    safe_store_meta "$product_id" "_api_collect_status" "processing"
    safe_store_meta "$product_id" "_api_collect_start" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Compteurs
    local api_calls=0
    local data_found=0
    
    # Variables pour stocker les résultats
    local google_data=""
    local isbndb_data=""
    local openlibrary_data=""
    local descriptions=()
    
    # === 1. GOOGLE BOOKS API ===
    echo "[DEBUG] Appel Google Books..." >&2
    if [ -f "$SCRIPT_DIR/apis/google_books.sh" ]; then
        source "$SCRIPT_DIR/apis/google_books.sh"
        if google_data=$(fetch_google_books "$isbn" "$product_id" 2>&1); then
            ((api_calls++))
            ((data_found++))
            echo "[DEBUG] ✓ Google Books : données trouvées" >&2
            
            # Parser les données
            local g_title=$(parse_api_data "$google_data" "title")
            local g_description=$(parse_api_data "$google_data" "description")
            local g_images=$(parse_api_data "$google_data" "images")
            
            if [ -n "$g_description" ] && [ "$g_description" != "null" ]; then
                descriptions+=("$g_description|google")
            fi
            
            echo "[DEBUG] Google : $g_images images trouvées" >&2
        else
            echo "[DEBUG] ✗ Google Books : pas de résultat" >&2
        fi
    fi
    
    # === 2. ISBNDB API ===
    echo "[DEBUG] Appel ISBNdb..." >&2
    if [ -f "$SCRIPT_DIR/apis/isbndb.sh" ]; then
        source "$SCRIPT_DIR/apis/isbndb.sh"
        if isbndb_data=$(fetch_isbndb "$isbn" "$product_id" 2>&1); then
            ((api_calls++))
            ((data_found++))
            echo "[DEBUG] ✓ ISBNdb : données trouvées" >&2
            
            local i_synopsis=$(parse_api_data "$isbndb_data" "synopsis")
            if [ -n "$i_synopsis" ] && [ "$i_synopsis" != "null" ]; then
                descriptions+=("$i_synopsis|isbndb")
            fi
        else
            echo "[DEBUG] ✗ ISBNdb : pas de résultat" >&2
        fi
    fi
    
    # === 3. OPEN LIBRARY API ===
    echo "[DEBUG] Appel Open Library..." >&2
    if [ -f "$SCRIPT_DIR/apis/open_library.sh" ]; then
        source "$SCRIPT_DIR/apis/open_library.sh"
        if openlibrary_data=$(fetch_open_library "$isbn" "$product_id" 2>&1); then
            ((api_calls++))
            ((data_found++))
            echo "[DEBUG] ✓ Open Library : données trouvées" >&2
            
            local o_description=$(parse_api_data "$openlibrary_data" "description")
            if [ -n "$o_description" ] && [ "$o_description" != "null" ] && [ ${#o_description} -gt 30 ]; then
                descriptions+=("$o_description|openlibrary")
            fi
        else
            echo "[DEBUG] ✗ Open Library : pas de résultat" >&2
        fi
    fi
    
    # === 4. SÉLECTION DE LA MEILLEURE DESCRIPTION ===
    local best_description=""
    if ! best_description=$(select_best_description "$product_id" "${descriptions[@]}"); then
        echo "[DEBUG] Aucune description trouvée dans les APIs" >&2
        
        # === 5. GÉNÉRATION IA SI NÉCESSAIRE ===
        if [ ${#descriptions[@]} -eq 0 ]; then
            # Récupérer les meilleures données pour l'IA
            local final_title=$(get_best_value "title" "$product_id")
            local final_authors=$(get_best_value "authors" "$product_id")
            local final_publisher=$(get_best_value "publisher" "$product_id")
            local final_pages=$(get_best_value "pages" "$product_id")
            local final_binding=$(safe_get_meta "$product_id" "_i_binding")
            [ -z "$final_binding" ] && final_binding="Broché"
            local categories=$(safe_get_meta "$product_id" "_g_categories")
            
            if [ "$use_groq" -eq 1 ]; then
                # Utiliser Groq
                echo "[DEBUG] Appel Groq IA..." >&2
                if [ -f "$SCRIPT_DIR/apis/groq_ai.sh" ]; then
                    source "$SCRIPT_DIR/apis/groq_ai.sh"
                    if groq_desc=$(generate_description_groq "$isbn" "$product_id" "$final_title" "$final_authors" "$final_publisher" "$final_pages" "$final_binding" "$categories" 2>&1); then
                        ((api_calls++))
                        best_description="$groq_desc"
                        store_best_data "$product_id" "description" "$best_description" "groq_ai"
                        echo "[DEBUG] ✓ Groq : description générée" >&2
                    else
                        echo "[DEBUG] ✗ Groq : échec génération" >&2
                    fi
                fi
            else
                # Utiliser Claude (par défaut)
                echo "[DEBUG] Appel Claude AI..." >&2
                if [ -f "$SCRIPT_DIR/apis/claude_ai.sh" ]; then
                    source "$SCRIPT_DIR/apis/claude_ai.sh"
                    if claude_desc=$(generate_description_claude "$isbn" "$product_id" "$final_title" "$final_authors" "$final_publisher" "$final_pages" "$final_binding" "$categories" 2>&1); then
                        ((api_calls++))
                        best_description="$claude_desc"
                        store_best_data "$product_id" "description" "$best_description" "claude_ai"
                        echo "[DEBUG] ✓ Claude : description générée" >&2
                    else
                        echo "[DEBUG] ✗ Claude : échec génération" >&2
                        echo "❌ ERREUR CRITIQUE : Claude AI indisponible"
                        echo "   Impossible de générer la description"
                        echo ""
                        echo "💡 Solutions :"
                        echo "   1. Vérifier la clé API dans config/credentials.sh"
                        echo "   2. Essayer avec -groq pour utiliser Groq"
                        echo "   3. Relancer plus tard"
                        echo ""
                        echo "Arrêt du script."
                        return 1
                    fi
                fi
            fi
        fi
    fi
    
    # === 6. CALCULS ET ENRICHISSEMENTS ===
    echo "[DEBUG] Enrichissements automatiques..." >&2
    
    # Calculer le poids si pages disponibles
    local pages=$(get_best_value "pages" "$product_id")
    if [ -n "$pages" ] && [ "$pages" != "0" ] && [ "$pages" != "null" ]; then
        local calculated_weight=$(calculate_weight "$pages")
        safe_store_meta "$product_id" "_calculated_weight" "$calculated_weight"
        echo "[DEBUG] Poids calculé : ${calculated_weight}g" >&2
    fi
    
    # Calculer les dimensions
    local binding=$(safe_get_meta "$product_id" "_i_binding")
    [ -z "$binding" ] && binding=$(safe_get_meta "$product_id" "_o_physical_format")
    [ -z "$binding" ] && binding="Broché"
    local dimensions=$(calculate_dimensions "$binding")
    safe_store_meta "$product_id" "_calculated_dimensions" "$dimensions"
    echo "[DEBUG] Dimensions calculées : $dimensions" >&2
    
    # Générer les bullet points Amazon
    local authors=$(get_best_value "authors" "$product_id")
    local publisher=$(get_best_value "publisher" "$product_id")
    generate_bullet_points "$product_id" "$authors" "$pages" "$publisher" "$binding" "$isbn"
    
    # === 7. TRAITEMENT DES IMAGES ===
    echo "[DEBUG] Traitement des images..." >&2
    process_book_images "$product_id" "$isbn"
    
    # === 8. CORRECTION BUG PUBLISHER ===
    local best_publisher=$(safe_get_meta "$product_id" "_best_publisher")
    if [ -z "$best_publisher" ] || [ "$best_publisher" = "null" ]; then
        local i_publisher=$(safe_get_meta "$product_id" "_i_publisher")
        if [ -n "$i_publisher" ] && [ "$i_publisher" != "null" ]; then
            safe_store_meta "$product_id" "_best_publisher" "$i_publisher"
            safe_store_meta "$product_id" "_best_publisher_source" "isbndb"
        else
            local o_publisher=$(safe_get_meta "$product_id" "_o_publishers")
            if [ -n "$o_publisher" ] && [ "$o_publisher" != "null" ]; then
                safe_store_meta "$product_id" "_best_publisher" "$o_publisher"
                safe_store_meta "$product_id" "_best_publisher_source" "openlibrary"
            fi
        fi
    fi
    
    # === 9. MÉTADONNÉES FINALES ===
    safe_store_meta "$product_id" "_api_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    safe_store_meta "$product_id" "_api_collect_status" "completed"
    safe_store_meta "$product_id" "_api_calls_made" "$api_calls"
    safe_store_meta "$product_id" "_api_data_sources" "$data_found"
    safe_store_meta "$product_id" "_last_analyze_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "[DEBUG] Collecte terminée : $api_calls appels API, $data_found sources" >&2
    # ===== À AJOUTER À LA FIN DE collect_all_apis() AVANT LE RETURN =====

    # === 10. SÉLECTION AUTOMATIQUE DES MEILLEURES DONNÉES ===
    echo "[DEBUG] Sélection automatique des meilleures données..." >&2
    
    # Titre
    local best_title=""
    for key in _g_title _i_title _o_title; do
        local val=$(safe_get_meta "$product_id" "$key")
        if [ -n "$val" ] && [ "$val" != "null" ]; then
            best_title="$val"
            safe_store_meta "$product_id" "_best_title" "$best_title"
            safe_store_meta "$product_id" "_best_title_source" "${key#_}"
            echo "[DEBUG] Best title: $best_title (source: ${key#_})" >&2
            break
        fi
    done
    
    # Auteurs
    local best_authors=""
    for key in _g_authors _i_authors _o_authors; do
        local val=$(safe_get_meta "$product_id" "$key")
        if [ -n "$val" ] && [ "$val" != "null" ]; then
            best_authors="$val"
            safe_store_meta "$product_id" "_best_authors" "$best_authors"
            safe_store_meta "$product_id" "_best_authors_source" "${key#_}"
            echo "[DEBUG] Best authors: $best_authors (source: ${key#_})" >&2
            break
        fi
    done
    
    # Éditeur (correction du bug)
    local best_publisher=""
    for key in _g_publisher _i_publisher _o_publishers; do
        local val=$(safe_get_meta "$product_id" "$key")
        if [ -n "$val" ] && [ "$val" != "null" ]; then
            best_publisher="$val"
            safe_store_meta "$product_id" "_best_publisher" "$best_publisher"
            safe_store_meta "$product_id" "_best_publisher_source" "${key#_}"
            echo "[DEBUG] Best publisher: $best_publisher (source: ${key#_})" >&2
            break
        fi
    done
    
    # Pages
    local best_pages=""
    for key in _g_pageCount _i_pages _o_number_of_pages; do
        local val=$(safe_get_meta "$product_id" "$key")
        if [ -n "$val" ] && [ "$val" != "null" ] && [ "$val" != "0" ]; then
            best_pages="$val"
            safe_store_meta "$product_id" "_best_pages" "$best_pages"
            safe_store_meta "$product_id" "_best_pages_source" "${key#_}"
            echo "[DEBUG] Best pages: $best_pages (source: ${key#_})" >&2
            break
        fi
    done
    
    # Reliure
    local best_binding=""
    for key in _i_binding _o_physical_format; do
        local val=$(safe_get_meta "$product_id" "$key")
        if [ -n "$val" ] && [ "$val" != "null" ]; then
            best_binding="$val"
            safe_store_meta "$product_id" "_best_binding" "$best_binding"
            safe_store_meta "$product_id" "_best_binding_source" "${key#_}"
            echo "[DEBUG] Best binding: $best_binding (source: ${key#_})" >&2
            break
        fi
    done
    
    # Mise à jour du titre WordPress si nécessaire
    if [ -n "$best_title" ]; then
        local current_title=$(safe_mysql "SELECT post_title FROM wp_${SITE_ID}_posts WHERE ID = $product_id")
        if [[ "$current_title" =~ ^Livre[[:space:]]ISBN ]] || [ "$current_title" = "" ]; then
            echo "[DEBUG] Mise à jour du titre WordPress : $best_title" >&2
            local title_escaped=$(safe_sql "$best_title")
            safe_mysql "UPDATE wp_${SITE_ID}_posts SET post_title = '$title_escaped' WHERE ID = $product_id"
        fi
    fi
    
    # === 11. VÉRIFICATION SI DONNÉES DÉJÀ COLLECTÉES ===
    if [ $data_found -eq 0 ] && [ $api_calls -gt 0 ]; then
        echo "[DEBUG] ⚠️  Aucune nouvelle donnée trouvée (APIs déjà interrogées)" >&2
        echo "[DEBUG] 💡 Utilisez -force pour forcer une nouvelle collecte" >&2
    fi
    return 0
}

# Traiter et importer les images d'un livre
process_book_images() {
    local product_id=$1
    local isbn=$2
    
    echo "[DEBUG] Recherche de la meilleure image..." >&2
    
    # Ordre de préférence des images
    local image_keys=(
        "_g_extraLarge"
        "_g_large"
        "_g_medium"
        "_g_small"
        "_g_thumbnail"
        "_g_smallThumbnail"
        "_i_image"
        "_o_cover_large"
        "_o_cover_medium"
        "_o_cover_small"
    )
    
    local best_image=""
    local best_key=""
    
    # Trouver la meilleure image disponible
    for key in "${image_keys[@]}"; do
        local url=$(safe_get_meta "$product_id" "$key")
        if [ -n "$url" ] && [ "$url" != "null" ] && [[ "$url" =~ ^https?:// ]]; then
            echo "[DEBUG] Image trouvée : $key" >&2
            
            # Vérifier si l'image existe
            if check_image_exists "$url"; then
                best_image="$url"
                best_key="$key"
                break
            else
                echo "[DEBUG] Image cassée : $url" >&2
            fi
        fi
    done
    
    if [ -n "$best_image" ]; then
        echo "[DEBUG] Meilleure image : $best_key → $best_image" >&2
        safe_store_meta "$product_id" "_best_cover_image" "$best_image"
        safe_store_meta "$product_id" "_best_cover_source" "$best_key"
        
        # Importer dans WordPress si possible
        if command -v wget &>/dev/null && command -v identify &>/dev/null; then
            import_image_to_wordpress "$product_id" "$isbn" "$best_image"
        fi
    else
        echo "[DEBUG] Aucune image valide trouvée" >&2
    fi
}

# Vérifier qu'une image existe
check_image_exists() {
    local url=$1
    
    if command -v curl &>/dev/null; then
        local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I "$url" --connect-timeout 5 --max-time 10 2>/dev/null)
        [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]
    else
        # Si curl n'est pas disponible, on suppose que l'image existe
        return 0
    fi
}

# Importer une image dans WordPress
import_image_to_wordpress() {
    local product_id=$1
    local isbn=$2
    local image_url=$3
    
    echo "[DEBUG] Import de l'image dans WordPress..." >&2
    
    # Créer les répertoires si nécessaire
    local year=$(date +%Y)
    local month=$(date +%m)
    local upload_dir="/var/www/html/wp-content/uploads/$year/$month"
    mkdir -p "$upload_dir"
    
    # Nom du fichier
    local filename="book-${isbn}-$(date +%s).jpg"
    local temp_file="/tmp/$filename"
    local final_file="$upload_dir/$filename"
    
    # Télécharger l'image
    if wget -q "$image_url" -O "$temp_file" 2>/dev/null; then
        echo "[DEBUG] Image téléchargée : $temp_file" >&2
        
        # Vérifier l'image avec ImageMagick
        if command -v identify &>/dev/null; then
            local img_info=$(identify "$temp_file" 2>/dev/null)
            if [ -z "$img_info" ]; then
                echo "[DEBUG] Image invalide, abandon" >&2
                rm -f "$temp_file"
                return 1
            fi
            
            # Obtenir les dimensions
            local dimensions=$(identify -format "%wx%h" "$temp_file" 2>/dev/null)
            echo "[DEBUG] Dimensions : $dimensions" >&2
        fi
        
        # Déplacer vers le dossier uploads
        mv "$temp_file" "$final_file"
        chmod 644 "$final_file"
        
        # Créer l'attachment dans WordPress
        local attachment_url="https://savoirlire.com/wp-content/uploads/$year/$month/$filename"
        local attachment_path="$year/$month/$filename"
        
        # Insérer dans wp_posts
        local attachment_id=$(safe_mysql "
            INSERT INTO wp_${SITE_ID}_posts (
                post_author, post_date, post_date_gmt, post_content, post_title,
                post_status, post_name, post_type, post_mime_type, guid
            ) VALUES (
                1, NOW(), NOW(), '', 'book-$isbn', 
                'inherit', 'book-$isbn', 'attachment', 'image/jpeg', '$attachment_url'
            );
            SELECT LAST_INSERT_ID();")
        
        if [ -n "$attachment_id" ] && [ "$attachment_id" != "0" ]; then
            echo "[DEBUG] Attachment créé : ID #$attachment_id" >&2
            
            # Ajouter les métadonnées
            safe_store_meta "$attachment_id" "_wp_attached_file" "$attachment_path"
            safe_store_meta "$attachment_id" "_wp_attachment_metadata" "a:0:{}"
            
            # Attacher au produit
            safe_store_meta "$product_id" "_thumbnail_id" "$attachment_id"
            
            echo "[DEBUG] ✓ Image importée avec succès" >&2
        else
            echo "[DEBUG] Erreur création attachment" >&2
        fi
    else
        echo "[DEBUG] Erreur téléchargement image" >&2
    fi
}

# Obtenir l'ID produit depuis ISBN ou ID
get_product_id_from_input() {
    local input=$1
    
    # Nettoyer l'input (enlever tirets)
    input=$(echo "$input" | tr -d '-')
    
    if [[ "$input" =~ ^[0-9]{1,6}$ ]]; then
        # C'est un ID
        echo "$input"
    elif [[ "$input" =~ ^[0-9]{10}$ ]] || [[ "$input" =~ ^[0-9]{13}$ ]]; then
        # C'est un ISBN
        local product_id=$(safe_mysql "
            SELECT post_id FROM wp_${SITE_ID}_postmeta 
            WHERE meta_key = '_isbn' AND meta_value = '$input' 
            LIMIT 1")
        echo "$product_id"
    else
        echo ""
    fi
}

# Sélectionner les livres incomplets pour traitement par lot
select_incomplete_books() {
    local limit=$1
    local force=${2:-0}
    
    if [ "$force" -eq 1 ]; then
        # Mode force : tous les livres
        safe_mysql "
            SELECT DISTINCT p.ID, pm_isbn.meta_value as isbn
            FROM wp_${SITE_ID}_posts p
            JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id 
                AND pm_isbn.meta_key = '_isbn'
            WHERE p.post_type = 'product'
            AND p.post_status = 'publish'
            ORDER BY p.ID ASC
            LIMIT $limit"
    else
        # Mode normal : seulement les incomplets
        safe_mysql "
            SELECT DISTINCT p.ID, pm_isbn.meta_value as isbn
            FROM wp_${SITE_ID}_posts p
            JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id 
                AND pm_isbn.meta_key = '_isbn'
            LEFT JOIN wp_${SITE_ID}_postmeta pm_score ON p.ID = pm_score.post_id 
                AND pm_score.meta_key = '_export_score'
            LEFT JOIN wp_${SITE_ID}_postmeta pm_max ON p.ID = pm_max.post_id 
                AND pm_max.meta_key = '_export_max_score'
            WHERE p.post_type = 'product'
            AND p.post_status = 'publish'
            AND (
                pm_score.meta_value IS NULL 
                OR pm_max.meta_value IS NULL
                OR pm_score.meta_value < pm_max.meta_value
            )
            ORDER BY p.ID ASC
            LIMIT $limit"
    fi
}

# Compter les livres incomplets
count_incomplete_books() {
    local force=${1:-0}
    
    if [ "$force" -eq 1 ]; then
        safe_mysql "
            SELECT COUNT(DISTINCT p.ID)
            FROM wp_${SITE_ID}_posts p
            JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id 
                AND pm_isbn.meta_key = '_isbn'
            WHERE p.post_type = 'product'
            AND p.post_status = 'publish'"
    else
        safe_mysql "
            SELECT COUNT(DISTINCT p.ID)
            FROM wp_${SITE_ID}_posts p
            JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id 
                AND pm_isbn.meta_key = '_isbn'
            LEFT JOIN wp_${SITE_ID}_postmeta pm_score ON p.ID = pm_score.post_id 
                AND pm_score.meta_key = '_export_score'
            LEFT JOIN wp_${SITE_ID}_postmeta pm_max ON p.ID = pm_max.post_id 
                AND pm_max.meta_key = '_export_max_score'
            WHERE p.post_type = 'product'
            AND p.post_status = 'publish'
            AND (
                pm_score.meta_value IS NULL 
                OR pm_max.meta_value IS NULL
                OR pm_score.meta_value < pm_max.meta_value
            )"
    fi
}

# Export des nouvelles fonctions
export -f collect_all_apis
export -f process_book_images
export -f check_image_exists
export -f import_image_to_wordpress
export -f get_product_id_from_input
export -f select_incomplete_books
export -f count_incomplete_books
