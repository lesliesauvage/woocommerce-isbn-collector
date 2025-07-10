#!/bin/bash
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
#         ;;
#     *)
#         # Mode normal : traiter un livre
#         if [ -n "$PARAM_ISBN" ]; then
#             echo -e "${BOLD}${GREEN}📚 Mode traitement individuel${NC}"
# echo "[DEBUG] Avant appel process_single_book - fonction existe : $(type -t process_single_book)" >&2
#             process_single_book "$PARAM_ISBN" "$PARAM_PRICE" "$PARAM_CONDITION" "$PARAM_STOCK"
#         else
#             echo -e "${RED}❌ ISBN requis${NC}"
#             show_help
#             exit 1
#         fi
#         ;;
# esac
# 
# # Log de fin
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Script terminé" >> "$LOG_FILE"

# === AFFICHAGE MARTINGALE FINALE SI DEMANDÉ ===
if [ "$VERBOSE" -eq 1 ] && [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE FINALE (156 CHAMPS)${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    if [ -n "$PARAM_ISBN" ]; then
        # Récupérer l'ID si on a traité un livre
        if [[ "$PARAM_ISBN" =~ ^[0-9]+$ ]] && [ ${#PARAM_ISBN} -lt 10 ]; then
            display_martingale_complete "$PARAM_ISBN"
        else
            local clean_isbn="${PARAM_ISBN//[^0-9]/}"
            local final_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT ID FROM wp_${SITE_ID}_posts 
                WHERE post_type='product' 
                AND post_status='publish' 
                AND ID IN (
                    SELECT post_id FROM wp_${SITE_ID}_postmeta 
                    WHERE meta_key='_sku' AND meta_value='$clean_isbn'
                )
                LIMIT 1")
            [ -n "$final_id" ] && display_martingale_complete "$final_id"
        fi
    fi
fi

exit 0