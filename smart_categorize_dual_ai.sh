#!/bin/bash
# ⚠️  FICHIER CRITIQUE - NE JAMAIS SUPPRIMER ⚠️
# smart_categorize_dual_ai.sh - Double IA qui débattent pour catégoriser

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

# Mode debug
SHOW_PROMPTS="${SHOW_PROMPTS:-0}"

# Vérifier si -noverbose est présent dans les arguments
VERBOSE=1
for arg in "$@"; do
    if [ "$arg" = "-noverbose" ]; then
        VERBOSE=0
        break
    fi
done

# Charger les modules
source "$SCRIPT_DIR/lib/ai_common.sh"
source "$SCRIPT_DIR/lib/category_functions.sh"
source "$SCRIPT_DIR/lib/ask_gemini.sh"
source "$SCRIPT_DIR/lib/ask_claude.sh"

# Fonction principale de catégorisation
categorize_with_dual_ai() {
    local post_id="$1"
    debug_echo "[DEBUG] === DÉBUT categorize_with_dual_ai pour post_id=$post_id ==="
    
    # Récupérer les infos du livre
    debug_echo "[DEBUG] Récupération des infos du livre ID $post_id..."
    local book_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT 
        p.post_title,
        IFNULL(pm_isbn.meta_value, '') as isbn,
        IFNULL(pm_authors.meta_value, IFNULL(pm_authors2.meta_value, '')) as authors,
        IFNULL(pm_desc.meta_value, IFNULL(pm_desc2.meta_value, '')) as description
    FROM wp_${SITE_ID}_posts p
    LEFT JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_authors2 ON p.ID = pm_authors2.post_id AND pm_authors2.meta_key = '_g_authors'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_desc2 ON p.ID = pm_desc2.post_id AND pm_desc2.meta_key = '_g_description'
    WHERE p.ID = $post_id
    " 2>/dev/null)
    
    debug_echo "[DEBUG] book_info trouvé : $(echo "$book_info" | wc -c) caractères"
    
    if [ -z "$book_info" ]; then
        debug_echo "[DEBUG] ERREUR : Aucune info trouvée pour ID $post_id"
        echo -e "${RED}❌ Livre ID $post_id non trouvé${NC}"
        return 1
    fi
    
    # Parser les infos
    IFS=$'\t' read -r title isbn authors description <<< "$book_info"
    debug_echo "[DEBUG] Infos parsées :"
    debug_echo "[DEBUG]   title='$title'"
    debug_echo "[DEBUG]   isbn='$isbn'"
    debug_echo "[DEBUG]   authors='$authors'"
    debug_echo "[DEBUG]   description length=$(echo "$description" | wc -c)"
    
    # Nettoyer le titre s'il commence par "Livre ISBN"
    if [[ "$title" =~ ^Livre[[:space:]]+[0-9]+ ]]; then
        debug_echo "[DEBUG] Titre générique détecté, recherche du vrai titre..."
        # Chercher _best_title ou _g_title
        local real_title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT IFNULL(
            (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = $post_id AND meta_key = '_best_title' LIMIT 1),
            (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = $post_id AND meta_key = '_g_title' LIMIT 1)
        )" 2>/dev/null)
        
        if [ -n "$real_title" ] && [ "$real_title" != "NULL" ]; then
            title="$real_title"
            debug_echo "[DEBUG] Vrai titre trouvé : '$title'"
        fi
    fi
    
    echo ""
    echo -e "📚 LIVRE : ${RED}${BOLD}$title${NC}"
    echo -e "   ISBN : ${CYAN}${isbn:-N/A}${NC}"
    echo -e "   Auteurs : ${BLUE}${authors:-N/A}${NC}"
    
    # Afficher la description
    if [ -n "$description" ] && [ "$description" != "NULL" ]; then
        echo -e "   Description : ${YELLOW}$(echo "$description" | sed 's/<[^>]*>//g' | cut -c1-150)...${NC}"
    else
        echo -e "   Description : ${YELLOW}Non disponible${NC}"
    fi
    echo ""
    
    # Obtenir la liste des catégories AVEC HIÉRARCHIE
    echo "📋 Récupération des catégories avec hiérarchie..."
    local categories_list=$(get_all_categories_with_hierarchy)
    local cat_count=$(echo "$categories_list" | wc -l)
    echo "   $cat_count catégories disponibles"
    debug_echo "[DEBUG] Exemples de catégories avec hiérarchie :"
    if [ "$VERBOSE" = "1" ]; then
        echo "$categories_list" | head -5 | while read line; do
            debug_echo "[DEBUG]   $line"
        done
    fi
    
    # Premier round : demander aux deux IA
    echo ""
    echo -e "${BOLD}🤖 ROUND 1 - Première analyse...${NC}"
    
    # Variables pour stocker les statuts
    local gemini_success=0
    local claude_success=0
    
    echo -n "   Gemini analyse... "
    debug_echo "[DEBUG] Appel ask_gemini Round 1..."
    local gemini_choice_1=$(ask_gemini "$title" "$authors" "$description" "$categories_list")
    local gemini_status=$?
    debug_echo "[DEBUG] Retour ask_gemini Round 1 : '$gemini_choice_1' (status=$gemini_status)"
    
    if [ $gemini_status -eq 0 ] && [ -n "$gemini_choice_1" ] && [[ "$gemini_choice_1" =~ ^[0-9]+$ ]]; then
        local gemini_cat_1=$(get_category_with_parent "$gemini_choice_1")
        echo -e "${GREEN}Gemini choisit : ${BOLD}$gemini_cat_1${NC}"
        gemini_success=1
    else
        debug_echo "[DEBUG] ERREUR : gemini_choice_1 invalide : '$gemini_choice_1'"
        echo -e "${RED}Gemini ne répond pas correctement !${NC}"
    fi
    
    echo -n "   Claude analyse... "
    debug_echo "[DEBUG] Appel ask_claude Round 1..."
    local claude_choice_1=$(ask_claude "$title" "$authors" "$description" "$categories_list")
    local claude_status=$?
    debug_echo "[DEBUG] Retour ask_claude Round 1 : '$claude_choice_1' (status=$claude_status)"
    
    if [ $claude_status -eq 0 ] && [ -n "$claude_choice_1" ] && [[ "$claude_choice_1" =~ ^[0-9]+$ ]]; then
        local claude_cat_1=$(get_category_with_parent "$claude_choice_1")
        echo -e "${BLUE}Claude choisit : ${BOLD}$claude_cat_1${NC}"
        claude_success=1
    else
        debug_echo "[DEBUG] ERREUR : claude_choice_1 invalide : '$claude_choice_1'"
        echo -e "${RED}Claude ne répond pas correctement !${NC}"
    fi
    
    # VÉRIFIER SI LES IA ONT RÉPONDU - NOUVELLE RÈGLE
    if [ $claude_success -eq 0 ]; then
        # Claude n'a pas répondu = toujours échec
        echo ""
        echo -e "${RED}${BOLD}❌ ÉCHEC : Claude n'a pas répondu${NC}"
        echo -e "${YELLOW}La catégorisation nécessite au minimum Claude${NC}"
        return 1
    elif [ $gemini_success -eq 0 ] && [ $claude_success -eq 1 ]; then
        # Seulement Claude a répondu = on prend Claude
        echo ""
        echo -e "${YELLOW}${BOLD}⚠️  Seul Claude a répondu - on prend son choix${NC}"
        local final_choice=$claude_choice_1
        local final_cat_name=$(get_category_with_parent "$final_choice")
        echo -e "${BLUE}Catégorie Claude : ${BOLD}$final_cat_name${NC}"
        
        # Passer directement à l'application
        echo ""
        echo -e "\n${RED}${BOLD}📌 CATÉGORIE FINALE : $final_cat_name${NC}\n"
        
        # Appliquer la catégorie
        if apply_category_to_product "$post_id" "$final_choice" "$final_cat_name"; then
            # Log
            mkdir -p "$LOG_DIR"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ID:$post_id - $title → $final_cat_name (Claude seul)" >> "$LOG_DIR/dual_ai_categorize.log"
            return 0
        else
            return 1
        fi
    fi
    
    # Vérifier si accord
    debug_echo "[DEBUG] Comparaison : gemini='$gemini_choice_1' vs claude='$claude_choice_1'"
    if [ "$gemini_choice_1" = "$claude_choice_1" ]; then
        echo ""
        echo -e "\n${GREEN}${BOLD}✅ ACCORD IMMÉDIAT sur : $gemini_cat_1${NC}"
        local final_choice=$gemini_choice_1
    else
        # Désaccord - Round 2
        echo ""
        echo -e "\n${RED}${BOLD}❌ DÉSACCORD ! Round 2...${NC}"
        
        # Reset des statuts pour le round 2
        gemini_success=0
        claude_success=0
        
        echo -n "   Gemini reconsidère... "
        debug_echo "[DEBUG] Appel ask_gemini Round 2 avec suggestion Claude=$claude_choice_1..."
        local gemini_choice_2=$(ask_gemini "$title" "$authors" "$description" "$categories_list" "$claude_choice_1")
        local gemini_status_2=$?
        debug_echo "[DEBUG] Retour ask_gemini Round 2 : '$gemini_choice_2' (status=$gemini_status_2)"
        
        if [ $gemini_status_2 -eq 0 ] && [ -n "$gemini_choice_2" ] && [[ "$gemini_choice_2" =~ ^[0-9]+$ ]]; then
            local gemini_cat_2=$(get_category_with_parent "$gemini_choice_2")
            echo -e "${GREEN}Gemini change pour : ${BOLD}$gemini_cat_2${NC}"
            gemini_success=1
        else
            echo -e "${RED}Gemini échoue au round 2${NC}"
            gemini_choice_2=$gemini_choice_1
            gemini_cat_2=$gemini_cat_1
            if [ -n "$gemini_choice_1" ]; then
                gemini_success=1  # On garde son premier choix
            fi
        fi
        
        echo -n "   Claude reconsidère... "
        debug_echo "[DEBUG] Appel ask_claude Round 2 avec suggestion Gemini=$gemini_choice_1..."
        local claude_choice_2=$(ask_claude "$title" "$authors" "$description" "$categories_list" "$gemini_choice_1")
        local claude_status_2=$?
        debug_echo "[DEBUG] Retour ask_claude Round 2 : '$claude_choice_2' (status=$claude_status_2)"
        
        if [ $claude_status_2 -eq 0 ] && [ -n "$claude_choice_2" ] && [[ "$claude_choice_2" =~ ^[0-9]+$ ]]; then
            local claude_cat_2=$(get_category_with_parent "$claude_choice_2")
            echo -e "${BLUE}Claude change pour : ${BOLD}$claude_cat_2${NC}"
            claude_success=1
        else
            echo -e "${RED}Claude échoue au round 2${NC}"
            claude_choice_2=$claude_choice_1
            claude_cat_2=$claude_cat_1
            if [ -n "$claude_choice_1" ]; then
                claude_success=1  # On garde son premier choix
            fi
        fi
        
        # Vérifier à nouveau avec la nouvelle règle
        if [ $claude_success -eq 0 ]; then
            # Claude doit toujours répondre
            echo ""
            echo -e "${RED}${BOLD}❌ ÉCHEC AU ROUND 2 : Claude n'a pas répondu${NC}"
            return 1
        elif [ $gemini_success -eq 0 ] && [ $claude_success -eq 1 ]; then
            # Si seulement Claude répond au round 2, on prend son choix
            echo ""
            echo -e "${YELLOW}${BOLD}⚠️  Seul Claude répond au round 2 - on prend son choix${NC}"
            local final_choice=$claude_choice_2
            local final_cat_name=$(get_category_with_parent "$final_choice")
        else
            # Les deux ont répondu, continuer normalement
            debug_echo "[DEBUG] Les deux IA ont des choix valides au round 2"
        fi
        
        # Suite du traitement seulement si les deux IA ont répondu
        if [ $gemini_success -eq 1 ] && [ $claude_success -eq 1 ]; then
            # Résultat final avec débat normal
            debug_echo "[DEBUG] Comparaison Round 2 : gemini='$gemini_choice_2' vs claude='$claude_choice_2'"
            if [ "$gemini_choice_2" = "$claude_choice_2" ]; then
                echo ""
                echo -e "\n${GREEN}${BOLD}✅ CONSENSUS TROUVÉ sur : $gemini_cat_2${NC}"
                local final_choice=$gemini_choice_2
            else
                echo ""
                echo -e "${YELLOW}⚠️  PAS DE CONSENSUS${NC}"
                echo -e "   Choix final de Gemini : ${GREEN}$gemini_cat_2${NC}"
                echo -e "   Choix final de Claude : ${BLUE}$claude_cat_2${NC}"
                # En cas de désaccord persistant, prendre Claude
                local final_choice=$claude_choice_2
                echo -e "   → Choix retenu : ${BOLD}$claude_cat_2 (Claude)${NC}"
            fi
        fi
    fi
    
    debug_echo "[DEBUG] Choix final : ID=$final_choice"
    
    # Vérifier que final_choice est valide
    if [ -z "$final_choice" ] || ! [[ "$final_choice" =~ ^[0-9]+$ ]]; then
        debug_echo "[DEBUG] ERREUR : final_choice invalide : '$final_choice'"
        echo -e "${RED}❌ Erreur : Aucune catégorie valide choisie${NC}"
        return 1
    fi
    
    # Récupérer le nom complet de la catégorie finale
    local final_cat_name=$(get_category_with_parent "$final_choice")
    
    echo ""
    echo -e "\n${RED}${BOLD}📌 CATÉGORIE FINALE : $final_cat_name${NC}\n"
    
    # Appliquer la catégorie
    if apply_category_to_product "$post_id" "$final_choice" "$final_cat_name"; then
        # Log
        mkdir -p "$LOG_DIR"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ID:$post_id - $title → $final_cat_name" >> "$LOG_DIR/dual_ai_categorize.log"
        debug_echo "[DEBUG] === FIN categorize_with_dual_ai ==="
        return 0
    else
        return 1
    fi
}

