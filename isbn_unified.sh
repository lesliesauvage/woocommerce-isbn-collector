#!/bin/bash
# Script unifié de gestion ISBN - Version complète
# Gère la collecte, l'analyse et l'enrichissement des données

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

# Debug des paramètres
echo "[DEBUG] Paramètres: input=$PARAM_ISBN, price=$PARAM_PRICE, condition=$PARAM_CONDITION, stock=$PARAM_STOCK"

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
    
    # Sélectionner le meilleur titre (priorité : ISBNdb > Google > OpenLibrary)
    local best_title=""
    if [ ! -z "$i_title" ] && [ "$i_title" != "null" ]; then
        best_title="$i_title"
    elif [ ! -z "$g_title" ] && [ "$g_title" != "null" ]; then
        best_title="$g_title"
    elif [ ! -z "$o_title" ] && [ "$o_title" != "null" ]; then
        best_title="$o_title"
    fi
    
    # Sélectionner les meilleurs auteurs
    local best_authors=""
    if [ ! -z "$i_authors" ] && [ "$i_authors" != "null" ]; then
        best_authors="$i_authors"
    elif [ ! -z "$g_authors" ] && [ "$g_authors" != "null" ]; then
        best_authors="$g_authors"
    elif [ ! -z "$o_authors" ] && [ "$o_authors" != "null" ]; then
        best_authors="$o_authors"
    fi
    
    # Sélectionner le meilleur éditeur
    local best_publisher=""
    if [ ! -z "$i_publisher" ] && [ "$i_publisher" != "null" ]; then
        best_publisher="$i_publisher"
    elif [ ! -z "$g_publisher" ] && [ "$g_publisher" != "null" ]; then
        best_publisher="$g_publisher"
    elif [ ! -z "$o_publishers" ] && [ "$o_publishers" != "null" ]; then
        best_publisher="$o_publishers"
    fi
    
    # Sélectionner le meilleur nombre de pages
    local best_pages=""
    if [ ! -z "$i_pages" ] && [ "$i_pages" != "null" ] && [ "$i_pages" != "0" ]; then
        best_pages="$i_pages"
    elif [ ! -z "$g_pages" ] && [ "$g_pages" != "null" ] && [ "$g_pages" != "0" ]; then
        best_pages="$g_pages"
    elif [ ! -z "$o_pages" ] && [ "$o_pages" != "null" ] && [ "$o_pages" != "0" ]; then
        best_pages="$o_pages"
    fi
    
    # Sauvegarder les meilleures données
    [ ! -z "$best_title" ] && safe_store_meta "$post_id" "_best_title" "$best_title"
    [ ! -z "$best_authors" ] && safe_store_meta "$post_id" "_best_authors" "$best_authors"
    [ ! -z "$best_publisher" ] && safe_store_meta "$post_id" "_best_publisher" "$best_publisher"
    [ ! -z "$best_pages" ] && safe_store_meta "$post_id" "_best_pages" "$best_pages"
    
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
    
    if [ ! -z "$pages" ] && [ "$pages" != "0" ]; then
        # Calcul du poids approximatif (80g par 100 pages + 50g couverture)
        local weight=$((pages * 80 / 100 + 50))
        safe_store_meta "$post_id" "_calculated_weight" "$weight"
        
        # Dimensions standard livre de poche
        safe_store_meta "$post_id" "_calculated_length" "18"
        safe_store_meta "$post_id" "_calculated_width" "11"
        
        # Épaisseur basée sur le nombre de pages (0.1cm par 10 pages)
        local thickness=$((pages / 10))
        [ $thickness -lt 1 ] && thickness=1
        safe_store_meta "$post_id" "_calculated_height" "$thickness"
        
        echo "[DEBUG] Poids: ${weight}g, Dimensions: 18x11x${thickness}cm" >&2
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
    local language=$(get_meta_value "$post_id" "_g_language")
    
    # Générer 5 bullet points
    [ ! -z "$title" ] && safe_store_meta "$post_id" "_calculated_bullet1" "Titre: $title"
    [ ! -z "$authors" ] && safe_store_meta "$post_id" "_calculated_bullet2" "Auteur(s): $authors"
    [ ! -z "$publisher" ] && safe_store_meta "$post_id" "_calculated_bullet3" "Éditeur: $publisher"
    [ ! -z "$pages" ] && safe_store_meta "$post_id" "_calculated_bullet4" "Nombre de pages: $pages"
    [ ! -z "$language" ] && safe_store_meta "$post_id" "_calculated_bullet5" "Langue: $language"
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

