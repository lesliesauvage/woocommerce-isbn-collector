#!/bin/bash
# 🛍️ GÉNÉRATEUR DE DESCRIPTIONS COMMERCIALES
# Usage: ./commercial_desc.sh ISBN [-quiet|-verbose|-save|-force]

echo "[START: commercial_desc.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Charger les configurations
source config/settings.sh
source lib/safe_functions.sh
source lib/database.sh
source lib/commercial_description.sh

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Variables
ISBN=""
MODE="normal"  # normal, quiet, verbose, save
FORCE=0

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -quiet|-q)
            MODE="quiet"
            shift
            ;;
        -verbose|-v)
            MODE="verbose"
            shift
            ;;
        -save|-s)
            MODE="save"
            shift
            ;;
        -force|-f)
            FORCE=1
            shift
            ;;
        -help|-h)
            echo "Usage: $0 ISBN [options]"
            echo ""
            echo "Options:"
            echo "  -quiet    Mode silencieux (description seule)"
            echo "  -verbose  Mode détaillé"
            echo "  -save     Sauvegarder dans la BDD"
            echo "  -force    Forcer la régénération"
            echo ""
            echo "Exemples:"
            echo "  $0 9782070360024"
            echo "  $0 9782070360024 -save"
            echo "  $0 9782070360024 -quiet"
            echo "[END: commercial_desc.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2
            exit 0
            ;;
        *)
            if [ -z "$ISBN" ]; then
                ISBN="$1"
            fi
            shift
            ;;
    esac
done

# Vérifier l'ISBN
if [ -z "$ISBN" ]; then
    echo -e "${RED}❌ ISBN requis${NC}"
    echo "Usage: $0 ISBN [-quiet|-verbose|-save]"
    echo "[END: commercial_desc.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2
    exit 1
fi

# Valider l'ISBN
if ! validate_isbn "$ISBN"; then
    echo -e "${RED}❌ ISBN invalide : $ISBN${NC}"
    echo "[END: commercial_desc.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2
    exit 1
fi

# Récupérer l'ID du post
post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT post_id FROM wp_${SITE_ID}_postmeta 
    WHERE meta_key = '_isbn' AND meta_value = '$ISBN'
    LIMIT 1" 2>/dev/null)

if [ -z "$post_id" ]; then
    if [ "$MODE" != "quiet" ]; then
        echo -e "${RED}❌ ISBN $ISBN non trouvé dans la base${NC}"
        echo ""
        echo -e "${YELLOW}💡 Pour ajouter ce livre :${NC}"
        echo -e "   ${CYAN}./add_and_collect.sh $ISBN${NC}"
    fi
    echo "[END: commercial_desc.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2
    exit 1
fi

# Récupérer les infos du livre
book_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT 
        p.post_title,
        (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = p.ID AND meta_key = '_best_authors' LIMIT 1),
        (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = p.ID AND meta_key = '_best_publisher' LIMIT 1),
        (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = p.ID AND meta_key = '_best_pages' LIMIT 1),
        (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = p.ID AND meta_key = '_best_description' LIMIT 1),
        (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = p.ID AND meta_key = '_commercial_description' LIMIT 1)
    FROM wp_${SITE_ID}_posts p
    WHERE p.ID = $post_id
" 2>/dev/null)

IFS=$'\t' read -r title authors publisher pages base_description existing_commercial <<< "$book_info"

# Header (sauf en mode quiet)
if [ "$MODE" != "quiet" ]; then
    clear
    echo -e "${BOLD}${CYAN}🛍️  GÉNÉRATEUR DE DESCRIPTIONS COMMERCIALES${NC}"
    echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BOLD}📖 Livre :${NC} $title"
    echo -e "${BOLD}✍️  Auteur :${NC} ${authors:-Non renseigné}"
    echo -e "${BOLD}🏢 Éditeur :${NC} ${publisher:-Non renseigné}"
    echo -e "${BOLD}📄 Pages :${NC} ${pages:-Non renseigné}"
    echo -e "${BOLD}🔢 ISBN :${NC} $ISBN"
    echo -e "${BOLD}🆔 ID :${NC} $post_id"
    echo ""
fi

# Vérifier si une description commerciale existe déjà
if [ -n "$existing_commercial" ] && [ "$FORCE" -eq 0 ] && [ "$MODE" != "save" ]; then
    if [ "$MODE" = "quiet" ]; then
        echo "$existing_commercial"
    else
        echo -e "${YELLOW}⚠️  Une description commerciale existe déjà :${NC}"
        echo -e "${BOLD}${PURPLE}─────────────────────────────────────────${NC}"
        echo "$existing_commercial"
        echo -e "${BOLD}${PURPLE}─────────────────────────────────────────${NC}"
        echo ""
        echo -e "${CYAN}💡 Utiliser -force pour régénérer${NC}"
    fi
    echo "[END: commercial_desc.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2
    exit 0
fi

# Vérifier qu'on a une description de base
if [ "$MODE" = "verbose" ]; then
    echo "🔍 Vérification de la description de base..."
    echo "   Description actuelle : ${#base_description} caractères"
fi