# Programme principal
clear
echo -e "${BOLD}=== SMART CATEGORIZE - DUAL AI MODE ===${NC}"
echo "Gemini + Claude débattent pour trouver la meilleure catégorie"
echo "════════════════════════════════════════════════════════════════════════════"

# Vérifier les clés
debug_echo "[DEBUG] Vérification des clés API..."
debug_echo "[DEBUG] GEMINI_API_KEY : ${GEMINI_API_KEY:0:10}..."
debug_echo "[DEBUG] CLAUDE_API_KEY : ${CLAUDE_API_KEY:0:10}..."

if [ -z "$GEMINI_API_KEY" ] || [ -z "$CLAUDE_API_KEY" ]; then
    echo -e "${RED}❌ ERREUR : Les deux clés API sont requises${NC}"
    echo "Lancez : ./setup_dual_ai.sh"
    exit 1
fi

# Si mode debug
if [ "$SHOW_PROMPTS" = "1" ] && [ "$VERBOSE" = "1" ]; then
    echo ""
    echo -e "${YELLOW}🔍 MODE DEBUG ACTIVÉ - Les prompts seront affichés${NC}"
    echo ""
fi

# Retirer -noverbose des arguments pour le traitement
args=()
for arg in "$@"; do
    if [ "$arg" != "-noverbose" ]; then
        args+=("$arg")
    fi