# Fonction pour traiter un livre unique
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
    
    # Catégorisation automatique au début
    echo ""
    echo "🤖 CATÉGORISATION AUTOMATIQUE"
    echo "══════════════════════════════════════════════════════════════"
    
    # Vérifier si le livre a déjà des catégories
    local existing_categories=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) 
        FROM wp_${SITE_ID}_term_relationships tr
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        WHERE tr.object_id = $id 
        AND tt.taxonomy = 'product_cat'
        AND tt.term_id NOT IN (3088, 3089)") # Exclure les catégories par défaut
    
    if [ "$existing_categories" -eq 0 ]; then
        echo "📚 Aucune catégorie trouvée, lancement de la catégorisation..."
        
        # Lancer la catégorisation
        if [ -f "$SCRIPT_DIR/smart_categorize_dual_ai.sh" ]; then
            "$SCRIPT_DIR/smart_categorize_dual_ai.sh" "$id"
            echo ""
            echo "✅ Catégorisation terminée"
        else
            echo "⚠️  Script de catégorisation non trouvé"
        fi
    else
        echo "✅ Le livre a déjà $existing_categories catégorie(s)"
        
        # Afficher les catégories actuelles
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            SELECT t.name as 'Catégorie'
            FROM wp_${SITE_ID}_terms t
            JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
            JOIN wp_${SITE_ID}_term_relationships tr ON tt.term_taxonomy_id = tr.term_taxonomy_id
            WHERE tr.object_id = $id 
            AND tt.taxonomy = 'product_cat'
            AND t.term_id NOT IN (3088, 3089)"
    fi
    
    echo ""
    
    # Afficher l'en-tête principal
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📚 ANALYSE COMPLÈTE AVEC COLLECTE - ISBN: $isbn"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Structure du rapport :"
    echo "  1️⃣  AVANT : État actuel avec toutes les données WordPress et métadonnées"
    echo "  2️⃣  COLLECTE : Résultats détaillés de chaque API"
    echo "  3️⃣  APRÈS : Données finales, images et exportabilité"
    echo ""
    
    # Capturer l'état AVANT
    local before_data=$(capture_book_state "$id")
    local before_count=$(echo "$before_data" | grep -c "^_")
    
    # Afficher section AVANT
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📊 SECTION 1 : ÉTAT ACTUEL DU LIVRE (AVANT COLLECTE)"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    # Appeler analyze_before.sh
    if [ -f "$SCRIPT_DIR/lib/analyze_before.sh" ]; then
        source "$SCRIPT_DIR/lib/analyze_before.sh"
        show_before_state "$id" "$isbn"
    fi
    
    # Vérifier si déjà collecté
    local collection_status=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key='_collection_status' LIMIT 1")
    
    # Lancer la collecte si nécessaire ou forcée
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "🔄 LANCEMENT DE LA COLLECTE"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    if [ "$collection_status" = "completed" ] && [ "$FORCE_MODE" != "force" ]; then
        echo "ℹ️  CE LIVRE A DÉJÀ ÉTÉ ANALYSÉ"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Toutes les APIs ont déjà été interrogées pour ce livre."
        echo "Les données sont à jour et complètes."
        echo ""
        echo "💡 Utilisez -force pour forcer une nouvelle collecte"
    else
        # Lancer la collecte
        echo "[DEBUG] Début collecte pour produit #$id - ISBN: $isbn"
        
        # Appeler les APIs avec le POST_ID et logger
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

        # Sélectionner les meilleures données
        echo "[DEBUG] Sélection des meilleures données..."
        select_best_data "$id"

        # Calculer poids et dimensions
        echo "[DEBUG] Calcul du poids et dimensions..."
        calculate_weight_dimensions "$id"

        # Générer les bullet points
        echo "[DEBUG] Génération des bullet points..."
        generate_bullet_points "$id"
        
        # Générer la description IA si pas déjà présente
        local has_description=$(get_meta_value "$id" "_has_description")
        if [ "$has_description" != "1" ] && [ -f "$SCRIPT_DIR/apis/generate_description.sh" ]; then
            echo "[DEBUG] Génération description IA..."
            "$SCRIPT_DIR/apis/generate_description.sh" "$id" 2>&1 | tee -a "$LOG_FILE"
        fi
        
        # Marquer la collecte comme terminée
        safe_store_meta "$id" "_collection_status" "completed"
        safe_store_meta "$id" "_last_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    # Gérer le prix et la condition
    if [ -n "$price" ]; then
        echo "[DEBUG] Mise à jour du prix : $price €"
        # Stocker le prix
        safe_store_meta "$id" "_price" "$price"
        safe_store_meta "$id" "_regular_price" "$price"
        
        # Vérifier que le prix a bien été stocké
        local stored_price=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT meta_value FROM wp_${SITE_ID}_postmeta 
            WHERE post_id=$id AND meta_key='_price' LIMIT 1")
        echo "[DEBUG] Prix stocké dans la base : $stored_price"
    fi
    
    if [ -n "$condition" ]; then
        echo "[DEBUG] Mise à jour de l'état : $condition"
        # Mapper la condition
        local book_condition=""
        local vinted_condition=""
        
        case "$condition" in
            1) book_condition="Neuf avec étiquette"; vinted_condition="1 - Neuf avec étiquette" ;;
            2) book_condition="Neuf sans étiquette"; vinted_condition="2 - Neuf sans étiquette" ;;
            3) book_condition="Très bon état"; vinted_condition="3 - Très bon état" ;;
            4) book_condition="Bon état"; vinted_condition="4 - Bon état" ;;
            5) book_condition="État correct"; vinted_condition="5 - Satisfaisant" ;;
            6) book_condition="État passable"; vinted_condition="5 - Satisfaisant" ;;
        esac
        
        if [ -n "$book_condition" ]; then
            # Vérifier l'état existant
            local existing_condition=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT meta_value FROM wp_${SITE_ID}_postmeta 
                WHERE post_id=$id AND meta_key='_book_condition' LIMIT 1")
            
            echo "[DEBUG] État existant : '$existing_condition'"
            
            if [ -z "$existing_condition" ]; then
                # Créer la métadonnée
                mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
                    INSERT INTO wp_${SITE_ID}_postmeta (post_id, meta_key, meta_value) 
                    VALUES ($id, '_book_condition', '$book_condition')"
                echo "[DEBUG] État créé : $book_condition"
            else
                # Mettre à jour
                mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
                    UPDATE wp_${SITE_ID}_postmeta 
                    SET meta_value='$book_condition' 
                    WHERE post_id=$id AND meta_key='_book_condition'"
                echo "[DEBUG] État mis à jour : $book_condition"
            fi
            
            # Stocker aussi la condition Vinted
            safe_store_meta "$id" "_vinted_condition" "$vinted_condition"
            
            # Vérifier que l'état a bien été stocké
            local stored_condition=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT meta_value FROM wp_${SITE_ID}_postmeta 
                WHERE post_id=$id AND meta_key='_book_condition' LIMIT 1")
            echo "[DEBUG] État stocké dans la base : $stored_condition"
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
    
    # Code postal par défaut
    local zip_code=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key='_location_zip' LIMIT 1")
    
    if [ -z "$zip_code" ]; then
        echo "[DEBUG] Ajout du code postal par défaut : 76000"
        safe_store_meta "$id" "_location_zip" "76000"
    fi
    
    # Capturer l'état APRÈS
    local after_data=$(capture_book_state "$id")
    local after_count=$(echo "$after_data" | grep -c "^_")
    
    # Afficher section COLLECTE
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "🔄 SECTION 2 : COLLECTE DES DONNÉES VIA APIs"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    # Afficher les résultats de chaque API
    show_api_results "$id"
    
    # Afficher section APRÈS avec requirements
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📊 SECTION 3 : RÉSULTAT APRÈS COLLECTE ET EXPORTABILITÉ"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    # Appeler analyze_after.sh
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
    
    # Compter les données par source
    local g_before=$(echo "$before_data" | grep -c "^_g_")
    local i_before=$(echo "$before_data" | grep -c "^_i_")
    local o_before=$(echo "$before_data" | grep -c "^_o_")
    local best_before=$(echo "$before_data" | grep -c "^_best_\|^_calculated_")
    
    local g_after=$(echo "$after_data" | grep -c "^_g_")
    local i_after=$(echo "$after_data" | grep -c "^_i_")
    local o_after=$(echo "$after_data" | grep -c "^_o_")
    local best_after=$(echo "$after_data" | grep -c "^_best_\|^_calculated_")
    
    # Calculer les gains
    local g_gain=$((g_after - g_before))
    local i_gain=$((i_after - i_before))
    local o_gain=$((o_after - o_before))
    local best_gain=$((best_after - best_before))
    local total_gain=$((after_count - before_count))
    
    # Afficher le tableau des gains
    printf "┌──────────────────────────────────────────────┬─────────────┬─────────────┬─────────────┬─────────────────┐\n"
    printf "│ %-44s │ %11s │ %11s │ %11s │ %-15s │\n" "Source" "AVANT" "APRÈS" "GAIN" "Progression"
    printf "├──────────────────────────────────────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤\n"
    printf "│ %-44s │ %11d │ %11d │ %+11d │ %-15s │\n" "Google Books" "$g_before" "$g_after" "$g_gain" "$(format_progression $g_gain)"
    printf "│ %-44s │ %11d │ %11d │ %+11d │ %-15s │\n" "ISBNdb" "$i_before" "$i_after" "$i_gain" "$(format_progression $i_gain)"
    printf "│ %-44s │ %11d │ %11d │ %+11d │ %-15s │\n" "Open Library" "$o_before" "$o_after" "$o_gain" "$(format_progression $o_gain)"
    printf "│ %-44s │ %11d │ %11d │ %+11d │ %-15s │\n" "Meilleures données & Calculs" "$best_before" "$best_after" "$best_gain" "$(format_progression $best_gain)"
    printf "├──────────────────────────────────────────────┼─────────────┼─────────────┼─────────────┼─────────────────┤\n"
    printf "│ %-44s │ %11d │ %11d │ %+11d │ %-15s │\n" "TOTAL" "$before_count" "$after_count" "$total_gain" "$(format_progression $total_gain)"
    printf "└──────────────────────────────────────────────┴─────────────┴─────────────┴─────────────┴─────────────────┘\n"
    
    # Message de conclusion
    echo ""
    if [ $total_gain -gt 0 ]; then
        echo "✅ Collecte réussie : +$total_gain nouvelles données"
    else
        echo "ℹ️  Aucune nouvelle donnée collectée"
        echo "   Causes possibles :"
        echo "   • Le livre a déjà toutes les données disponibles"
        echo "   • Les APIs n'ont pas d'informations supplémentaires"
        echo "   • Utilisez -force pour réinterroger les APIs"
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
            echo "❌ Statut : Erreur de connexion à l'API"
        fi
    fi
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    echo ""
    
    # Tableau Google Books
    show_google_data_table "$id"
    
    # ISBNdb
    echo ""
    echo "🟢 ISBNDB API"
    local i_test=$(get_meta_value "$id" "_i_title")
    local isbndb_timestamp=$(get_meta_timestamp "$id" "_isbndb_last_attempt")
    
    # Vérifier si la clé API est configurée
    source "$SCRIPT_DIR/config/credentials.sh"
    if [ -z "$ISBNDB_API_KEY" ] || [ "$ISBNDB_API_KEY" = "YOUR_ISBNDB_API_KEY_HERE" ]; then
        echo "❌ Statut : Clé API non configurée"
    elif [ -n "$i_test" ]; then
        echo "✅ Statut : Données collectées avec succès"
        echo -e "${CYAN}⏰ Collecté le : $isbndb_timestamp${NC}"
    else
        if [ -n "$isbndb_timestamp" ]; then
            echo "⚠️  Statut : Aucune donnée trouvée ou API non accessible"
            echo -e "${YELLOW}⏰ Dernière tentative : $isbndb_timestamp${NC}"
        else
            echo "❌ Statut : API non appelée"
        fi
    fi
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    
    # Tableau ISBNdb
    show_isbndb_data_table "$id"
    
    # Open Library
    echo ""
    echo "🟠 OPEN LIBRARY API"
    local o_test=$(get_meta_value "$id" "_o_title")
    local ol_timestamp=$(get_meta_timestamp "$id" "_openlibrary_last_attempt")
    
    if [ -n "$o_test" ]; then
        echo "✅ Statut : Données collectées avec succès"
        echo -e "${CYAN}⏰ Collecté le : $ol_timestamp${NC}"
    else
        if [ -n "$ol_timestamp" ]; then
            echo "⚠️  Statut : Aucune donnée trouvée pour cet ISBN"
            echo -e "${YELLOW}⏰ Dernière tentative : $ol_timestamp${NC}"
        else
            echo "❌ Statut : Erreur de connexion à l'API (timeout ou réseau)"
        fi
    fi
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    echo ""
    
    # Tableau Open Library
    show_openlibrary_data_table "$id"
}

