#!/bin/bash
echo "[START: isbn_unified.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2

# Script unifié de gestion ISBN - Version 4 MARTINGALE COMPLÈTE MODULAIRE
# Fichier principal qui charge les modules

# Définir le répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger la configuration et les fonctions de base
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

# Charger les modules
echo "[DEBUG] Chargement des modules..." >&2
source "$SCRIPT_DIR/lib/isbn_functions.sh"    # Fonctions utilitaires
echo "[DEBUG] isbn_functions.sh chargé : $(type -t select_best_data)" >&2
source "$SCRIPT_DIR/lib/isbn_display.sh"      # Fonctions d'affichage
echo "[DEBUG] isbn_display.sh chargé : $(type -t show_help)" >&2
source "$SCRIPT_DIR/lib/isbn_collect.sh"      # Fonctions de collecte
echo "[DEBUG] isbn_collect.sh chargé : $(type -t collect_all_apis)" >&2
source "$SCRIPT_DIR/lib/isbn_process.sh"      # Fonctions de traitement
echo "[DEBUG] isbn_process.sh chargé : $(type -t process_single_book)" >&2
source "$SCRIPT_DIR/lib/martingale_complete.sh"  # Martingale complète
echo "[DEBUG] martingale_complete.sh chargé : $(type -t enrich_metadata_complete)" >&2

# Charger les fichiers analyze si disponibles
[ -f "$SCRIPT_DIR/lib/analyze_before.sh" ] && source "$SCRIPT_DIR/lib/analyze_before.sh"
[ -f "$SCRIPT_DIR/lib/analyze_after.sh" ] && source "$SCRIPT_DIR/lib/analyze_after.sh"

# Variables globales
PARAM_ISBN=""
PARAM_PRICE=""
PARAM_CONDITION=""
PARAM_STOCK=""
MODE=""
LIMIT=""
FORCE_MODE=""

# Définir LOG_FILE
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/isbn_unified_$(date +%Y%m%d_%H%M%S).log"

# Variables globales pour les options
FORCE_COLLECT=0
VERBOSE=0
SKIP_CATEGORIZATION=0  # Nouvelle variable pour permettre de désactiver la catégorisation
SKIP_COMMERCIAL=0       # Nouvelle variable pour permettre de désactiver la description commerciale

# Couleurs ANSI pour affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Parser les options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -force)
            FORCE_MODE="force"
            FORCE_COLLECT=1
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
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -nocategorize|--no-categorize)
            SKIP_CATEGORIZATION=1
            shift
            ;;
        -nocommercial|--no-commercial)
            SKIP_COMMERCIAL=1
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

# Fonction pour obtenir la hiérarchie complète d'une catégorie
get_full_category_hierarchy() {
    local term_id="$1"
    local hierarchy=""
    
    while [ -n "$term_id" ] && [ "$term_id" != "0" ]; do
        local cat_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT t.name, tt.parent
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE t.term_id = $term_id AND tt.taxonomy = 'product_cat'
        " 2>/dev/null)
        
        if [ -n "$cat_info" ]; then
            local cat_name=$(echo "$cat_info" | cut -f1)
            local parent_id=$(echo "$cat_info" | cut -f2)
            
            if [ -z "$hierarchy" ]; then
                hierarchy="$cat_name"
            else
                hierarchy="$cat_name > $hierarchy"
            fi
            
            term_id="$parent_id"
        else
            break
        fi
    done
    
    echo "$hierarchy"
}