done

# Menu
if [ ${#args[@]} -eq 0 ]; then
    echo ""
    echo "Usage :"
    echo -e "  ${CYAN}./smart_categorize_dual_ai.sh ISBN${NC}"
    echo -e "  ${CYAN}./smart_categorize_dual_ai.sh -id ID${NC}"
    echo -e "  ${CYAN}./smart_categorize_dual_ai.sh -batch N${NC}"
    echo -e "  ${CYAN}./smart_categorize_dual_ai.sh ISBN -noverbose${NC}"
    echo ""
    echo -e "Mode debug : ${YELLOW}SHOW_PROMPTS=1 ./smart_categorize_dual_ai.sh ISBN${NC}"
    echo ""
    echo -n "ISBN ou ID du livre : "
    read input
else
    input="${args[0]}"
fi

debug_echo "[DEBUG] Input reçu : '$input'"

# Traiter l'input
case "$input" in
    -id)
        debug_echo "[DEBUG] Mode ID direct : ID=${args[1]}"
        categorize_with_dual_ai "${args[1]}"
        ;;
    -batch)
        limit="${args[1]:-5}"
        echo -e "${BOLD}Catégorisation de $limit livres...${NC}"
        debug_echo "[DEBUG] Recherche de $limit livres sans catégorie..."
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT DISTINCT p.ID
        FROM wp_${SITE_ID}_posts p
        LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
        LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        WHERE p.post_type = 'product'
        AND p.post_status = 'publish'
        AND (tt.taxonomy != 'product_cat' OR tt.taxonomy IS NULL)
        LIMIT $limit
        " 2>/dev/null | while read post_id; do
            debug_echo "[DEBUG] Traitement du livre ID=$post_id"
            categorize_with_dual_ai "$post_id"
            echo "════════════════════════════════════════════════════════════════════════════"
            sleep 2  # Pause entre chaque livre
        done
        ;;
    *)
        # Chercher par ISBN
        debug_echo "[DEBUG] Recherche par ISBN : '$input'"
        post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key = '_isbn' AND meta_value = '$input'
        LIMIT 1
        " 2>/dev/null)
        
        debug_echo "[DEBUG] Post ID trouvé : '$post_id'"
        
        if [ -n "$post_id" ]; then
            categorize_with_dual_ai "$post_id"
        else
            echo -e "${RED}❌ ISBN '$input' non trouvé${NC}"
        fi
        ;;
esac

echo ""
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"