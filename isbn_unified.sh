#!/bin/bash
# Script unifié de gestion ISBN - Version MARTINGALE COMPLÈTE
# Gère la collecte, l'analyse et l'enrichissement EXHAUSTIF des données

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"
source "$SCRIPT_DIR/lib/marketplace/amazon.sh"
source "$SCRIPT_DIR/lib/marketplace/rakuten.sh"
source "$SCRIPT_DIR/lib/marketplace/vinted.sh"
source "$SCRIPT_DIR/lib/marketplace/fnac.sh"
source "$SCRIPT_DIR/lib/marketplace/cdiscount.sh"
source "$SCRIPT_DIR/lib/marketplace/leboncoin.sh"

# Variables globales
FORCE_MODE=""
MODE=""
LIMIT=""
PARAM_ISBN=""
PARAM_PRICE=""
PARAM_CONDITION=""
PARAM_STOCK=""

# Définir LOG_FILE
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/isbn_unified_$(date +%Y%m%d_%H%M%S).log"

# Variables globales pour les options
FORCE_COLLECT=0
VERBOSE=0

# Couleurs ANSI pour affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Fonction get_meta_value (depuis safe_functions.sh)
get_meta_value() {
    local post_id="$1"
    local meta_key="$2"
    [ -z "$post_id" ] || [ -z "$meta_key" ] && return 1
    
    local value=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value 
        FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id 
        AND meta_key='$meta_key' 
        LIMIT 1" 2>/dev/null)
    
    # Si vide ou null, retourner vide
    if [ -z "$value" ] || [ "$value" = "null" ] || [ "$value" = "NULL" ]; then
        echo ""
    else
        echo "$value"
    fi
}

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
}

# Fonction d'aide
show_help() {
    cat << EOF
══════════════════════════════════════════════════════════════════════════════════════════════
                             📚 ISBN UNIFIED - Script complet
══════════════════════════════════════════════════════════════════════════════════════════════

UTILISATION :
    ./isbn_unified.sh [OPTIONS] [ISBN] [prix] [état] [stock]

OPTIONS :
    -h, --help          Afficher cette aide
    -force              Forcer la collecte même si déjà fait
    -notableau          Mode compact sans tableaux détaillés
    -simple             Mode très simplifié (ID et titre uniquement)
    -vendu              Marquer le livre comme vendu
    -nostatus           Ne pas afficher le statut de collecte
    -p[N]               Traiter les N prochains livres sans données
    -export             Exporter vers les marketplaces

PARAMÈTRES :
    ISBN               Code ISBN ou ID du produit (optionnel si mode -p)
    prix               Prix de vente en euros (optionnel)
    état               1=Neuf avec étiquette, 2=Neuf, 3=Très bon, 4=Bon, 5=Correct, 6=Passable
    stock              Quantité en stock (défaut: 1)

EXEMPLES :
    ./isbn_unified.sh                         # Mode interactif
    ./isbn_unified.sh 9782070368228          # Analyse simple
    ./isbn_unified.sh 9782070368228 7.50     # Avec prix
    ./isbn_unified.sh 9782070368228 7.50 3 1 # Complet
    ./isbn_unified.sh -p10                   # 10 prochains livres
    ./isbn_unified.sh -vendu 12345           # Marquer vendu
    ./isbn_unified.sh -force 12345           # Forcer collecte

══════════════════════════════════════════════════════════════════════════════════════════════
EOF
}

# Parser les options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -force)
            FORCE_MODE="force"
            shift
            ;;
        -notableau)
            MODE="notableau"
            shift
            ;;
        -simple)
            MODE="simple"
            shift
            ;;
        -vendu)
            MODE="vendu"
            shift
            ;;
        -nostatus)
            MODE="nostatus"
            shift
            ;;
        -p*)
            MODE="batch"
            LIMIT="${1#-p}"
            shift
            ;;
        -export)
            MODE="export"
            shift
            ;;
        *)
            if [ -z "$PARAM_ISBN" ]; then
                PARAM_ISBN="$1"
            elif [ -z "$PARAM_PRICE" ]; then
                PARAM_PRICE="$1"
            elif [ -z "$PARAM_CONDITION" ]; then
                PARAM_CONDITION="$1"
            elif [ -z "$PARAM_STOCK" ]; then
                PARAM_STOCK="$1"
            fi
            shift
            ;;
    esac
