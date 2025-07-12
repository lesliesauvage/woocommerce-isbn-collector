#!/bin/bash
echo "[START: isbn_functions.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# Bibliothèque de fonctions utilitaires pour isbn_unified.sh
# Gère la sélection des données, calculs et génération de contenu

# Fonction pour obtenir le timestamp d'une métadonnée
get_meta_timestamp() {
    local post_id="$1"
    local meta_key="$2"
    local timestamp=""
    
    # Pour les APIs, chercher le timestamp de dernière tentative
    case "$meta_key" in
        "_g_"*)
            timestamp=$(get_meta_value "$post_id" "_google_last_attempt")
            ;;
        "_i_"*)
            timestamp=$(get_meta_value "$post_id" "_isbndb_last_attempt")
            ;;
        "_o_"*)
            timestamp=$(get_meta_value "$post_id" "_openlibrary_last_attempt")
            ;;
        "_best_"*|"_calculated_"*)
            timestamp=$(get_meta_value "$post_id" "_last_collect_date")
            ;;
        *)
            # Pour les autres, utiliser la date de dernière collecte
            timestamp=$(get_meta_value "$post_id" "_last_collect_date")
            ;;
    esac
    
    echo "${timestamp:-Non collecté}"
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
}

# Fonction pour sélectionner les meilleures données
select_best_data() {
    local post_id="$1"
    [ -z "$post_id" ] && { echo "[ERROR] select_best_data: post_id requis"; return 1; }
    
    echo "[DEBUG] Sélection des meilleures données pour #$post_id..." >&2
    
    # Récupérer toutes les données des APIs
    local g_title=$(get_meta_value "$post_id" "_g_title")
    local i_title=$(get_meta_value "$post_id" "_i_title")
    local o_title=$(get_meta_value "$post_id" "_o_title")
    
    local g_authors=$(get_meta_value "$post_id" "_g_authors")
    local i_authors=$(get_meta_value "$post_id" "_i_authors")
    local o_authors=$(get_meta_value "$post_id" "_o_authors")
    
    local g_publisher=$(get_meta_value "$post_id" "_g_publisher")
    local i_publisher=$(get_meta_value "$post_id" "_i_publisher")
    local o_publishers=$(get_meta_value "$post_id" "_o_publishers")
    
    local g_pages=$(get_meta_value "$post_id" "_g_pageCount")
    local i_pages=$(get_meta_value "$post_id" "_i_pages")
    local o_pages=$(get_meta_value "$post_id" "_o_number_of_pages")
    
    local g_desc=$(get_meta_value "$post_id" "_g_description")
    local i_desc=$(get_meta_value "$post_id" "_i_synopsis")
    local o_desc=$(get_meta_value "$post_id" "_o_description")
    local claude_desc=$(get_meta_value "$post_id" "_claude_description")
    local groq_desc=$(get_meta_value "$post_id" "_groq_description")
    
    local i_binding=$(get_meta_value "$post_id" "_i_binding")
    local o_format=$(get_meta_value "$post_id" "_o_physical_format")
    
    # Sélectionner le meilleur titre (priorité : ISBNdb > Google > OpenLibrary)
    local best_title=""
    local best_title_source=""
    if [ ! -z "$i_title" ] && [ "$i_title" != "null" ]; then
        best_title="$i_title"
        best_title_source="isbndb"
    elif [ ! -z "$g_title" ] && [ "$g_title" != "null" ]; then
        best_title="$g_title"
        best_title_source="google"
    elif [ ! -z "$o_title" ] && [ "$o_title" != "null" ]; then
        best_title="$o_title"
        best_title_source="openlibrary"
    fi
    
    # Sélectionner les meilleurs auteurs
    local best_authors=""
    local best_authors_source=""
    if [ ! -z "$i_authors" ] && [ "$i_authors" != "null" ]; then
        best_authors="$i_authors"
        best_authors_source="isbndb"
    elif [ ! -z "$g_authors" ] && [ "$g_authors" != "null" ]; then
        best_authors="$g_authors"
        best_authors_source="google"
    elif [ ! -z "$o_authors" ] && [ "$o_authors" != "null" ]; then
        best_authors="$o_authors"
        best_authors_source="openlibrary"
    fi
    
    # Sélectionner le meilleur éditeur
    local best_publisher=""
    local best_publisher_source=""
    if [ ! -z "$i_publisher" ] && [ "$i_publisher" != "null" ]; then
        best_publisher="$i_publisher"
        best_publisher_source="isbndb"
    elif [ ! -z "$g_publisher" ] && [ "$g_publisher" != "null" ]; then
        best_publisher="$g_publisher"
        best_publisher_source="google"
    elif [ ! -z "$o_publishers" ] && [ "$o_publishers" != "null" ]; then
        best_publisher="$o_publishers"
        best_publisher_source="openlibrary"
    fi
    
    # Sélectionner le meilleur nombre de pages
    local best_pages=""
    local best_pages_source=""
    if [ ! -z "$i_pages" ] && [ "$i_pages" != "null" ] && [ "$i_pages" != "0" ]; then
        best_pages="$i_pages"
        best_pages_source="isbndb"
    elif [ ! -z "$g_pages" ] && [ "$g_pages" != "null" ] && [ "$g_pages" != "0" ]; then
        best_pages="$g_pages"
        best_pages_source="google"
    elif [ ! -z "$o_pages" ] && [ "$o_pages" != "null" ] && [ "$o_pages" != "0" ]; then
        best_pages="$o_pages"
        best_pages_source="openlibrary"
    fi
    
    # Sélectionner la meilleure description
    local best_description=""
    local best_description_source=""
    if [ ! -z "$claude_desc" ] && [ "$claude_desc" != "null" ] && [ ${#claude_desc} -gt 20 ]; then
        best_description="$claude_desc"
        best_description_source="claude_ai"
    elif [ ! -z "$groq_desc" ] && [ "$groq_desc" != "null" ] && [ ${#groq_desc} -gt 20 ]; then
        best_description="$groq_desc"
        best_description_source="groq_ai"
    elif [ ! -z "$g_desc" ] && [ "$g_desc" != "null" ] && [ ${#g_desc} -gt 20 ]; then
        best_description="$g_desc"
        best_description_source="google"
    elif [ ! -z "$i_desc" ] && [ "$i_desc" != "null" ] && [ ${#i_desc} -gt 20 ]; then
        best_description="$i_desc"
        best_description_source="isbndb"
    elif [ ! -z "$o_desc" ] && [ "$o_desc" != "null" ] && [ ${#o_desc} -gt 20 ]; then
        best_description="$o_desc"
        best_description_source="openlibrary"
    fi
    
    # Sélectionner le meilleur format
    local best_binding=""
    local best_binding_source=""
    if [ ! -z "$i_binding" ] && [ "$i_binding" != "null" ]; then
        best_binding="$i_binding"
        best_binding_source="isbndb"
    elif [ ! -z "$o_format" ] && [ "$o_format" != "null" ]; then
        best_binding="$o_format"
        best_binding_source="openlibrary"
    else
        best_binding="Broché"
        best_binding_source="default"
    fi
    
    # Sélectionner la meilleure image
    local best_cover=""
    local best_cover_source=""
    # Ordre de préférence : grande > moyenne > petite
    for key in _g_extraLarge _g_large _g_medium _g_small _g_thumbnail _g_smallThumbnail _i_image _o_cover_large _o_cover_medium _o_cover_small; do
        local img=$(get_meta_value "$post_id" "$key")
        if [ ! -z "$img" ] && [ "$img" != "null" ] && [[ "$img" =~ ^https?:// ]]; then
            best_cover="$img"
            best_cover_source="${key#_}"
            break
        fi
    done
    
    # Sauvegarder les meilleures données
    [ ! -z "$best_title" ] && safe_store_meta "$post_id" "_best_title" "$best_title"
    [ ! -z "$best_title_source" ] && safe_store_meta "$post_id" "_best_title_source" "$best_title_source"
    
    [ ! -z "$best_authors" ] && safe_store_meta "$post_id" "_best_authors" "$best_authors"
    [ ! -z "$best_authors_source" ] && safe_store_meta "$post_id" "_best_authors_source" "$best_authors_source"
    
    [ ! -z "$best_publisher" ] && safe_store_meta "$post_id" "_best_publisher" "$best_publisher"
    [ ! -z "$best_publisher_source" ] && safe_store_meta "$post_id" "_best_publisher_source" "$best_publisher_source"
    
    [ ! -z "$best_pages" ] && safe_store_meta "$post_id" "_best_pages" "$best_pages"
    [ ! -z "$best_pages_source" ] && safe_store_meta "$post_id" "_best_pages_source" "$best_pages_source"
    
    [ ! -z "$best_description" ] && safe_store_meta "$post_id" "_best_description" "$best_description"
    [ ! -z "$best_description_source" ] && safe_store_meta "$post_id" "_best_description_source" "$best_description_source"
    
    [ ! -z "$best_binding" ] && safe_store_meta "$post_id" "_best_binding" "$best_binding"
    [ ! -z "$best_binding_source" ] && safe_store_meta "$post_id" "_best_binding_source" "$best_binding_source"
    
    [ ! -z "$best_cover" ] && safe_store_meta "$post_id" "_best_cover_image" "$best_cover"
    [ ! -z "$best_cover_source" ] && safe_store_meta "$post_id" "_best_cover_source" "$best_cover_source"
    
    # Mettre à jour le titre WordPress si on a un meilleur titre
    if [ ! -z "$best_title" ]; then
        local escaped_title=$(safe_sql "$best_title")
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            UPDATE wp_${SITE_ID}_posts 
            SET post_title='$escaped_title' 
            WHERE ID=$post_id"
    fi
    
    echo "[DEBUG] Meilleures données sélectionnées et sauvegardées" >&2
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
}

# Fonction de calcul du poids et dimensions
calculate_weight_dimensions() {
    local post_id="$1"
    [ -z "$post_id" ] && { echo "[ERROR] calculate_weight_dimensions: post_id requis"; return 1; }
    
    echo "[DEBUG] Calcul du poids et dimensions pour #$post_id..." >&2
    
    # Récupérer le nombre de pages
    local pages=$(get_meta_value "$post_id" "_best_pages")
    [ -z "$pages" ] && pages=$(get_meta_value "$post_id" "_g_pageCount")
    [ -z "$pages" ] && pages=$(get_meta_value "$post_id" "_i_pages")
    [ -z "$pages" ] && pages=$(get_meta_value "$post_id" "_o_number_of_pages")
    
    # Récupérer le format
    local binding=$(get_meta_value "$post_id" "_best_binding")
    [ -z "$binding" ] && binding=$(get_meta_value "$post_id" "_i_binding")
    [ -z "$binding" ] && binding=$(get_meta_value "$post_id" "_o_physical_format")
    [ -z "$binding" ] && binding="Broché"
    
    if [ ! -z "$pages" ] && [ "$pages" != "0" ]; then
        # Calcul du poids approximatif (2.5g par page + 50g couverture)
        local weight=$((pages * 25 / 10 + 50))
        safe_store_meta "$post_id" "_calculated_weight" "$weight"
        safe_store_meta "$post_id" "_weight" "$weight"
        
        # Dimensions selon le format
        local length width height dimensions
        
        if [[ "$binding" =~ [Pp]oche ]]; then
            length="18"
            width="11"
            height="2"
            dimensions="18x11x2"
        elif [[ "$binding" =~ [Rr]elié|[Hh]ardcover ]]; then
            length="24"
            width="16"
            height="3"
            dimensions="24x16x3"
        else
            # Broché par défaut
            length="21"
            width="14"
            height="2"
            dimensions="21x14x2"
        fi
        
        # Ajuster l'épaisseur selon le nombre de pages
        if [ $pages -gt 500 ]; then
            height="5"
        elif [ $pages -gt 300 ]; then
            height="3"
        elif [ $pages -gt 200 ]; then
            height="2"
        else
            height="1"
        fi
        
        # Recalculer dimensions avec nouvelle hauteur
        dimensions="${length}x${width}x${height}"
        
        # Stocker toutes les dimensions
        safe_store_meta "$post_id" "_calculated_length" "$length"
        safe_store_meta "$post_id" "_calculated_width" "$width"
        safe_store_meta "$post_id" "_calculated_height" "$height"
        safe_store_meta "$post_id" "_calculated_dimensions" "$dimensions"
        
        # Stocker aussi dans les champs WooCommerce
        safe_store_meta "$post_id" "_length" "$length"
        safe_store_meta "$post_id" "_width" "$width"
        safe_store_meta "$post_id" "_height" "$height"
        
        echo "[DEBUG] Poids: ${weight}g, Dimensions: ${dimensions}cm" >&2
    else
        # Valeurs par défaut si pas de pages
        safe_store_meta "$post_id" "_calculated_weight" "200"
        safe_store_meta "$post_id" "_weight" "200"
        safe_store_meta "$post_id" "_calculated_length" "21"
        safe_store_meta "$post_id" "_calculated_width" "14"
        safe_store_meta "$post_id" "_calculated_height" "2"
        safe_store_meta "$post_id" "_calculated_dimensions" "21x14x2"
        safe_store_meta "$post_id" "_length" "21"
        safe_store_meta "$post_id" "_width" "14"
        safe_store_meta "$post_id" "_height" "2"
        
        echo "[DEBUG] Poids et dimensions par défaut appliqués" >&2
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
}

# Fonction de génération des bullet points
generate_bullet_points() {
    local post_id="$1"
    [ -z "$post_id" ] && { echo "[ERROR] generate_bullet_points: post_id requis"; return 1; }
    
    echo "[DEBUG] Génération des bullet points pour #$post_id..." >&2
    
    # Récupérer les données
    local title=$(get_meta_value "$post_id" "_best_title")
    local authors=$(get_meta_value "$post_id" "_best_authors")
    local publisher=$(get_meta_value "$post_id" "_best_publisher")
    local pages=$(get_meta_value "$post_id" "_best_pages")
    local binding=$(get_meta_value "$post_id" "_best_binding")
    local language=$(get_meta_value "$post_id" "_g_language")
    local date=$(get_meta_value "$post_id" "_g_publishedDate")
    local isbn=$(get_meta_value "$post_id" "_isbn")
    local condition=$(get_meta_value "$post_id" "_book_condition")
    local dimensions=$(get_meta_value "$post_id" "_calculated_dimensions")
    
    # Générer 5 bullet points
    local bullet1 bullet2 bullet3 bullet4 bullet5
    
    # Bullet 1 : Format et pages
    if [ ! -z "$binding" ] && [ ! -z "$pages" ]; then
        bullet1="Format $binding de $pages pages"
    elif [ ! -z "$pages" ]; then
        bullet1="Livre de $pages pages"
    elif [ ! -z "$binding" ]; then
        bullet1="Format $binding"
    else
        bullet1="Livre d'occasion"
    fi
    
    # Bullet 2 : Auteur et éditeur
    if [ ! -z "$authors" ] && [ ! -z "$publisher" ]; then
        bullet2="Par $authors, édité chez $publisher"
    elif [ ! -z "$authors" ]; then
        bullet2="Écrit par $authors"
    elif [ ! -z "$publisher" ]; then
        bullet2="Édité par $publisher"
    else
        bullet2="Édition française"
    fi
    
    # Bullet 3 : État
    if [ ! -z "$condition" ]; then
        bullet3="État : $condition - Livre d'occasion vérifié"
    else
        bullet3="Livre d'occasion en très bon état"
    fi
    
    # Bullet 4 : Langue et date
    if [ ! -z "$language" ] && [ ! -z "$date" ]; then
        bullet4="Langue : $([ "$language" = "fr" ] && echo "Français" || echo "$language") - Publié en $date"
    elif [ ! -z "$language" ]; then
        bullet4="Livre en $([ "$language" = "fr" ] && echo "français" || echo "$language")"
    elif [ ! -z "$date" ]; then
        bullet4="Date de publication : $date"
    else
        bullet4="Livre en français"
    fi
    
    # Bullet 5 : ISBN et dimensions
    if [ ! -z "$isbn" ] && [ ! -z "$dimensions" ]; then
        bullet5="ISBN : $isbn - Dimensions : $dimensions cm"
    elif [ ! -z "$isbn" ]; then
        bullet5="ISBN : $isbn - Authenticité garantie"
    elif [ ! -z "$dimensions" ]; then
        bullet5="Dimensions : $dimensions cm"
    else
        bullet5="Envoi rapide et soigné"
    fi
    
    # Sauvegarder les bullet points
    safe_store_meta "$post_id" "_calculated_bullet1" "$bullet1"
    safe_store_meta "$post_id" "_calculated_bullet2" "$bullet2"
    safe_store_meta "$post_id" "_calculated_bullet3" "$bullet3"
    safe_store_meta "$post_id" "_calculated_bullet4" "$bullet4"
    safe_store_meta "$post_id" "_calculated_bullet5" "$bullet5"
    
    echo "[DEBUG] Bullet points générés" >&2
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
}

# Fonction pour calculer le score d'export
calculate_export_score() {
    local post_id="$1"
    [ -z "$post_id" ] && { echo "[ERROR] calculate_export_score: post_id requis"; return 1; }
    
    echo "[DEBUG] Calcul du score d'export pour #$post_id..." >&2
    
    local score=0
    local max_score=0
    local missing=""
    
    # Vérifier chaque champ obligatoire
    local fields=(
        "_best_title:5:Titre"
        "_price:5:Prix"
        "_isbn:5:ISBN"
        "_best_cover_image:5:Image"
        "_best_description:5:Description"
        "_best_authors:3:Auteur"
        "_best_publisher:3:Éditeur"
        "_book_condition:3:État"
        "_stock:3:Stock"
        "_best_pages:1:Pages"
        "_calculated_weight:1:Poids"
        "_calculated_dimensions:1:Dimensions"
        "_g_categories:1:Catégories"
        "_vinted_condition:1:Condition Vinted"
        "_cat_vinted:1:Catégorie Vinted"
    )
    
    for field_info in "${fields[@]}"; do
        IFS=':' read -r field weight label <<< "$field_info"
        ((max_score += weight))
        
        local value=$(get_meta_value "$post_id" "$field")
        if [ ! -z "$value" ] && [ "$value" != "0" ] && [ "$value" != "null" ]; then
            ((score += weight))
        else
            missing="${missing}$label, "
        fi
    done
    
    # Enlever la dernière virgule
    missing="${missing%, }"
    
    # Sauvegarder le score
    safe_store_meta "$post_id" "_export_score" "$score"
    safe_store_meta "$post_id" "_export_max_score" "$max_score"
    safe_store_meta "$post_id" "_missing_data" "$missing"
    
    echo "[DEBUG] Score d'export: $score/$max_score" >&2
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$post_id"
    fi
}

# Fonction pour capturer l'état d'un livre
capture_book_state() {
    local id=$1
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_key FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id 
        AND meta_key LIKE '\_%' 
        AND meta_value != ''
        AND meta_value IS NOT NULL"
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$id"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$id"
    fi
}

# Fonction pour formater la progression
format_progression() {
    local gain=$1
    if [ $gain -gt 0 ]; then
        echo "✅ +$gain"
    elif [ $gain -lt 0 ]; then
        echo "❌ $gain"
    else
        echo "➖ Aucun gain"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$1"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$1"
    fi
}
echo "[END: isbn_functions.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