# Fonctions d'affichage des tableaux
show_google_data_table() {
    local id=$1
    
    printf "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐\n"
    printf "│ %-44s │ %-102s │ %-8s │\n" "Variable Google Books" "Valeur collectée" "Status"
    printf "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤\n"
    
    # Liste des variables Google Books
    local g_vars=(
        "_g_title:Titre"
        "_g_subtitle:Sous-titre"
        "_g_authors:Auteurs"
        "_g_publisher:Éditeur"
        "_g_publishedDate:Date publication"
        "_g_description:Description"
        "_g_pageCount:Nombre pages"
        "_g_categories:Catégories"
        "_g_language:Langue"
        "_g_isbn10:ISBN-10"
        "_g_isbn13:ISBN-13"
        "_g_thumbnail:Thumbnail"
        "_g_smallThumbnail:Small Thumbnail"
        "_g_medium:Medium"
        "_g_large:Large"
        "_g_extraLarge:Extra Large"
        "_g_height:Hauteur"
        "_g_width:Largeur"
        "_g_thickness:Épaisseur"
        "_g_printType:Type"
        "_g_averageRating:Note moyenne"
        "_g_ratingsCount:Nb avis"
        "_g_previewLink:Lien preview"
        "_g_infoLink:Lien info"
        "_g_listPrice:Prix catalogue"
        "_g_retailPrice:Prix vente"
    )
    
    for var_info in "${g_vars[@]}"; do
        local var_key="${var_info%%:*}"
        local var_label="${var_info##*:}"
        
        local value=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT meta_value FROM wp_${SITE_ID}_postmeta 
            WHERE post_id=$id AND meta_key='$var_key' LIMIT 1")
        
        if [ -n "$value" ]; then
            # Tronquer si trop long
            if [ ${#value} -gt 100 ]; then
                value="${value:0:97}..."
            fi
            printf "│ %-44s │ %-102s │ ${GREEN}✓ OK${NC}     │\n" "$var_key" "$value"
        else
            printf "│ %-44s │ %-102s │ ${RED}✗ MANQUE${NC} │\n" "$var_key" "-"
        fi
    done
    
    printf "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘\n"
}

show_isbndb_data_table() {
    local id=$1
    
    printf "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐\n"
    printf "│ %-44s │ %-102s │ %-8s │\n" "Variable ISBNdb" "Valeur collectée" "Status"
    printf "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤\n"
    
    # Liste des variables ISBNdb
    local i_vars=(
        "_i_title:Titre"
        "_i_authors:Auteurs"
        "_i_publisher:Éditeur"
        "_i_synopsis:Synopsis"
        "_i_overview:Aperçu"
        "_i_binding:Reliure"
        "_i_pages:Pages"
        "_i_subjects:Sujets"
        "_i_msrp:Prix"
        "_i_language:Langue"
        "_i_date_published:Date publication"
        "_i_isbn10:ISBN-10"
        "_i_isbn13:ISBN-13"
        "_i_dimensions:Dimensions"
        "_i_image:Image"
    )
    
    for var_info in "${i_vars[@]}"; do
        local var_key="${var_info%%:*}"
        local var_label="${var_info##*:}"
        
        local value=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT meta_value FROM wp_${SITE_ID}_postmeta 
            WHERE post_id=$id AND meta_key='$var_key' LIMIT 1")
        
        if [ -n "$value" ]; then
            if [ ${#value} -gt 100 ]; then
                value="${value:0:97}..."
            fi
            printf "│ %-44s │ %-102s │ ${GREEN}✓ OK${NC}     │\n" "$var_key" "$value"
        else
            printf "│ %-44s │ %-102s │ ${RED}✗ MANQUE${NC} │\n" "$var_key" "-"
        fi
    done
    
    printf "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘\n"
}

show_openlibrary_data_table() {
    local id=$1
    
    printf "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐\n"
    printf "│ %-44s │ %-102s │ %-8s │\n" "Variable Open Library" "Valeur collectée" "Status"
    printf "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤\n"
    
    # Liste des variables Open Library
    local o_vars=(
        "_o_title:Titre"
        "_o_authors:Auteurs"
        "_o_publishers:Éditeurs"
        "_o_number_of_pages:Nombre pages"
        "_o_physical_format:Format physique"
        "_o_subjects:Sujets"
        "_o_description:Description"
        "_o_first_sentence:Première phrase"
        "_o_excerpts:Extraits"
        "_o_cover_small:Cover small"
        "_o_cover_medium:Cover medium"
        "_o_cover_large:Cover large"
    )
    
    for var_info in "${o_vars[@]}"; do
        local var_key="${var_info%%:*}"
        local var_label="${var_info##*:}"
        
        local value=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT meta_value FROM wp_${SITE_ID}_postmeta 
            WHERE post_id=$id AND meta_key='$var_key' LIMIT 1")
        
        if [ -n "$value" ]; then
            if [ ${#value} -gt 100 ]; then
                value="${value:0:97}..."
            fi
            printf "│ %-44s │ %-102s │ ${GREEN}✓ OK${NC}     │\n" "$var_key" "$value"
        else
            printf "│ %-44s │ %-102s │ ${RED}✗ MANQUE${NC} │\n" "$var_key" "-"
        fi
    done
    
    printf "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘\n"
}

# Main
main() {
    # Mode batch
    if [ "$MODE" = "batch" ]; then
        process_batch "$LIMIT"
        exit 0
    fi
    
    # Mode vendu
    if [ "$MODE" = "vendu" ]; then
        if [ -z "$PARAM_ISBN" ]; then
            echo "❌ ISBN ou ID requis pour marquer comme vendu"
            exit 1
        fi
        mark_as_sold "$PARAM_ISBN"
        exit 0
    fi
    
    # Mode normal - traiter un livre
    if [ -z "$PARAM_ISBN" ] && [ "$MODE" != "batch" ]; then
        # Mode interactif
        echo ""
        echo "📚 MODE INTERACTIF"
        echo "────────────────────"
        read -p "ISBN ou ID du livre : " PARAM_ISBN
        
        if [ -z "$PARAM_ISBN" ]; then
            echo "❌ ISBN ou ID requis"
            exit 1
        fi
        
        read -p "Prix (laisser vide pour garder l'existant) : " PARAM_PRICE
        
        if [ -n "$PARAM_PRICE" ]; then
            echo ""
            echo "État du livre :"
            echo "  1 = Neuf avec étiquette"
            echo "  2 = Neuf sans étiquette"
            echo "  3 = Très bon état"
            echo "  4 = Bon état"
            echo "  5 = État correct"
            echo "  6 = État passable"
            read -p "Votre choix (1-6) : " PARAM_CONDITION
            
            read -p "Stock (défaut: 1) : " PARAM_STOCK
            [ -z "$PARAM_STOCK" ] && PARAM_STOCK="1"
        fi
    fi
    
    # Traiter le livre
    process_single_book "$PARAM_ISBN" "$PARAM_PRICE" "$PARAM_CONDITION" "$PARAM_STOCK"
    
    # Footer
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "🔄 NOUVELLE ANALYSE"
    echo ""
    echo "Pour analyser un autre livre :"
    echo "./isbn_unified.sh [ISBN] [prix] [état] [stock]"
    echo ""
    echo "Exemples :"
    echo "./isbn_unified.sh 9782070368228                    # Interactif"
    echo "./isbn_unified.sh 9782070368228 7.50 3 1           # Tout défini"
    echo "./isbn_unified.sh -notableau 9782070368228         # Sans tableaux"
    echo "./isbn_unified.sh -vendu 9782070368228             # Marquer vendu"
    echo ""
    echo "États : 1=Neuf étiq. 2=Neuf 3=Très bon 4=Bon 5=Correct 6=Passable"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
}

# Lancer le script
main