done

# Fonction pour appliquer TOUTES les métadonnées de la martingale
apply_martingale_metadata() {
    local post_id="$1"
    [ -z "$post_id" ] && { echo "[ERROR] apply_martingale_metadata: post_id requis"; return 1; }
    
    echo "[DEBUG] Application de TOUTES les métadonnées martingale pour #$post_id..." >&2
    
    # === VALEURS PAR DÉFAUT OBLIGATOIRES ===
    
    # Prix et stock
    local price=$(get_meta_value "$post_id" "_price")
    if [ -z "$price" ] || [ "$price" = "0" ]; then
        safe_store_meta "$post_id" "_price" "0"
        safe_store_meta "$post_id" "_regular_price" "0"
    else
        safe_store_meta "$post_id" "_regular_price" "$price"
    fi
    
    # Stock
    local stock=$(get_meta_value "$post_id" "_stock")
    [ -z "$stock" ] && safe_store_meta "$post_id" "_stock" "1"
    safe_store_meta "$post_id" "_stock_status" "instock"
    safe_store_meta "$post_id" "_manage_stock" "yes"
    safe_store_meta "$post_id" "_backorders" "no"
    safe_store_meta "$post_id" "_sold_individually" "yes"
    
    # Métadonnées produit
    safe_store_meta "$post_id" "_product_type" "simple"
    safe_store_meta "$post_id" "_visibility" "visible"
    safe_store_meta "$post_id" "_featured" "no"
    safe_store_meta "$post_id" "_virtual" "no"
    safe_store_meta "$post_id" "_downloadable" "no"
    safe_store_meta "$post_id" "_tax_status" "taxable"
    safe_store_meta "$post_id" "_tax_class" "reduced-rate"
    
    # État du livre
    local condition=$(get_meta_value "$post_id" "_book_condition")
    if [ -z "$condition" ]; then
        safe_store_meta "$post_id" "_book_condition" "très bon"
        safe_store_meta "$post_id" "_vinted_condition" "3"
        safe_store_meta "$post_id" "_vinted_condition_text" "3 - Très bon état"
    else
        # Mapper la condition Vinted
        case "$condition" in
            "Neuf avec étiquette") 
                safe_store_meta "$post_id" "_vinted_condition" "1"
                safe_store_meta "$post_id" "_vinted_condition_text" "1 - Neuf avec étiquette"
                ;;
            "Neuf sans étiquette"|"Neuf")
                safe_store_meta "$post_id" "_vinted_condition" "2"
                safe_store_meta "$post_id" "_vinted_condition_text" "2 - Neuf sans étiquette"
                ;;
            "Très bon état"|"très bon")
                safe_store_meta "$post_id" "_vinted_condition" "3"
                safe_store_meta "$post_id" "_vinted_condition_text" "3 - Très bon état"
                ;;
            "Bon état"|"bon")
                safe_store_meta "$post_id" "_vinted_condition" "4"
                safe_store_meta "$post_id" "_vinted_condition_text" "4 - Bon état"
                ;;
            *)
                safe_store_meta "$post_id" "_vinted_condition" "5"
                safe_store_meta "$post_id" "_vinted_condition_text" "5 - Satisfaisant"
                ;;
        esac
    fi
    
    # Catégories Vinted
    safe_store_meta "$post_id" "_cat_vinted" "1601"
    safe_store_meta "$post_id" "_vinted_category_id" "1601"
    safe_store_meta "$post_id" "_vinted_category_name" "Livres"
    
    # Localisation
    safe_store_meta "$post_id" "_location_zip" "76000"
    safe_store_meta "$post_id" "_location_city" "Rouen"
    safe_store_meta "$post_id" "_location_country" "FR"
    
    # Identifiants
    local isbn=$(get_meta_value "$post_id" "_isbn")
    if [ -n "$isbn" ]; then
        safe_store_meta "$post_id" "_sku" "$isbn"
        safe_store_meta "$post_id" "_ean" "$isbn"
        # Si ISBN13
        if [[ "$isbn" =~ ^[0-9]{13}$ ]]; then
            safe_store_meta "$post_id" "_isbn13" "$isbn"
        # Si ISBN10
        elif [[ "$isbn" =~ ^[0-9]{10}$ ]]; then
            safe_store_meta "$post_id" "_isbn10" "$isbn"
        fi
    fi
    
    # Catégories marketplaces par défaut
    safe_store_meta "$post_id" "_leboncoin_category" "27"
    safe_store_meta "$post_id" "_leboncoin_phone_hidden" "true"
    safe_store_meta "$post_id" "_fnac_tva_rate" "5.5"
    safe_store_meta "$post_id" "_rakuten_state" "10"
    safe_store_meta "$post_id" "_ebay_condition_id" "4"
    
    # Langue par défaut
    local language=$(get_meta_value "$post_id" "_g_language")
    [ -z "$language" ] && safe_store_meta "$post_id" "_g_language" "fr"
    
    # Métadonnées système
    safe_store_meta "$post_id" "_has_description" "1"
    safe_store_meta "$post_id" "_collection_status" "completed"
    safe_store_meta "$post_id" "_last_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    safe_store_meta "$post_id" "_api_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    safe_store_meta "$post_id" "_last_analyze_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Copier dimensions calculées vers dimensions WooCommerce
    local calc_length=$(get_meta_value "$post_id" "_calculated_length")
    local calc_width=$(get_meta_value "$post_id" "_calculated_width")
    local calc_height=$(get_meta_value "$post_id" "_calculated_height")
    local calc_weight=$(get_meta_value "$post_id" "_calculated_weight")
    
    [ -n "$calc_length" ] && safe_store_meta "$post_id" "_length" "$calc_length"
    [ -n "$calc_width" ] && safe_store_meta "$post_id" "_width" "$calc_width"
    [ -n "$calc_height" ] && safe_store_meta "$post_id" "_height" "$calc_height"
    [ -n "$calc_weight" ] && safe_store_meta "$post_id" "_weight" "$calc_weight"
    
    echo "[DEBUG] Métadonnées martingale appliquées" >&2
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
}

