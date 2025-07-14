#!/bin/bash
echo "[START: isbn_unified.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2

# Script unifié de gestion ISBN - Version 4 MARTINGALE COMPLÈTE MODULAIRE
# Fichier principal qui charge les modules

# Définir le répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Charger les configurations et fonctions
source config/settings.sh
source lib/safe_functions.sh
source lib/isbn_functions.sh
source lib/isbn_display.sh
source lib/isbn_collect.sh
source lib/isbn_process.sh
source lib/database.sh
source lib/commercial_description.sh

# Charger la bibliothèque martingale complète
source "$SCRIPT_DIR/martingale_complete.sh"

# Définir les couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Variables pour les paramètres
PARAM_ISBN=""
PARAM_ACTION=""
FORCE_MODE=0
GENERATE_COMMERCIAL=1  # Par défaut, on génère la description commerciale
GENERATE_NEGOTIATION=0  # Par défaut, on ne génère pas le message de négociation
AUTO_SELECT_DESC=1      # Par défaut, sélection automatique de la meilleure description

# Fonction d'aide
show_help() {
    cat << EOF
${BOLD}${CYAN}📚 Script unifié de gestion ISBN - Version 4 MARTINGALE${NC}

${BOLD}Usage:${NC}
    $0 [ISBN] [OPTIONS]
    $0 -action [ACTION] [PARAMS]

${BOLD}Options de traitement individuel:${NC}
    ${GREEN}ISBN${NC}                  Traiter un ISBN spécifique
    ${GREEN}-force${NC}                Forcer la collecte même si les données existent
    ${GREEN}-nocommercial${NC}         Ne pas générer la description commerciale
    ${GREEN}-negotiation${NC}          Générer aussi le message de négociation
    ${GREEN}-interactive${NC}          Mode interactif pour la sélection de description

${BOLD}Actions disponibles:${NC}
    ${GREEN}-action bulk${NC}          Traiter plusieurs ISBN depuis la base
    ${GREEN}-action missing${NC}       Traiter les livres sans description
    ${GREEN}-action incomplete${NC}    Traiter les livres avec données incomplètes
    ${GREEN}-action martingale${NC}    Afficher le tableau martingale d'un livre
    ${GREEN}-action verify [ISBN]${NC} Vérifier la complétude d'un livre

${BOLD}Exemples:${NC}
    ${CYAN}$0 9782070360024${NC}              # Traiter un ISBN
    ${CYAN}$0 9782070360024 -force${NC}       # Forcer la mise à jour
    ${CYAN}$0 -action bulk${NC}               # Traiter plusieurs livres
    ${CYAN}$0 -action martingale 9782070360024${NC}  # Voir la martingale

${BOLD}${PURPLE}Fonctionnalités:${NC}
    ✓ Collecte via 3 APIs (Google Books, ISBNdb, Open Library)
    ✓ Enrichissement automatique (martingale complète)
    ✓ Recherche d'éditions si pas de description
    ✓ Catégorisation IA automatique
    ✓ Génération description commerciale
    ✓ Export multi-marketplace ready

EOF
}

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -action)
            PARAM_ACTION="$2"
            shift 2
            ;;
        -force)
            FORCE_MODE=1
            shift
            ;;
        -nocommercial)
            GENERATE_COMMERCIAL=0
            shift
            ;;
        -negotiation)
            GENERATE_NEGOTIATION=1
            shift
            ;;
        -interactive)
            AUTO_SELECT_DESC=0
            shift
            ;;
        *)
            if [ -z "$PARAM_ISBN" ]; then
                PARAM_ISBN="$1"
            fi
            shift
            ;;
    esac
done