# Si pas de description ou trop courte
if [ -z "$base_description" ] || [ ${#base_description} -lt 20 ] || [[ "$base_description" == "Description non disponible"* ]]; then
    if [ "$MODE" != "quiet" ]; then
        echo -e "${YELLOW}⚠️  Description de base insuffisante${NC}"
        echo ""
        echo -e "${BLUE}🔄 Collecte des données nécessaires...${NC}"
    fi
    
    # Lancer la collecte
    if [ "$MODE" = "verbose" ]; then
        ./isbn_unified.sh "$ISBN" -force
    else
        ./isbn_unified.sh "$ISBN" -force >/dev/null 2>&1
    fi
    
    # Attendre un peu
    sleep 2
    
    # Recharger la description
    base_description=$(get_meta_value "$post_id" "_best_description")
    
    if [ -z "$base_description" ] || [ ${#base_description} -lt 20 ] || [[ "$base_description" == "Description non disponible"* ]]; then
        if [ "$MODE" != "quiet" ]; then
            echo -e "${RED}❌ Impossible de générer une description commerciale sans données${NC}"
            echo -e "${YELLOW}💡 Vérifiez que les APIs retournent des données pour cet ISBN${NC}"
        fi
        echo "[END: commercial_desc.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2
        exit 1
    fi
fi

# Générer la description commerciale
if [ "$MODE" != "quiet" ]; then
    echo ""
    echo -e "${BOLD}${GREEN}🚀 GÉNÉRATION EN COURS...${NC}"
fi

# Créer une description temporaire pour le mode non-save
temp_key="_temp_commercial_description_$$"

if [ "$MODE" = "save" ]; then
    # Mode save : utiliser la vraie clé
    target_key="_commercial_description"
else
    # Autres modes : utiliser une clé temporaire
    target_key="$temp_key"
fi

# Générer via l'API
if [ "$MODE" = "verbose" ]; then
    # Mode verbose : afficher tous les détails
    generate_commercial_description "$post_id" "$ISBN" "$target_key"
    result=$?
else
    # Mode normal/quiet : capturer la sortie
    generate_commercial_description "$post_id" "$ISBN" "$target_key" >/dev/null 2>&1
    result=$?
fi

if [ $result -eq 0 ]; then
    # Récupérer la description générée
    new_desc=$(get_meta_value "$post_id" "$target_key")
    
    if [ "$MODE" = "quiet" ]; then
        # Mode quiet : afficher seulement la description
        echo "$new_desc"
    else
        # Mode normal/verbose : affichage complet
        echo ""
        echo -e "${BOLD}${GREEN}✅ DESCRIPTION COMMERCIALE GÉNÉRÉE !${NC}"
        echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════${NC}"
        echo ""
        echo -e "${CYAN}$new_desc${NC}"
        echo ""
        echo -e "${BOLD}${PURPLE}═══════════════════════════════════════════${NC}"
        echo ""
        echo -e "${BOLD}📊 Statistiques :${NC}"
        echo -e "   • Longueur : ${GREEN}${#new_desc} caractères${NC}"
        echo -e "   • Mots : ${GREEN}$(echo "$new_desc" | wc -w) mots${NC}"
        echo -e "   • Lignes : ${GREEN}$(echo "$new_desc" | wc -l) lignes${NC}"
        
        if [ "$MODE" = "save" ]; then
            echo ""
            echo -e "${BOLD}${GREEN}💾 Sauvegardé dans la base de données${NC}"
            echo -e "   • Clé : ${CYAN}_commercial_description${NC}"
            echo -e "   • Date : ${CYAN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
        else
            echo ""
            echo -e "${YELLOW}💡 Pour sauvegarder : $0 $ISBN -save${NC}"
        fi
    fi
    
    # Nettoyer la clé temporaire si pas en mode save
    if [ "$MODE" != "save" ] && [ -n "$temp_key" ]; then
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            DELETE FROM wp_${SITE_ID}_postmeta 
            WHERE post_id=$post_id AND meta_key='$temp_key'" 2>/dev/null
    fi
    
    exit_code=0
else
    if [ "$MODE" != "quiet" ]; then
        echo ""
        echo -e "${RED}❌ Échec de la génération${NC}"
        echo -e "${YELLOW}Causes possibles :${NC}"
        echo -e "   • Clé API Claude manquante ou invalide"
        echo -e "   • Limite de l'API atteinte"
        echo -e "   • Données insuffisantes pour le livre"
        echo ""
        echo -e "${CYAN}💡 Vérifiez votre configuration dans config/credentials.sh${NC}"
    fi
    exit_code=1
fi

# Footer en mode verbose
if [ "$MODE" = "verbose" ]; then
    echo ""
    echo -e "${BOLD}${BLUE}📋 MÉTADONNÉES UTILISÉES :${NC}"
    echo "─────────────────────────────"
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        SELECT meta_key, LEFT(meta_value, 80) as 'Valeur (80 car max)'
        FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $post_id 
        AND meta_key IN ('_best_title', '_best_authors', '_best_publisher', 
                        '_best_description', '_best_pages', '_g_categories',
                        '_i_subjects', '_commercial_description')
        ORDER BY meta_key
    " 2>/dev/null
fi

echo "[END: commercial_desc.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2
exit $exit_code