# Fonction pour chercher d'autres éditions quand pas de description
find_editions_for_description() {
    local post_id="$1"
    local isbn="$2"
    
    echo ""
    echo -e "${BOLD}${CYAN}🔍 RECHERCHE D'AUTRES ÉDITIONS POUR RÉCUPÉRER UNE DESCRIPTION...${NC}"
    
    # Récupérer titre et auteur
    local book_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT 
            p.post_title,
            (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = p.ID AND meta_key = '_best_authors' LIMIT 1)
        FROM wp_${SITE_ID}_posts p
        WHERE p.ID = $post_id
        LIMIT 1" 2>/dev/null)
    
    if [ -z "$book_info" ]; then
        echo -e "${RED}❌ Impossible de récupérer les infos du livre${NC}"
        return 1
    fi
    
    IFS=$'\t' read -r title authors <<< "$book_info"
    
    # Nettoyer pour la recherche
    local search_title=$(echo "$title" | sed 's/[[:punct:]]//g' | head -c 50)
    local search_author=$(echo "$authors" | cut -d',' -f1 | sed 's/[[:punct:]]//g')
    local search_query=$(echo "$search_title $search_author" | sed 's/ /+/g')
    
    echo -e "   📖 Titre : $title"
    echo -e "   ✍️  Auteur : $authors"
    echo -e "   🔎 Recherche : $search_query"
    echo ""
    
    # Rechercher sur Google Books
    local response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=$search_query&maxResults=40&key=$GOOGLE_BOOKS_API_KEY" 2>/dev/null)
    
    # Trouver la meilleure description (la plus longue)
    local best_desc=""
    local best_date=""
    local best_isbn=""
    local max_length=0
    
    # Parser les résultats avec jq
    while IFS='|' read -r date isbn desc; do
        if [ -n "$desc" ] && [ ${#desc} -gt $max_length ]; then
            max_length=${#desc}
            best_desc="$desc"
            best_date="$date"
            best_isbn="$isbn"
        fi
    done < <(echo "$response" | jq -r '.items[]? | 
        select(.volumeInfo.description != null) |
        select(.volumeInfo.title | test("'"${title:0:20}"'"; "i")) |
        select(.volumeInfo.authors[0] | test("'"$search_author"'"; "i")) |
        "\(.volumeInfo.publishedDate // "?")|\(.volumeInfo.industryIdentifiers[]? | select(.type == "ISBN_13") | .identifier // "?")|\(.volumeInfo.description)"' 2>/dev/null)
    
    if [ -n "$best_desc" ] && [ $max_length -gt 100 ]; then
        echo -e "${GREEN}✅ DESCRIPTION TROUVÉE !${NC}"
        echo -e "   📅 Édition : $best_date"
        echo -e "   📚 ISBN : $best_isbn"
        echo -e "   📏 Longueur : $max_length caractères"
        echo ""
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}$(echo "$best_desc" | head -c 300)...${NC}"
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        
        # Sauvegarder la description
        echo ""
        echo -e "${YELLOW}💾 Sauvegarde de la description...${NC}"
        safe_store_meta "$post_id" "_best_description" "$best_desc"
        safe_store_meta "$post_id" "_best_description_source" "google_editions_$best_date"
        
        # Attendre un peu pour la sauvegarde
        sleep 1
        
        return 0
    else
        echo -e "${YELLOW}⚠️  Aucune description trouvée dans les autres éditions${NC}"
        return 1
    fi
}

# Fonction pour catégoriser le livre avec les IA
categorize_book_with_ai() {
    local post_id="$1"
    local isbn="$2"
    
    echo "[DEBUG] Tentative de catégorisation IA pour post_id=$post_id, isbn=$isbn" >&2
    
    # Vérifier si smart_categorize_dual_ai.sh existe
    if [ ! -f "$SCRIPT_DIR/smart_categorize_dual_ai.sh" ]; then
        echo -e "${YELLOW}⚠️  smart_categorize_dual_ai.sh non trouvé - catégorisation IA ignorée${NC}"
        return 1
    fi
    
    # Vérifier si les clés API sont configurées
    if [ -z "$GEMINI_API_KEY" ] || [ -z "$CLAUDE_API_KEY" ]; then
        echo -e "${YELLOW}⚠️  Clés API manquantes - catégorisation IA ignorée${NC}"
        echo -e "${CYAN}💡 Lancez ./setup_dual_ai.sh pour configurer les clés${NC}"
        return 1
    fi
    
    # Vérifier si déjà catégorisé
    local has_cat=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT COUNT(*) 
    FROM wp_${SITE_ID}_term_relationships tr
    JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
    WHERE tr.object_id = $post_id 
    AND tt.taxonomy = 'product_cat'
    " 2>/dev/null)
    
    if [ "$has_cat" -gt 0 ] && [ "$FORCE_MODE" != "force" ]; then
        # Récupérer et afficher la catégorie existante en vert avec hiérarchie complète
        echo ""
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${CYAN}🏷️  CATÉGORIE WORDPRESS EXISTANTE :${NC}"
        
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT tt.term_id
        FROM wp_${SITE_ID}_term_relationships tr
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        WHERE tr.object_id = $post_id AND tt.taxonomy = 'product_cat'
        " 2>/dev/null | while read term_id; do
            local full_hierarchy=$(get_full_category_hierarchy "$term_id")
            echo -e "   ${GREEN}${BOLD}✅ $full_hierarchy${NC}"
        done
        
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        return 0
    fi
    
    echo ""
    echo -e "${BOLD}${CYAN}🤖 CATÉGORISATION INTELLIGENTE PAR IA...${NC}"
    
    # Sauvegarder la catégorie avant l'appel
    local before_categories=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT GROUP_CONCAT(tt.term_id) 
    FROM wp_${SITE_ID}_term_relationships tr
    JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
    WHERE tr.object_id = $post_id AND tt.taxonomy = 'product_cat'
    " 2>/dev/null)
    
    # Appeler smart_categorize_dual_ai.sh avec l'ID du post
    local categorize_output
    local categorize_status
    
    if [ "$VERBOSE" = "1" ]; then
        # Mode verbose : afficher toute la sortie
        "$SCRIPT_DIR/smart_categorize_dual_ai.sh" -id "$post_id"
        categorize_status=$?
    else
        # Mode normal : capturer la sortie et n'afficher que le résultat
        categorize_output=$("$SCRIPT_DIR/smart_categorize_dual_ai.sh" -id "$post_id" -noverbose 2>&1)
        categorize_status=$?
    fi
    
    # Afficher le résultat de la catégorisation
    if [ $categorize_status -eq 0 ]; then
        # Récupérer la nouvelle catégorie
        local new_categories=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT tt.term_id
        FROM wp_${SITE_ID}_term_relationships tr
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        WHERE tr.object_id = $post_id AND tt.taxonomy = 'product_cat'
        AND tt.term_id NOT IN (IFNULL('$before_categories', ''))
        LIMIT 1
        " 2>/dev/null)
        
        if [ -n "$new_categories" ]; then
            echo ""
            echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
            echo -e "${BOLD}${CYAN}🎯 CATÉGORIE CHOISIE PAR L'IA :${NC}"
            
            # Afficher avec la hiérarchie complète
            local full_hierarchy=$(get_full_category_hierarchy "$new_categories")
            echo -e "   ${GREEN}${BOLD}✅ $full_hierarchy${NC}"
            
            echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        else
            # Si on n'a pas trouvé de nouvelle catégorie, afficher toutes les catégories
            echo ""
            echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
            echo -e "${BOLD}${CYAN}🏷️  CATÉGORIES APRÈS IA :${NC}"
            
            mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT tt.term_id
            FROM wp_${SITE_ID}_term_relationships tr
            JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE tr.object_id = $post_id AND tt.taxonomy = 'product_cat'
            " 2>/dev/null | while read term_id; do
                local full_hierarchy=$(get_full_category_hierarchy "$term_id")
                echo -e "   ${GREEN}${BOLD}✅ $full_hierarchy${NC}"
            done
            
            echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        fi
    else
        echo -e "${RED}❌ Échec de la catégorisation IA${NC}"
    fi
    
    return $categorize_status
}

# Fonction pour générer la description commerciale
generate_commercial_description_for_book() {
    local post_id="$1"
    local isbn="$2"
    
    echo "[DEBUG] Génération description commerciale pour post_id=$post_id, isbn=$isbn" >&2
    
    # Vérifier si commercial_desc.sh existe
    if [ ! -f "$SCRIPT_DIR/commercial_desc.sh" ]; then
        echo -e "${YELLOW}⚠️  commercial_desc.sh non trouvé - description commerciale ignorée${NC}"
        return 1
    fi
    
    # Vérifier si la clé API Claude est configurée
    if [ -z "$CLAUDE_API_KEY" ]; then
        echo -e "${YELLOW}⚠️  Clé API Claude manquante - description commerciale ignorée${NC}"
        return 1
    fi
    
    # Vérifier si une description commerciale existe déjà
    local existing_commercial=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = '$post_id' AND meta_key = '_commercial_description'
        AND meta_value IS NOT NULL AND meta_value != 'NULL' AND meta_value != ''
        LIMIT 1" 2>/dev/null)
    
    if [ -n "$existing_commercial" ] && [ "$FORCE_MODE" != "force" ]; then
        echo ""
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${CYAN}📢 DESCRIPTION COMMERCIALE EXISTANTE :${NC}"
        echo ""
        # Afficher la description complète avec retour à la ligne
        echo -e "${CYAN}$existing_commercial${NC}"
        echo ""
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        return 0
    fi
    
    echo ""
    echo -e "${BOLD}${CYAN}🛍️  GÉNÉRATION DESCRIPTION COMMERCIALE...${NC}"
    
    # Attendre que les données soient bien enregistrées
    sleep 2
    
    # Générer et sauvegarder directement
    if ./commercial_desc.sh "$isbn" -save -quiet >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Description commerciale générée et sauvegardée${NC}"
        
        # Attendre un peu pour la sauvegarde
        sleep 1
        
        # Récupérer et afficher la description
        commercial_desc=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT meta_value FROM wp_${SITE_ID}_postmeta 
            WHERE post_id = '$post_id' AND meta_key = '_commercial_description' 
            LIMIT 1" 2>/dev/null)
        
        if [ -n "$commercial_desc" ] && [ "$commercial_desc" != "NULL" ]; then
            echo ""
            echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
            echo -e "${BOLD}${CYAN}📢 DESCRIPTION COMMERCIALE GÉNÉRÉE :${NC}"
            echo ""
            echo -e "${CYAN}$commercial_desc${NC}"
            echo ""
            echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
            echo -e "${BOLD}📊 Statistiques :${NC}"
            echo -e "   • Longueur : ${GREEN}${#commercial_desc} caractères${NC}"
            echo -e "   • Mots : ${GREEN}$(echo "$commercial_desc" | wc -w) mots${NC}"
        fi
        return 0
    else
        echo -e "${YELLOW}⚠️  Description commerciale non générée (données insuffisantes)${NC}"
        return 1
    fi
}

# === PROGRAMME PRINCIPAL ===

echo "[DEBUG] Mode: $MODE, ISBN: $PARAM_ISBN" >&2

# Si aucun paramètre, afficher l'aide
if [ -z "$MODE" ] && [ -z "$PARAM_ISBN" ]; then
    show_help
    exit 0
fi

# Traiter selon le mode
case "$MODE" in
    vendu)
        echo -e "${BOLD}${RED}🛒 Mode marquage VENDU${NC}"
        mark_as_sold "$PARAM_ISBN"
        ;;
    batch)
        echo -e "${BOLD}${CYAN}📦 Mode traitement batch${NC}"
        process_batch "$LIMIT"
        ;;
    export)
        echo -e "${BOLD}${PURPLE}🚀 Mode export vers marketplaces${NC}"
        if [ -n "$PARAM_ISBN" ]; then
            # Export d'un seul livre
            echo "Export du livre $PARAM_ISBN..."
            # TODO: Implémenter l'export
            echo -e "${YELLOW}⚠️  Fonction export en cours de développement${NC}"
        else
            # Export en masse
            echo "Export en masse..."
            # TODO: Implémenter l'export en masse
            echo -e "${YELLOW}⚠️  Fonction export en masse en cours de développement${NC}"
        fi
        ;;
    *)
        # Mode normal : traiter un livre
        if [ -n "$PARAM_ISBN" ]; then
            echo -e "${BOLD}${GREEN}📚 Mode traitement individuel${NC}"
            echo "[DEBUG] Avant appel process_single_book - fonction existe : $(type -t process_single_book)" >&2
            
            # Appeler process_single_book qui va collecter et enrichir
            process_single_book "$PARAM_ISBN" "$PARAM_PRICE" "$PARAM_CONDITION" "$PARAM_STOCK"
            process_status=$?
            
            # Si la collecte a réussi
            if [ $process_status -eq 0 ]; then
                # Récupérer l'ID du post
                post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key = '_isbn' AND meta_value = '$PARAM_ISBN'
                LIMIT 1" 2>/dev/null)
                
                if [ -n "$post_id" ]; then
                    # Vérifier si on a une description suffisante
                    current_desc=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
                        WHERE post_id = '$post_id' AND meta_key = '_best_description'
                        LIMIT 1" 2>/dev/null)
                    
                    # Si pas de description ou trop courte ou "non disponible"
                    if [ -z "$current_desc" ] || [ ${#current_desc} -lt 50 ] || [[ "$current_desc" =~ "non disponible" ]]; then
                        echo ""
                        echo -e "${YELLOW}⚠️  Description insuffisante (${#current_desc} caractères)${NC}"
                        # Chercher dans d'autres éditions
                        find_editions_for_description "$post_id" "$PARAM_ISBN"
                    fi
                    
                    # 1. Catégorisation IA (si pas désactivée)
                    if [ "$SKIP_CATEGORIZATION" != "1" ]; then
                        categorize_book_with_ai "$post_id" "$PARAM_ISBN"
                    fi
                    
                    # 2. Description commerciale (si pas désactivée)
                    if [ "$SKIP_COMMERCIAL" != "1" ]; then
                        generate_commercial_description_for_book "$post_id" "$PARAM_ISBN"
                    fi
                fi
            fi
        else
            echo -e "${RED}❌ ISBN requis${NC}"
            show_help
            exit 1
        fi
        ;;
esac

# Log de fin
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script terminé" >> "$LOG_FILE"

echo "[END: isbn_unified.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2
exit 0