# Fonction améliorée pour chercher d'autres éditions quand pas de description
find_editions_for_description() {
    local post_id="$1"
    local isbn="$2"
    
    echo "[DEBUG] Recherche d'éditions pour récupérer une description" >&2
    
    # Récupérer titre et auteur
    local book_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT 
            COALESCE(
                (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = $post_id AND meta_key = '_best_title' LIMIT 1),
                (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = $post_id AND meta_key = '_g_title' LIMIT 1),
                p.post_title
            ),
            COALESCE(
                (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = $post_id AND meta_key = '_best_authors' LIMIT 1),
                (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = $post_id AND meta_key = '_g_authors' LIMIT 1),
                ''
            )
        FROM wp_${SITE_ID}_posts p
        WHERE p.ID = $post_id
        LIMIT 1" 2>/dev/null)
    
    if [ -z "$book_info" ]; then
        echo "[ERROR] Livre non trouvé" >&2
        return 1
    fi
    
    IFS=$'\t' read -r title authors <<< "$book_info"
    
    echo -e "${YELLOW}🔎 Recherche d'autres éditions pour : $title${NC}"
    if [ -n "$authors" ]; then
        echo -e "${YELLOW}   Auteur : $authors${NC}"
    fi
    
    # Tableaux pour stocker les résultats
    declare -a descriptions
    declare -a years
    declare -a publishers
    declare -a sources
    local count=0
    
    # Fonction pour ajouter un résultat unique
    add_if_matches() {
        local desc="$1"
        local found_title="$2"
        local found_author="$3"
        local year="$4"
        local publisher="$5"
        local source="$6"
        
        # Vérifications souples pour le titre et l'auteur
        local title_match=0
        local author_match=0
        
        # Vérifier le titre (souple)
        if [[ "${found_title,,}" == "${title,,}" ]] || \
           [[ "${found_title,,}" == *"dictionnaire"* && "${found_title,,}" == *"symbole"* && "${title,,}" == *"dictionnaire"* && "${title,,}" == *"symbole"* ]] || \
           [[ "${title,,}" == *"${found_title,,}"* ]] || \
           [[ "${found_title,,}" == *"${title,,}"* ]]; then
            title_match=1
        fi
        
        # Vérifier l'auteur (souple)
        if [ -z "$authors" ] || [ "$authors" == "Auteur inconnu" ]; then
            author_match=1  # Pas d'auteur à vérifier
        elif [[ "${found_author,,}" == *"${authors,,}"* ]] || \
             [[ "${authors,,}" == *"${found_author,,}"* ]] || \
             [[ "${found_author,,}" == *"chevalier"* && "${authors,,}" == *"chevalier"* ]]; then
            author_match=1
        fi
        
        # Si ça match et qu'on a une description valide
        if [ $title_match -eq 1 ] && [ $author_match -eq 1 ]; then
            if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt 50 ]; then
                # Éviter les doublons
                local is_duplicate=0
                for existing in "${descriptions[@]}"; do
                    if [ "${existing:0:100}" = "${desc:0:100}" ]; then
                        is_duplicate=1
                        break
                    fi
                done
                
                if [ $is_duplicate -eq 0 ]; then
                    descriptions+=("$desc")
                    years+=("$year")
                    publishers+=("$publisher")
                    sources+=("$source")
                    ((count++))
                    echo -e "    ${GREEN}✓ Description trouvée${NC} ($source) : ${#desc} caractères"
                fi
            fi
        fi
    }
    
    # 1. Google Books - Recherche par ISBN direct
    echo -e "${CYAN}→ Recherche par ISBN...${NC}"
    local response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$GOOGLE_BOOKS_API_KEY")
    local desc=$(echo "$response" | jq -r '.items[0].volumeInfo.description // empty' 2>/dev/null)
    if [ -n "$desc" ] && [ "$desc" != "null" ]; then
        add_if_matches "$desc" "$title" "$authors" \
            "$(echo "$response" | jq -r '.items[0].volumeInfo.publishedDate // "?" | .[0:4]')" \
            "$(echo "$response" | jq -r '.items[0].volumeInfo.publisher // ""')" \
            "Google Books (ISBN direct)"
    fi
    
    # 2. Recherche simple "Dictionnaire symboles" si applicable
    if [[ "$title" =~ [Dd]ictionnaire.*[Ss]ymbole ]]; then
        echo -e "${CYAN}→ Recherche 'Dictionnaire symboles'...${NC}"
        response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Dictionnaire+symboles&maxResults=40&key=$GOOGLE_BOOKS_API_KEY")
        
        for i in $(seq 0 39); do
            local item=$(echo "$response" | jq ".items[$i]" 2>/dev/null)
            if [ "$item" != "null" ] && [ -n "$item" ]; then
                desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
                found_title=$(echo "$item" | jq -r '.volumeInfo.title // ""')
                found_author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // ""')
                year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "" | .[0:4]')
                publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // ""')
                
                add_if_matches "$desc" "$found_title" "$found_author" "$year" "$publisher" "Google Books"
            fi
        done
    fi
    
    # 3. Recherche par titre + auteur
    if [ -n "$authors" ] && [ "$authors" != "Auteur inconnu" ]; then
        echo -e "${CYAN}→ Recherche par titre + auteur...${NC}"
        local search_title=$(echo "$title" | sed 's/[[:punct:]]//g' | tr ' ' '+')
        local search_author=$(echo "$authors" | cut -d',' -f1 | sed 's/[[:punct:]]//g' | tr ' ' '+')
        response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=$search_title+$search_author&maxResults=20&key=$GOOGLE_BOOKS_API_KEY")
        
        for i in $(seq 0 19); do
            local item=$(echo "$response" | jq ".items[$i]" 2>/dev/null)
            if [ "$item" != "null" ] && [ -n "$item" ]; then
                desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
                found_title=$(echo "$item" | jq -r '.volumeInfo.title // ""')
                found_author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // ""')
                year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "" | .[0:4]')
                publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // ""')
                
                add_if_matches "$desc" "$found_title" "$found_author" "$year" "$publisher" "Google Books (titre+auteur)"
            fi
        done
    fi
    
    # 4. ISBN alternatifs pour Dictionnaire des symboles
    if [[ "$title" =~ [Dd]ictionnaire.*[Ss]ymbole ]]; then
        echo -e "${CYAN}→ ISBN alternatifs du Dictionnaire des symboles...${NC}"
        for alt_isbn in "2221501861" "2221081641" "9782221081648" "2850760285"; do
            response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$alt_isbn&key=$GOOGLE_BOOKS_API_KEY")
            local item=$(echo "$response" | jq '.items[0]' 2>/dev/null)
            if [ "$item" != "null" ] && [ -n "$item" ]; then
                desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
                found_title=$(echo "$item" | jq -r '.volumeInfo.title // ""')
                found_author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // ""')
                year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "" | .[0:4]')
                publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // ""')
                
                add_if_matches "$desc" "$found_title" "$found_author" "$year" "$publisher" "Google (ISBN: $alt_isbn)"
            fi
        done
    fi
    
    # Si aucune description trouvée
    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}⚠️  Aucune description trouvée dans d'autres éditions${NC}"
        return 1
    fi
    
    # Mode automatique : prendre la plus longue
    if [ $AUTO_SELECT_DESC -eq 1 ]; then
        echo ""
        echo -e "${CYAN}🤖 Sélection automatique de la meilleure description...${NC}"
        
        # Trouver la description la plus longue
        local best_index=0
        local max_length=0
        for i in "${!descriptions[@]}"; do
            if [ ${#descriptions[$i]} -gt $max_length ]; then
                max_length=${#descriptions[$i]}
                best_index=$i
            fi
        done
        
        local selected_desc="${descriptions[$best_index]}"
        
        echo -e "${GREEN}✅ Description sélectionnée : ${#selected_desc} caractères${NC}"
        echo -e "   Source : ${sources[$best_index]}"
        echo -e "   Année : ${years[$best_index]}"
        if [ -n "${publishers[$best_index]}" ]; then
            echo -e "   Éditeur : ${publishers[$best_index]}"
        fi
        
        # Sauvegarder
        safe_store_meta "$post_id" "_best_description" "$selected_desc"
        safe_store_meta "$post_id" "_best_description_source" "google_editions_auto"
        
        # Mettre à jour le post content aussi
        local safe_desc=$(safe_sql "$selected_desc")
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            UPDATE wp_${SITE_ID}_posts 
            SET post_content = '$safe_desc'
            WHERE ID = $post_id" 2>/dev/null
        
        return 0
    else
        # Mode interactif : afficher toutes les options
        echo ""
        echo "════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}${CYAN}📋 DESCRIPTIONS TROUVÉES : $count${NC}"
        echo "════════════════════════════════════════════════════════════════════"
        
        # Afficher chaque résultat
        for i in "${!descriptions[@]}"; do
            local num=$((i+1))
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "📖 CHOIX #$num - ${YELLOW}${sources[$i]}${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "📅 Année    : ${years[$i]}"
            if [ -n "${publishers[$i]}" ]; then
                echo "🏢 Éditeur  : ${publishers[$i]}"
            fi
            echo "📏 Longueur : ${#descriptions[$i]} caractères"
            echo ""
            echo "📝 Aperçu :"
            echo "────────────────────────────────────────────────────────────────"
            
            if [ ${#descriptions[$i]} -gt 400 ]; then
                echo "${descriptions[$i]:0:400}..."
            else
                echo "${descriptions[$i]}"
            fi
        done
        
        echo ""
        echo "════════════════════════════════════════════════════════════════════"
        echo ""
        echo "📌 Choisir une description (1-$count) ou 0 pour annuler :"
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $count ]; then
            local idx=$((choice-1))
            local selected_desc="${descriptions[$idx]}"
            
            # Sauvegarder
            safe_store_meta "$post_id" "_best_description" "$selected_desc"
            safe_store_meta "$post_id" "_best_description_source" "${sources[$idx]}"
            
            # Mettre à jour le post content
            local safe_desc=$(safe_sql "$selected_desc")
            mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
                UPDATE wp_${SITE_ID}_posts 
                SET post_content = '$safe_desc'
                WHERE ID = $post_id" 2>/dev/null
            
            echo ""
            echo -e "${GREEN}✅ Description sauvegardée !${NC}"
            return 0
        elif [ "$choice" = "0" ]; then
            echo -e "${YELLOW}❌ Sélection annulée${NC}"
            return 1
        else
            echo -e "${RED}❌ Choix invalide${NC}"
            return 1
        fi
    fi
}

# Fonction pour générer la description commerciale
generate_commercial_description_for_book() {
    local post_id="$1"
    local isbn="$2"
    
    echo "[DEBUG] Génération description commerciale pour post_id=$post_id, isbn=$isbn" >&2
    
    # Vérifier si commercial_desc.sh existe
    if [ ! -f "./commercial_desc.sh" ]; then
        echo -e "${YELLOW}⚠️  Script commercial_desc.sh non trouvé${NC}"
        return 1
    fi
    
    # Vérifier si la clé API Claude est configurée
    if [ -z "$CLAUDE_API_KEY" ]; then
        echo -e "${YELLOW}⚠️  Clé API Claude non configurée${NC}"
        return 1
    fi
    
    # Vérifier si une description commerciale existe déjà (sauf si force)
    if [ $FORCE_MODE -eq 0 ]; then
        local existing_commercial=$(get_meta_value "$post_id" "_commercial_description")
        if [ -n "$existing_commercial" ] && [ "$existing_commercial" != "NULL" ]; then
            echo -e "${CYAN}ℹ️  Description commerciale existe déjà${NC}"
            return 0
        fi
    fi
    
    echo ""
    echo -e "${BOLD}${CYAN}🛍️  GÉNÉRATION DESCRIPTION COMMERCIALE...${NC}"
    
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

# Fonction pour générer le message de négociation
generate_negotiation_message() {
    local post_id="$1"
    local isbn="$2"
    
    echo "[DEBUG] Génération message de négociation pour post_id=$post_id, isbn=$isbn" >&2
    
    # Récupérer les infos nécessaires
    local book_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT 
            p.post_title,
            (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = p.ID AND meta_key = '_best_authors' LIMIT 1),
            (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = p.ID AND meta_key = '_price' LIMIT 1)
        FROM wp_${SITE_ID}_posts p
        WHERE p.ID = $post_id
        LIMIT 1" 2>/dev/null)
    
    IFS=$'\t' read -r title authors price <<< "$book_info"
    
    # Calculer le prix réduit
    local reduced_price=$((price - 2))
    
    echo ""
    echo -e "${BOLD}${CYAN}💬 GÉNÉRATION MESSAGE NÉGOCIATION...${NC}"
    
    # Appel à Claude
    local negotiation_msg=$(curl -s -X POST https://api.anthropic.com/v1/messages \
        -H "Content-Type: application/json" \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d '{
            "model": "claude-3-haiku-20240307",
            "max_tokens": 250,
            "messages": [
                {
                    "role": "user",
                    "content": "Tu es un vendeur expert en psychologie de vente sur Leboncoin/Vinted. Un acheteur négocie sur '"$title"' de '"$authors"' que je vends '"$price"'€. Il propose '"$reduced_price"'€.\n\nÉcris une réponse de VENDEUR MALIN qui :\n\n1. NE PARLE JAMAIS des prix des concurrents\n2. NE DIT PAS qu'\''il y a d'\''autres acheteurs (argument faible)\n3. VALORISE SUBTILEMENT l'\''expertise unique de l'\''auteur DIFFÉREMMENT de la description commerciale\n4. Crée une CONNEXION ÉMOTIONNELLE (\"ce livre va vous transformer\", \"vous allez découvrir\", etc.)\n5. Utilise la RARETÉ psychologique (\"exemplaire particulièrement soigné\", \"édition recherchée\")\n6. ANCRE la valeur (\"pour moins qu'\''un restaurant, vous avez 1060 pages de sagesse\")\n7. Reste FERME sur le prix SANS être désagréable\n8. Termine EXACTEMENT par : \"Qu'\''en dites-vous ?\"\n\nTon : Amical mais professionnel, comme un libraire passionné.\nDébut : \"Bonjour,\"\nMax 120 mots. Sois SUBTIL et PSYCHOLOGUE."
                }
            ]
        }' | jq -r '.content[0].text' 2>/dev/null)
    
    if [ -n "$negotiation_msg" ] && [ "$negotiation_msg" != "null" ]; then
        echo -e "${GREEN}✅ Message de négociation généré${NC}"
        
        # Sauvegarder
        safe_store_meta "$post_id" "_negotiation_message" "$negotiation_msg"
        
        echo ""
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${CYAN}💬 MESSAGE DE NÉGOCIATION :${NC}"
        echo ""
        echo -e "${CYAN}$negotiation_msg${NC}"
        echo ""
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}📊 Longueur : ${GREEN}${#negotiation_msg} caractères${NC}"
        
        return 0
    else
        echo -e "${YELLOW}⚠️  Erreur génération message négociation${NC}"
        return 1
    fi
}

# Fonction pour catégoriser avec l'IA
categorize_book_with_ai() {
    local post_id="$1"
    local isbn="$2"
    
    echo "[DEBUG] Tentative de catégorisation IA pour post_id=$post_id, isbn=$isbn" >&2
    
    # Vérifier si une catégorie existe déjà
    local existing_category=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT t.name 
        FROM wp_${SITE_ID}_term_relationships tr
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
        WHERE tr.object_id = $post_id 
        AND tt.taxonomy = 'product_cat'
        AND t.term_id != (SELECT term_id FROM wp_${SITE_ID}_terms WHERE slug = 'uncategorized')
        LIMIT 1" 2>/dev/null)
    
    if [ -n "$existing_category" ] && [ $FORCE_MODE -eq 0 ]; then
        echo ""
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${CYAN}🏷️  CATÉGORIE WORDPRESS EXISTANTE :${NC}"
        echo -e "   ${GREEN}✅ $existing_category${NC}"
        echo -e "${BOLD}${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
        return 0
    fi
    
    # Lancer la catégorisation
    if [ -f "$SCRIPT_DIR/smart_categorize_dual_ai.sh" ]; then
        echo -e "${CYAN}🤖 Catégorisation en cours...${NC}"
        "$SCRIPT_DIR/smart_categorize_dual_ai.sh" "$isbn" 2>/dev/null
    else
        echo -e "${YELLOW}⚠️  Script de catégorisation non trouvé${NC}"
    fi
}

# Fonction pour traiter en masse
process_bulk_books() {
    echo -e "${CYAN}📊 Recherche des livres à traiter...${NC}"
    
    # Récupérer les ISBN sans description
    local isbns=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT DISTINCT pm1.meta_value
        FROM wp_${SITE_ID}_postmeta pm1
        LEFT JOIN wp_${SITE_ID}_postmeta pm2 ON pm1.post_id = pm2.post_id 
            AND pm2.meta_key = '_best_description'
        WHERE pm1.meta_key = '_isbn'
        AND pm1.meta_value != ''
        AND (pm2.meta_value IS NULL OR pm2.meta_value = '' OR pm2.meta_value LIKE 'Description non disponible%')
        LIMIT 10" 2>/dev/null)
    
    local count=$(echo "$isbns" | wc -l)
    echo -e "${GREEN}✓ $count livres à traiter${NC}"
    echo ""
    
    # Traiter chaque ISBN
    local i=1
    while IFS= read -r isbn; do
        if [ -n "$isbn" ]; then
            echo -e "${BOLD}${BLUE}[$i/$count] Traitement de : $isbn${NC}"
            echo "════════════════════════════════════════════"
            
            process_single_isbn "$isbn"
            
            echo ""
            echo ""
            ((i++))
            
            # Pause entre les traitements
            sleep 2
        fi
    done <<< "$isbns"
    
    echo -e "${GREEN}✅ Traitement en masse terminé${NC}"
}

# Fonction pour traiter les livres sans description
process_books_without_description() {
    echo -e "${CYAN}📊 Recherche des livres sans description...${NC}"
    
    local isbns=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT DISTINCT pm1.meta_value
        FROM wp_${SITE_ID}_postmeta pm1
        LEFT JOIN wp_${SITE_ID}_postmeta pm2 ON pm1.post_id = pm2.post_id 
            AND pm2.meta_key = '_best_description'
        WHERE pm1.meta_key = '_isbn'
        AND pm1.meta_value != ''
        AND (pm2.meta_value IS NULL OR pm2.meta_value = '' OR LENGTH(pm2.meta_value) < 50)
        ORDER BY pm1.post_id DESC
        LIMIT 20" 2>/dev/null)
    
    local count=$(echo "$isbns" | wc -l)
    echo -e "${GREEN}✓ $count livres sans description trouvés${NC}"
    echo ""
    
    local i=1
    while IFS= read -r isbn; do
        if [ -n "$isbn" ]; then
            echo -e "${BOLD}${BLUE}[$i/$count] ISBN : $isbn${NC}"
            process_single_isbn "$isbn"
            echo ""
            ((i++))
            sleep 1
        fi
    done <<< "$isbns"
}

# Fonction pour traiter les livres incomplets
process_incomplete_books() {
    echo -e "${CYAN}📊 Recherche des livres avec données incomplètes...${NC}"
    
    # Requête pour trouver les livres avec peu de métadonnées
    local isbns=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT pm.meta_value, COUNT(pm2.meta_key) as meta_count
        FROM wp_${SITE_ID}_postmeta pm
        LEFT JOIN wp_${SITE_ID}_postmeta pm2 ON pm.post_id = pm2.post_id
        WHERE pm.meta_key = '_isbn'
        AND pm.meta_value != ''
        GROUP BY pm.post_id, pm.meta_value
        HAVING meta_count < 50
        ORDER BY meta_count ASC
        LIMIT 15" 2>/dev/null | cut -f1)
    
    local count=$(echo "$isbns" | wc -l)
    echo -e "${GREEN}✓ $count livres incomplets trouvés${NC}"
    echo ""
    
    local i=1
    while IFS= read -r isbn; do
        if [ -n "$isbn" ]; then
            echo -e "${BOLD}${BLUE}[$i/$count] ISBN : $isbn${NC}"
            process_single_isbn "$isbn" -force
            echo ""
            ((i++))
            sleep 1
        fi
    done <<< "$isbns"
}

# Fonction pour vérifier la complétude d'un livre
verify_book_completeness() {
    local isbn="$1"
    local post_id=$(get_post_id_by_isbn "$isbn")
    
    if [ -z "$post_id" ]; then
        echo -e "${RED}❌ ISBN non trouvé : $isbn${NC}"
        return 1
    fi
    
    echo -e "${BOLD}${CYAN}📊 VÉRIFICATION DE COMPLÉTUDE${NC}"
    echo "════════════════════════════════════════════"
    
    # Afficher la martingale
    display_martingale_complete "$post_id" "$isbn"
    
    # Vérifier les champs critiques
    echo ""
    echo -e "${BOLD}${BLUE}🔍 ANALYSE DES DONNÉES MANQUANTES :${NC}"
    
    local missing=0
    
    # Vérifier description
    local desc=$(get_meta_value "$post_id" "_best_description")
    if [ -z "$desc" ] || [ ${#desc} -lt 50 ]; then
        echo -e "${RED}❌ Description manquante ou trop courte${NC}"
        ((missing++))
    fi
    
    # Vérifier image
    local image=$(get_meta_value "$post_id" "_best_cover_image")
    if [ -z "$image" ]; then
        echo -e "${RED}❌ Image de couverture manquante${NC}"
        ((missing++))
    fi
    
    # Vérifier prix
    local price=$(get_meta_value "$post_id" "_price")
    if [ -z "$price" ] || [ "$price" = "0" ]; then
        echo -e "${RED}❌ Prix non défini${NC}"
        ((missing++))
    fi
    
    # Vérifier description commerciale
    local commercial=$(get_meta_value "$post_id" "_commercial_description")
    if [ -z "$commercial" ]; then
        echo -e "${YELLOW}⚠️  Description commerciale non générée${NC}"
        ((missing++))
    fi
    
    if [ $missing -eq 0 ]; then
        echo -e "${GREEN}✅ Toutes les données sont complètes !${NC}"
    else
        echo -e "${YELLOW}⚠️  $missing données manquantes${NC}"
        echo ""
        echo -e "${CYAN}💡 Pour compléter : $0 $isbn -force${NC}"
    fi
}

# Fonction pour vérifier si un livre a déjà des données
check_book_has_data() {
    local post_id="$1"
    
    # Vérifier si on a des données principales
    local has_data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $post_id 
        AND meta_key IN ('_best_title', '_best_description', '_g_title', '_i_title', '_o_title')
        AND meta_value != '' 
        AND meta_value != 'NULL'"
        2>/dev/null)
    
    if [ "$has_data" -gt 0 ]; then
        echo "1"
    else
        echo "0"
    fi
}

# Fonction pour traiter un ISBN individuel
process_single_isbn() {
    local isbn="$1"
    
    # Valider l'ISBN
    local clean_isbn=$(validate_isbn "$isbn")
    if [ -z "$clean_isbn" ]; then
        echo -e "${RED}❌ ISBN invalide : $isbn${NC}"
        return 1
    fi
    
    # Vérifier si le livre existe
    local post_id=$(get_post_id_by_isbn "$clean_isbn")
    
    if [ -n "$post_id" ]; then
        echo -e "${GREEN}✓ Livre trouvé (ID: $post_id)${NC}"
        
        # Vérifier si on force la mise à jour
        if [ $FORCE_MODE -eq 0 ]; then
            local has_data=$(check_book_has_data "$post_id")
            if [ "$has_data" = "1" ]; then
                echo -e "${CYAN}ℹ️  Le livre a déjà des données. Utilisez -force pour mettre à jour.${NC}"
                
                # Afficher quand même la martingale
                echo ""
                display_martingale_complete "$post_id" "$clean_isbn"
                
                # Générer la description commerciale si manquante
                if [ $GENERATE_COMMERCIAL -eq 1 ]; then
                    generate_commercial_description_for_book "$post_id" "$clean_isbn"
                fi
                
                return 0
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Livre non trouvé dans la base${NC}"
        echo -e "${CYAN}ℹ️  Ajout du livre...${NC}"
        
        # Ajouter le livre
        post_id=$(add_book_to_wordpress "$clean_isbn")
        if [ -z "$post_id" ]; then
            echo -e "${RED}❌ Erreur lors de l'ajout du livre${NC}"
            return 1
        fi
        echo -e "${GREEN}✓ Livre ajouté (ID: $post_id)${NC}"
    fi
    
    # Collecter les données
    echo ""
    echo -e "${BOLD}${BLUE}📡 COLLECTE DES DONNÉES...${NC}"
    
    # Appeler chaque API
    echo -e "${CYAN}→ Google Books...${NC}"
    collect_google_books "$post_id" "$clean_isbn"
    
    echo -e "${CYAN}→ ISBNdb...${NC}"
    collect_isbndb "$post_id" "$clean_isbn"
    
    echo -e "${CYAN}→ Open Library...${NC}"
    collect_open_library "$post_id" "$clean_isbn"
    
    # Traiter et enrichir les données avec la martingale complète
    echo ""
    echo -e "${BOLD}${PURPLE}🎰 ENRICHISSEMENT MARTINGALE...${NC}"
    local process_status=0
    if ! enrich_metadata_complete "$post_id" "$clean_isbn"; then
        echo -e "${YELLOW}⚠️  Enrichissement partiel${NC}"
        process_status=1
    fi
    
    # Vérifier si on a une description, sinon chercher dans d'autres éditions
    local description=$(get_meta_value "$post_id" "_best_description")
    if [ -z "$description" ] || [ ${#description} -lt 50 ] || [[ "$description" == "Description non disponible"* ]]; then
        echo ""
        echo -e "${BOLD}${YELLOW}🔍 RECHERCHE D'AUTRES ÉDITIONS...${NC}"
        find_editions_for_description "$post_id" "$clean_isbn"
    fi
    
    # Afficher les résultats de la martingale complète
    echo ""
    display_martingale_complete "$post_id" "$clean_isbn"
    
    # Appeler la catégorisation IA si configurée
    if [ -f "$SCRIPT_DIR/smart_categorize_dual_ai.sh" ]; then
        echo ""
        echo -e "${BOLD}${CYAN}🤖 CATÉGORISATION IA...${NC}"
        if [ -n "$GEMINI_API_KEY" ] || [ -n "$CLAUDE_API_KEY" ]; then
            categorize_book_with_ai "$post_id" "$clean_isbn"
        else
            echo -e "${YELLOW}⚠️  APIs IA non configurées${NC}"
        fi
    fi
    
    # Générer la description commerciale
    if [ $GENERATE_COMMERCIAL -eq 1 ] && [ $process_status -eq 0 ]; then
        generate_commercial_description_for_book "$post_id" "$clean_isbn"
    fi
    
    # Générer le message de négociation si demandé
    if [ $GENERATE_NEGOTIATION -eq 1 ] && [ $process_status -eq 0 ]; then
        generate_negotiation_message "$post_id" "$clean_isbn"
    fi
    
    return $process_status
}

# Fonction principale
main() {
    echo "[DEBUG] Mode: $PARAM_ACTION, ISBN: $PARAM_ISBN" >&2
    
    # Si pas d'action spécifiée et pas d'ISBN, afficher l'aide
    if [ -z "$PARAM_ACTION" ] && [ -z "$PARAM_ISBN" ]; then
        show_help
        exit 0
    fi
    
    # Traiter selon l'action
    if [ -n "$PARAM_ACTION" ]; then
        case "$PARAM_ACTION" in
            bulk)
                echo -e "${BOLD}${BLUE}📚 Mode traitement en masse${NC}"
                process_bulk_books
                ;;
            missing)
                echo -e "${BOLD}${BLUE}📚 Traitement des livres sans description${NC}"
                process_books_without_description
                ;;
            incomplete)
                echo -e "${BOLD}${BLUE}📚 Traitement des livres incomplets${NC}"
                process_incomplete_books
                ;;
            martingale)
                if [ -z "$3" ]; then
                    echo -e "${RED}❌ ISBN requis pour afficher la martingale${NC}"
                    exit 1
                fi
                local post_id=$(get_post_id_by_isbn "$3")
                if [ -n "$post_id" ]; then
                    display_martingale_complete "$post_id" "$3"
                else
                    echo -e "${RED}❌ ISBN non trouvé : $3${NC}"
                fi
                ;;
            verify)
                if [ -z "$3" ]; then
                    echo -e "${RED}❌ ISBN requis pour la vérification${NC}"
                    exit 1
                fi
                verify_book_completeness "$3"
                ;;
            *)
                echo -e "${RED}❌ Action inconnue : $PARAM_ACTION${NC}"
                show_help
                exit 1
                ;;
        esac
    else
        # Mode traitement individuel
        echo -e "${BOLD}${BLUE}📚 Mode traitement individuel${NC}"
        process_single_isbn "$PARAM_ISBN"
    fi
}

# Exécuter le script principal
main

echo "[END: isbn_unified.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2