# Fonction pour générer les métadonnées marketplaces
generate_marketplace_metadata() {
    local post_id="$1"
    [ -z "$post_id" ] && { echo "[ERROR] generate_marketplace_metadata: post_id requis"; return 1; }
    
    echo "[DEBUG] Génération des métadonnées marketplaces pour #$post_id..." >&2
    
    # Récupérer les données de base
    local title=$(get_meta_value "$post_id" "_best_title")
    local authors=$(get_meta_value "$post_id" "_best_authors")
    local publisher=$(get_meta_value "$post_id" "_best_publisher")
    local categories=$(get_meta_value "$post_id" "_g_categories")
    
    # Amazon
    safe_store_meta "$post_id" "_amazon_keywords" "$title $authors $publisher"
    safe_store_meta "$post_id" "_amazon_search_terms" "$title, $authors, $publisher, $categories"
    
    # Rakuten
    safe_store_meta "$post_id" "_rakuten_state" "10"
    
    # Fnac
    safe_store_meta "$post_id" "_fnac_tva_rate" "5.5"
    
    # Cdiscount
    [ ! -z "$publisher" ] && safe_store_meta "$post_id" "_cdiscount_brand" "$publisher"
    
    # Leboncoin
    safe_store_meta "$post_id" "_leboncoin_category" "27"
    safe_store_meta "$post_id" "_leboncoin_phone_hidden" "true"
    
    # eBay
    safe_store_meta "$post_id" "_ebay_condition_id" "4"
    
    echo "[DEBUG] Métadonnées marketplaces générées" >&2
}

# Fonctions spécifiques aux modes
mark_as_sold() {
    local input="$1"
    
    # Déterminer si c'est un ID ou ISBN
    if [[ "$input" =~ ^[0-9]+$ ]] && [ ${#input} -lt 10 ]; then
        local id="$input"
    else
        local isbn="${input//[^0-9]/}"
        local id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT ID FROM wp_${SITE_ID}_posts 
            WHERE post_type='product' 
            AND post_status='publish' 
            AND ID IN (
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key='_sku' AND meta_value='$isbn'
            )
            LIMIT 1")
    fi
    
    if [ -z "$id" ]; then
        echo "❌ Livre non trouvé"
        return 1
    fi
    
    # Mettre à jour le stock
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        UPDATE wp_${SITE_ID}_postmeta 
        SET meta_value='0' 
        WHERE post_id=$id AND meta_key='_stock';"
    
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        UPDATE wp_${SITE_ID}_postmeta 
        SET meta_value='outofstock' 
        WHERE post_id=$id AND meta_key='_stock_status';"
    
    echo "✅ Livre #$id marqué comme VENDU"
}

process_batch() {
    local limit="${1:-10}"
    
    echo "🔄 Recherche de $limit livres sans données..."
    
    local books=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT p.ID, pm.meta_value as isbn
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm ON p.ID = pm.post_id
        LEFT JOIN wp_${SITE_ID}_postmeta pm2 ON p.ID = pm2.post_id AND pm2.meta_key = '_collection_status'
        WHERE p.post_type = 'product'
        AND p.post_status = 'publish'
        AND pm.meta_key = '_sku'
        AND pm.meta_value != ''
        AND (pm2.meta_value IS NULL OR pm2.meta_value != 'completed')
        ORDER BY p.ID DESC
        LIMIT $limit")
    
    if [ -z "$books" ]; then
        echo "❌ Aucun livre à traiter"
        return 1
    fi
    
    local count=0
    while IFS=$'\t' read -r id isbn; do
        ((count++))
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📚 Livre $count/$limit - ID: $id, ISBN: $isbn"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Traiter ce livre
        process_single_book "$id"
        
        echo ""
        echo "⏸  Pause de 2 secondes..."
        sleep 2
    done <<< "$books"
    
    echo ""
    echo "✅ Traitement terminé : $count livres traités"
}

# Fonction pour traiter un livre unique avec MARTINGALE COMPLÈTE
process_single_book() {
    local input="$1"
    local price="$2"
    local condition="$3"
    local stock="${4:-1}"
    
    # Debug
    echo "[DEBUG] process_single_book: input=$input, price=$price, condition=$condition, stock=$stock"
    
    # Déterminer si c'est un ID ou ISBN
    if [[ "$input" =~ ^[0-9]+$ ]] && [ ${#input} -lt 10 ]; then
        local id="$input"
        local isbn=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT meta_value FROM wp_${SITE_ID}_postmeta 
            WHERE post_id=$id AND meta_key='_sku' LIMIT 1")
    else
        local isbn="${input//[^0-9]/}"
        local id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT ID FROM wp_${SITE_ID}_posts 
            WHERE post_type='product' 
            AND post_status='publish' 
            AND ID IN (
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key='_sku' AND meta_value='$isbn'
            )
            LIMIT 1")
    fi
    
    if [ -z "$id" ] || [ -z "$isbn" ]; then
        echo "❌ Livre non trouvé"
        return 1
    fi
    
    # === ÉTAPE 1 : APPLIQUER LES VALEURS MANUELLES ===
    if [ -n "$price" ]; then
        echo "[DEBUG] Mise à jour du prix : $price €"
        safe_store_meta "$id" "_price" "$price"
        safe_store_meta "$id" "_regular_price" "$price"
    fi
    
    if [ -n "$condition" ]; then
        echo "[DEBUG] Mise à jour de l'état : $condition"
        local book_condition=""
        local vinted_condition=""
        local vinted_text=""
        
        case "$condition" in
            1) 
                book_condition="Neuf avec étiquette"
                vinted_condition="1"
                vinted_text="1 - Neuf avec étiquette"
                ;;
            2) 
                book_condition="Neuf sans étiquette"
                vinted_condition="2"
                vinted_text="2 - Neuf sans étiquette"
                ;;
            3) 
                book_condition="Très bon état"
                vinted_condition="3"
                vinted_text="3 - Très bon état"
                ;;
            4) 
                book_condition="Bon état"
                vinted_condition="4"
                vinted_text="4 - Bon état"
                ;;
            5) 
                book_condition="État correct"
                vinted_condition="5"
                vinted_text="5 - Satisfaisant"
                ;;
            6) 
                book_condition="État passable"
                vinted_condition="5"
                vinted_text="5 - Satisfaisant"
                ;;
        esac
        
        if [ -n "$book_condition" ]; then
            safe_store_meta "$id" "_book_condition" "$book_condition"
            safe_store_meta "$id" "_vinted_condition" "$vinted_condition"
            safe_store_meta "$id" "_vinted_condition_text" "$vinted_text"
        fi
    fi
    
    if [ -n "$stock" ]; then
        echo "[DEBUG] Mise à jour du stock : $stock"
        safe_store_meta "$id" "_stock" "$stock"
        safe_store_meta "$id" "_manage_stock" "yes"
        
        if [ "$stock" -gt 0 ]; then
            safe_store_meta "$id" "_stock_status" "instock"
        else
            safe_store_meta "$id" "_stock_status" "outofstock"
        fi
    fi
    
    # === ÉTAPE 2 : APPLIQUER TOUTES LES MÉTADONNÉES MARTINGALE ===
    apply_martingale_metadata "$id"
    
    # === ÉTAPE 3 : CATÉGORISATION AUTOMATIQUE ===
    echo ""
    echo "🤖 CATÉGORISATION AUTOMATIQUE"
    echo "══════════════════════════════════════════════════════════════"
    
    local existing_categories=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) 
        FROM wp_${SITE_ID}_term_relationships tr
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        WHERE tr.object_id = $id 
        AND tt.taxonomy = 'product_cat'
        AND tt.term_id NOT IN (3088, 3089)")
    
    if [ "$existing_categories" -eq 0 ]; then
        echo "📚 Aucune catégorie trouvée, lancement de la catégorisation..."
        
        if [ -f "$SCRIPT_DIR/smart_categorize_dual_ai.sh" ]; then
            "$SCRIPT_DIR/smart_categorize_dual_ai.sh" "$id"
            echo ""
            echo "✅ Catégorisation terminée"
        else
            echo "⚠️  Script de catégorisation non trouvé"
        fi
    else
        echo "✅ Le livre a déjà $existing_categories catégorie(s)"
    fi
    
    # === ÉTAPE 4 : AFFICHAGE AVANT ===
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📚 ANALYSE COMPLÈTE AVEC COLLECTE - ISBN: $isbn"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Capturer l'état AVANT
    local before_data=$(capture_book_state "$id")
    local before_count=$(echo "$before_data" | grep -c "^_")
    
    # Afficher section AVANT
    if [ -f "$SCRIPT_DIR/lib/analyze_before.sh" ]; then
        source "$SCRIPT_DIR/lib/analyze_before.sh"
        show_before_state "$id" "$isbn"
    fi
    
    # === ÉTAPE 5 : COLLECTE DES DONNÉES ===
    local collection_status=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key='_collection_status' LIMIT 1")
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "🔄 LANCEMENT DE LA COLLECTE"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    if [ "$collection_status" = "completed" ] && [ "$FORCE_MODE" != "force" ]; then
        echo "ℹ️  CE LIVRE A DÉJÀ ÉTÉ ANALYSÉ"
        echo "💡 Utilisez -force pour forcer une nouvelle collecte"
    else
        # Lancer la collecte COMPLÈTE
        echo "[DEBUG] Début collecte MARTINGALE pour produit #$id - ISBN: $isbn"
        
        # Marquer les timestamps de début
        safe_store_meta "$id" "_google_last_attempt" "$(date '+%Y-%m-%d %H:%M:%S')"
        safe_store_meta "$id" "_isbndb_last_attempt" "$(date '+%Y-%m-%d %H:%M:%S')"
        safe_store_meta "$id" "_openlibrary_last_attempt" "$(date '+%Y-%m-%d %H:%M:%S')"
        
        # Appeler les APIs
        if [ -f "$SCRIPT_DIR/apis/google_books.sh" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]   → Google Books API..." | tee -a "$LOG_FILE"
            source "$SCRIPT_DIR/apis/google_books.sh"
            fetch_google_books "$isbn" "$id" 2>&1 | tee -a "$LOG_FILE"
        fi

        if [ -f "$SCRIPT_DIR/apis/isbndb.sh" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]   → ISBNdb API..." | tee -a "$LOG_FILE"
            source "$SCRIPT_DIR/apis/isbndb.sh"
            fetch_isbndb "$isbn" "$id" 2>&1 | tee -a "$LOG_FILE"
        fi

        if [ -f "$SCRIPT_DIR/apis/open_library.sh" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]   → Open Library API..." | tee -a "$LOG_FILE"
            source "$SCRIPT_DIR/apis/open_library.sh"
            fetch_open_library "$isbn" "$id" 2>&1 | tee -a "$LOG_FILE"
        fi

        # === ÉTAPE 6 : SÉLECTION DES MEILLEURES DONNÉES ===
        echo "[DEBUG] Sélection des meilleures données..."
        select_best_data "$id"

        # === ÉTAPE 7 : CALCULS AUTOMATIQUES ===
        echo "[DEBUG] Calcul du poids et dimensions..."
        calculate_weight_dimensions "$id"

        # === ÉTAPE 8 : GÉNÉRATION DES BULLET POINTS ===
        echo "[DEBUG] Génération des bullet points..."
        generate_bullet_points "$id"
        
        # === ÉTAPE 9 : GÉNÉRATION DESCRIPTION IA SI NÉCESSAIRE ===
        local has_description=$(get_meta_value "$id" "_has_description")
        local best_desc=$(get_meta_value "$id" "_best_description")
        
        if [ "$has_description" != "1" ] || [ -z "$best_desc" ] || [ ${#best_desc} -lt 20 ]; then
            echo "[DEBUG] Génération description IA nécessaire..."
            
            # Récupérer les données pour l'IA
            local final_title=$(get_meta_value "$id" "_best_title")
            local final_authors=$(get_meta_value "$id" "_best_authors")
            local final_publisher=$(get_meta_value "$id" "_best_publisher")
            local final_pages=$(get_meta_value "$id" "_best_pages")
            local final_binding=$(get_meta_value "$id" "_best_binding")
            local categories=$(get_meta_value "$id" "_g_categories")
            
            if [ -f "$SCRIPT_DIR/apis/claude_ai.sh" ]; then
                echo "[DEBUG] Appel Claude AI pour génération description..."
                source "$SCRIPT_DIR/apis/claude_ai.sh"
                if claude_desc=$(generate_description_claude "$isbn" "$id" "$final_title" "$final_authors" "$final_publisher" "$final_pages" "$final_binding" "$categories" 2>&1); then
                    safe_store_meta "$id" "_best_description" "$claude_desc"
                    safe_store_meta "$id" "_best_description_source" "claude_ai"
                    safe_store_meta "$id" "_has_description" "1"
                    echo "[DEBUG] ✓ Claude : description générée"
                else
                    echo "[DEBUG] ✗ Claude : échec génération"
                    # Essayer Groq en fallback
                    if [ -f "$SCRIPT_DIR/apis/groq_ai.sh" ]; then
                        echo "[DEBUG] Appel Groq AI en fallback..."
                        source "$SCRIPT_DIR/apis/groq_ai.sh"
                        if groq_desc=$(generate_description_groq "$isbn" "$id" "$final_title" "$final_authors" "$final_publisher" "$final_pages" "$final_binding" "$categories" 2>&1); then
                            safe_store_meta "$id" "_best_description" "$groq_desc"
                            safe_store_meta "$id" "_best_description_source" "groq_ai"
                            safe_store_meta "$id" "_has_description" "1"
                            echo "[DEBUG] ✓ Groq : description générée"
                        fi
                    fi
                fi
            fi
        fi
        
        # === ÉTAPE 10 : GÉNÉRATION DES MÉTADONNÉES MARKETPLACES ===
        echo "[DEBUG] Génération des métadonnées marketplaces..."
        generate_marketplace_metadata "$id"
        
        # === ÉTAPE 11 : CALCUL DU SCORE D'EXPORT ===
        echo "[DEBUG] Calcul du score d'export..."
        calculate_export_score "$id"
        
        # === ÉTAPE 12 : APPLICATION FINALE DES MÉTADONNÉES ===
        echo "[DEBUG] Application finale des métadonnées martingale..."
        apply_martingale_metadata "$id"
        
        # Marquer la collecte comme terminée
        safe_store_meta "$id" "_collection_status" "completed"
        safe_store_meta "$id" "_last_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
        safe_store_meta "$id" "_api_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
        safe_store_meta "$id" "_last_analyze_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    # === ÉTAPE 13 : AFFICHAGE DES RÉSULTATS ===
    
    # Capturer l'état APRÈS
    local after_data=$(capture_book_state "$id")
    local after_count=$(echo "$after_data" | grep -c "^_")
    
    # Afficher section COLLECTE
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "🔄 SECTION 2 : COLLECTE DES DONNÉES VIA APIs"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    show_api_results "$id"
    
    # Afficher section APRÈS avec requirements
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📊 SECTION 3 : RÉSULTAT APRÈS COLLECTE ET EXPORTABILITÉ"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    if [ -f "$SCRIPT_DIR/lib/analyze_after.sh" ]; then
        source "$SCRIPT_DIR/lib/analyze_after.sh"
        show_after_state "$id" "$isbn"
    fi
    
    # Afficher le résumé des gains
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📈 RÉSUMÉ DES GAINS DE LA COLLECTE"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Calculer et afficher les gains
    local total_gain=$((after_count - before_count))
    
    if [ $total_gain -gt 0 ]; then
        echo "✅ Collecte réussie : +$total_gain nouvelles données"
    else
        echo "ℹ️  Aucune nouvelle donnée collectée"
    fi
    
    # === ÉTAPE 14 : VÉRIFICATION FINALE DES DONNÉES MARTINGALE ===
    echo ""
    echo "🔍 VÉRIFICATION MARTINGALE COMPLÈTE"
    echo "══════════════════════════════════════════════════════════════"
    
    local complete_fields=0
    local total_fields=0
    local missing_critical=""
    
    # Liste de TOUS les champs à vérifier
    local martingale_fields=(
        "_best_title:CRITIQUE"
        "_best_authors:IMPORTANT"
        "_best_publisher:IMPORTANT"
        "_best_description:CRITIQUE"
        "_best_pages:NORMAL"
        "_best_binding:NORMAL"
        "_best_cover_image:CRITIQUE"
        "_price:CRITIQUE"
        "_regular_price:CRITIQUE"
        "_stock:IMPORTANT"
        "_stock_status:IMPORTANT"
        "_manage_stock:NORMAL"
        "_book_condition:IMPORTANT"
        "_vinted_condition:IMPORTANT"
        "_vinted_condition_text:NORMAL"
        "_cat_vinted:IMPORTANT"
        "_vinted_category_id:IMPORTANT"
        "_vinted_category_name:NORMAL"
        "_calculated_weight:IMPORTANT"
        "_calculated_dimensions:IMPORTANT"
        "_calculated_length:NORMAL"
        "_calculated_width:NORMAL"
        "_calculated_height:NORMAL"
        "_calculated_bullet1:NORMAL"
        "_calculated_bullet2:NORMAL"
        "_calculated_bullet3:NORMAL"
        "_calculated_bullet4:NORMAL"
        "_calculated_bullet5:NORMAL"
        "_location_zip:IMPORTANT"
        "_location_city:NORMAL"
        "_location_country:NORMAL"
        "_isbn:CRITIQUE"
        "_sku:CRITIQUE"
        "_collection_status:CRITIQUE"
        "_has_description:NORMAL"
        "_export_score:IMPORTANT"
        "_export_max_score:IMPORTANT"
    )
    
    for field_info in "${martingale_fields[@]}"; do
        IFS=':' read -r field importance <<< "$field_info"
        ((total_fields++))
        
        local value=$(get_meta_value "$id" "$field")
        if [ ! -z "$value" ] && [ "$value" != "0" ] && [ "$value" != "null" ]; then
            ((complete_fields++))
        else
            if [ "$importance" = "CRITIQUE" ]; then
                missing_critical="${missing_critical}$field, "
            fi
        fi
    done
    
    local completion_rate=$((complete_fields * 100 / total_fields))
    
    echo "Champs remplis : $complete_fields / $total_fields ($completion_rate%)"
    
    if [ -n "$missing_critical" ]; then
        echo -e "${RED}❌ CHAMPS CRITIQUES MANQUANTS : ${missing_critical%, }${NC}"
    fi
    
    if [ $completion_rate -eq 100 ]; then
        echo -e "${GREEN}✅ MARTINGALE COMPLÈTE : 100% des données collectées !${NC}"
    elif [ $completion_rate -gt 90 ]; then
        echo -e "${YELLOW}⚠️  MARTINGALE PRESQUE COMPLÈTE : $completion_rate%${NC}"
    else
        echo -e "${RED}❌ MARTINGALE INCOMPLÈTE : $completion_rate%${NC}"
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
}

# Fonction pour afficher les résultats des APIs
show_api_results() {
    local id=$1
    
    # Google Books
    echo ""
    echo "🔵 GOOGLE BOOKS API"
    local g_test=$(get_meta_value "$id" "_g_title")
    local google_timestamp=$(get_meta_timestamp "$id" "_google_last_attempt")
    
    if [ -n "$g_test" ]; then
        echo "✅ Statut : Données collectées avec succès"
        echo -e "${CYAN}⏰ Collecté le : $google_timestamp${NC}"
    else
        local google_attempt=$(get_meta_value "$id" "_google_last_attempt")
        if [ -n "$google_attempt" ]; then
            echo "⚠️  Statut : Aucune donnée trouvée pour cet ISBN"
            echo -e "${YELLOW}⏰ Dernière tentative : $google_attempt${NC}"
        else
            echo "❌ Statut : Jamais collecté"
        fi
    fi
    
    # ISBNdb
    echo ""
    echo "🟢 ISBNDB API"
    local i_test=$(get_meta_value "$id" "_i_title")
    local isbndb_timestamp=$(get_meta_timestamp "$id" "_isbndb_last_attempt")
    
    if [ -n "$i_test" ]; then
        echo "✅ Statut : Données collectées avec succès"
        echo -e "${CYAN}⏰ Collecté le : $isbndb_timestamp${NC}"
    else
        local isbndb_attempt=$(get_meta_value "$id" "_isbndb_last_attempt")
        if [ -n "$isbndb_attempt" ]; then
            echo "⚠️  Statut : Aucune donnée trouvée pour cet ISBN"
            echo -e "${YELLOW}⏰ Dernière tentative : $isbndb_attempt${NC}"
        else
            echo "❌ Statut : Jamais collecté"
        fi
    fi
    
    # Open Library
    echo ""
    echo "🟠 OPEN LIBRARY API"
    local o_test=$(get_meta_value "$id" "_o_title")
    local openlibrary_timestamp=$(get_meta_timestamp "$id" "_openlibrary_last_attempt")
    
    if [ -n "$o_test" ]; then
        echo "✅ Statut : Données collectées avec succès"
        echo -e "${CYAN}⏰ Collecté le : $openlibrary_timestamp${NC}"
    else
        local openlibrary_attempt=$(get_meta_value "$id" "_openlibrary_last_attempt")
        if [ -n "$openlibrary_attempt" ]; then
            echo "⚠️  Statut : Aucune donnée trouvée pour cet ISBN"
            echo -e "${YELLOW}⏰ Dernière tentative : $openlibrary_attempt${NC}"
        else
            echo "❌ Statut : Jamais collecté"
        fi
    fi
    
    # Claude AI
    echo ""
    echo "🤖 CLAUDE AI"
    local claude_desc=$(get_meta_value "$id" "_claude_description")
    
    if [ -n "$claude_desc" ] && [ ${#claude_desc} -gt 20 ]; then
        echo "✅ Statut : Description générée avec succès"
        echo -e "${CYAN}📝 Longueur : ${#claude_desc} caractères${NC}"
    else
        echo "❌ Statut : Pas de description Claude"
    fi
    
    # Groq AI
    echo ""
    echo "🧠 GROQ AI"
    local groq_desc=$(get_meta_value "$id" "_groq_description")
    
    if [ -n "$groq_desc" ] && [ ${#groq_desc} -gt 20 ]; then
        echo "✅ Statut : Description générée avec succès"
        echo -e "${CYAN}📝 Longueur : ${#groq_desc} caractères${NC}"
    else
        echo "❌ Statut : Pas de description Groq"
    fi
}

# === PROGRAMME PRINCIPAL ===

# Si aucun paramètre, afficher l'aide
if [ -z "$MODE" ] && [ -z "$PARAM_ISBN" ]; then
    show_help
    exit 0
fi

# Traiter selon le mode
case "$MODE" in
    vendu)
        mark_as_sold "$PARAM_ISBN"
        ;;
    batch)
        process_batch "$LIMIT"
        ;;
    export)
        echo "🚀 Mode export vers marketplaces"
        if [ -n "$PARAM_ISBN" ]; then
            # Export d'un seul livre
            echo "Export du livre $PARAM_ISBN..."
            # TODO: Implémenter l'export
        else
            # Export en masse
            echo "Export en masse..."
            # TODO: Implémenter l'export en masse
        fi
        ;;
    *)
        # Mode normal : traiter un livre
        if [ -n "$PARAM_ISBN" ]; then
            process_single_book "$PARAM_ISBN" "$PARAM_PRICE" "$PARAM_CONDITION" "$PARAM_STOCK"
        else
            echo "❌ ISBN requis"
            show_help
            exit 1
        fi
        ;;
esac