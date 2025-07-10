#!/bin/bash
# ⚠️  FICHIER CRITIQUE - NE JAMAIS SUPPRIMER ⚠️
# smart_categorize_dual_ai.sh - Double IA qui débattent pour catégoriser

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

# Couleurs pour affichage
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m" # No Color

# Mode debug
# Si pas de paramètre SHOW_PROMPTS, le mettre à 0 par défaut
SHOW_PROMPTS="${SHOW_PROMPTS:-0}"

# Vérifier si -noverbose est présent dans les arguments
VERBOSE=1
for arg in "$@"; do
    if [ "$arg" = "-noverbose" ]; then
        VERBOSE=0
        break
    fi
done

# Fonction pour afficher les messages de debug
debug_echo() {
    if [ "$VERBOSE" = "1" ]; then
        echo "$@" >&2
    fi
}

# Fonction pour extraire le texte des réponses JSON des IA
extract_text_from_json() {
    local json="$1"
    local api_type="$2"  # "gemini" ou "claude"
    
    debug_echo "[DEBUG] Extraction pour $api_type..."
    debug_echo "[DEBUG] JSON length: ${#json}"
    
    # Essayer Python en premier
    local result
    if [ "$api_type" = "gemini" ]; then
        result=$(echo "$json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    text = data['candidates'][0]['content']['parts'][0]['text']
    print(text.strip())
except Exception as e:
    print(f'ERREUR: {e}', file=sys.stderr)
" 2>/dev/null)
    else  # claude
        result=$(echo "$json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    text = data['content'][0]['text']
    print(text.strip())
except Exception as e:
    print(f'ERREUR: {e}', file=sys.stderr)
" 2>/dev/null)
    fi
    
    debug_echo "[DEBUG] Result before cleaning: '$result'"
    debug_echo "[DEBUG] Result length: ${#result}"
    
    # Nettoyer le résultat - garder uniquement les chiffres
    result=$(echo "$result" | tr -d '\n\r' | grep -o '[0-9]\+' | head -1)
    
    debug_echo "[DEBUG] Résultat extrait et nettoyé : '$result'"
    debug_echo "[DEBUG] Final length: ${#result}"
    
    echo "$result"
}

# Fonction pour analyser les erreurs API
analyze_api_error() {
    local response="$1"
    local api_name="$2"
    
    # TOUJOURS afficher les erreurs, même en mode -noverbose
    
    # Vérifier quota dépassé
    if echo "$response" | grep -q "quota\|RESOURCE_EXHAUSTED\|exceeded"; then
        echo -e "${RED}❌ ERREUR : Quota $api_name dépassé !${NC}"
        if echo "$response" | grep -q "quotaValue"; then
            local quota=$(echo "$response" | grep -o '"quotaValue":[^,}]*' | cut -d'"' -f4)
            echo -e "${YELLOW}   Limite : $quota requêtes/jour${NC}"
        fi
        # Afficher le message d'erreur complet pour Gemini (2e avis)
        if [ "$api_name" = "Gemini (2e avis)" ] && echo "$response" | grep -q '"message"'; then
            local error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d':' -f2- | tr -d '"')
            echo -e "${YELLOW}   Message : $error_msg${NC}"
        fi
        return 1
    fi
    
    # Vérifier rate limit
    if echo "$response" | grep -q "rate_limit\|too_many_requests"; then
        echo -e "${YELLOW}⚠️  ERREUR : Rate limit $api_name atteint${NC}"
        if echo "$response" | grep -q "retryDelay"; then
            local delay=$(echo "$response" | grep -o '"retryDelay":[^,}]*' | cut -d'"' -f4)
            echo -e "${YELLOW}   Attendre : $delay${NC}"
        fi
        # Message spécifique pour Gemini (2e avis)
        if [ "$api_name" = "Gemini (2e avis)" ]; then
            local error_detail=$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null)
            [ -n "$error_detail" ] && echo -e "${YELLOW}   Détail : $error_detail${NC}"
        fi
        return 1
    fi
    
    # Vérifier clé invalide
    if echo "$response" | grep -q "invalid_api_key\|authentication_error"; then
        echo -e "${RED}❌ ERREUR : Clé API $api_name invalide !${NC}"
        return 1
    fi
    
    # Vérifier crédit insuffisant
    if echo "$response" | grep -q "insufficient_credits"; then
        echo -e "${RED}❌ ERREUR : Crédits $api_name insuffisants !${NC}"
        echo -e "${YELLOW}   Vérifier : https://console.anthropic.com/billing${NC}"
        return 1
    fi
    
    # Autres erreurs - TOUJOURS afficher pour comprendre
    if echo "$response" | grep -q '"error"'; then
        echo -e "${RED}❌ ERREUR $api_name :${NC}"
        # Extraire et afficher le message d'erreur
        local error_msg=$(echo "$response" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if 'error' in d:
        print(d['error'].get('message', str(d['error'])))
except:
    print('Erreur inconnue')
" 2>/dev/null || echo "$response" | grep -o '"message":"[^"]*"' | head -1)
        echo -e "${YELLOW}   $error_msg${NC}"
        
        # En mode verbose, afficher plus de détails
        debug_echo "[DEBUG] Réponse complète : $response"
        return 1
    fi
    
    return 0
}

# Obtenir toutes les catégories avec leur hiérarchie
get_all_categories_with_hierarchy() {
    debug_echo "[DEBUG] Récupération des catégories AVEC hiérarchie..."
    
    # Récupérer TOUTES les catégories (pas seulement les finales)
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    WITH RECURSIVE category_path AS (
        -- Cas de base : catégories sans parent
        SELECT 
            t.term_id,
            t.name,
            tt.parent,
            CAST(t.name AS CHAR(1000)) AS path,
            t.term_id AS final_id,
            t.name AS final_name
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE tt.taxonomy = 'product_cat' 
        AND tt.parent = 0
        AND t.term_id NOT IN (15, 16)
        
        UNION ALL
        
        -- Cas récursif : ajouter les enfants
        SELECT 
            t.term_id,
            t.name,
            tt.parent,
            CONCAT(cp.path, ' > ', t.name) AS path,
            t.term_id AS final_id,
            t.name AS final_name
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        JOIN category_path cp ON tt.parent = cp.term_id
        WHERE tt.taxonomy = 'product_cat'
    )
    SELECT CONCAT(path, ' (ID:', final_id, ')') AS category_line
    FROM category_path
    WHERE final_id NOT IN (
        SELECT DISTINCT parent 
        FROM wp_${SITE_ID}_term_taxonomy 
        WHERE taxonomy = 'product_cat' AND parent != 0
    )
    ORDER BY path
    " 2>/dev/null
}

# Obtenir la hiérarchie complète d'une catégorie
get_category_with_parent() {
    local cat_id=$1
    debug_echo "[DEBUG] Recherche hiérarchie pour cat_id='$cat_id'"
    [ -z "$cat_id" ] && { debug_echo "[DEBUG] ERREUR : cat_id vide !"; return; }
    
    # Fonction récursive pour remonter toute la hiérarchie
    get_full_path() {
        local id=$1
        local result=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT t.name, tt.parent
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE t.term_id = $id" 2>/dev/null)
        
        if [ -n "$result" ]; then
            local name=$(echo "$result" | cut -f1)
            local parent=$(echo "$result" | cut -f2)
            
            if [ "$parent" != "0" ] && [ -n "$parent" ]; then
                local parent_path=$(get_full_path $parent)
                echo "$parent_path > $name"
            else
                echo "$name"
            fi
        fi
    }
    
    local full_path=$(get_full_path $cat_id)
    debug_echo "[DEBUG] Hiérarchie trouvée : '$full_path'"
    echo "$full_path"
}

# Demander à Gemini
ask_gemini() {
    debug_echo "[DEBUG] === DÉBUT ask_gemini ==="
    local title="$1"
    local authors="$2"
    local description="$3"
    local categories_list="$4"
    local previous_claude_response="${5:-}"
    
    debug_echo "[DEBUG] Paramètres reçus :"
    debug_echo "[DEBUG]   title='${title:0:50}...'"
    debug_echo "[DEBUG]   authors='$authors'"
    debug_echo "[DEBUG]   description length=$(echo "$description" | wc -c)"
    debug_echo "[DEBUG]   categories count=$(echo "$categories_list" | wc -l)"
    debug_echo "[DEBUG]   previous_claude='$previous_claude_response'"
    
    # Préparer le prompt
    local prompt="Tu dois catégoriser ce livre dans LA catégorie la plus appropriée.

LIVRE À CATÉGORISER:
Titre: $title
Auteurs: $authors
Description: $(echo "$description" | cut -c1-500)

CATÉGORIES DISPONIBLES (avec hiérarchie complète):
$categories_list

INSTRUCTIONS CRITIQUES:
1. Les catégories sont affichées avec leur hiérarchie complète (Parent > Enfant > Petite-enfant)
2. Tu dois choisir UNE SEULE catégorie FINALE (la plus spécifique)
3. L'ID est indiqué entre parenthèses à la fin : (ID:XXX)
4. Réponds UNIQUEMENT avec le numéro ID, rien d'autre
5. Par exemple, si tu choisis 'LITTÉRATURE > Romans > Romans français (ID:279)', réponds juste: 279"

    # Si Gemini (2e avis) a déjà répondu
    if [ -n "$previous_claude_response" ]; then
        prompt="$prompt

Note: Gemini (2e avis) a suggéré la catégorie ID:$previous_claude_response
Es-tu d'accord ? Si oui réponds le même ID, sinon donne ton choix."
    fi

    # Afficher le prompt si DEBUG
    if [ "$SHOW_PROMPTS" = "1" ] && [ "$VERBOSE" = "1" ]; then
        {
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "${GREEN}📤 PROMPT ENVOYÉ À GEMINI :${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$prompt" | head -50
            echo "... [tronqué pour l'affichage]"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
        } >&2
    fi

    # Échapper pour JSON
    debug_echo "[DEBUG] Échappement du prompt pour JSON..."
    local prompt_escaped=$(echo "$prompt" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    debug_echo "[DEBUG] Prompt échappé (50 car) : ${prompt_escaped:0:50}..."
    
    # Créer le JSON de la requête
    local json_request="{
        \"contents\": [{
            \"parts\": [{
                \"text\": \"$prompt_escaped\"
            }]
        }],
        \"generationConfig\": {
            \"temperature\": 0.3,
            \"maxOutputTokens\": 20
        }
    }"
    
    # Appel à Gemini
    debug_echo "[DEBUG] Appel curl vers Gemini API..."
    debug_echo "[DEBUG] URL : ${GEMINI_API_URL}?key=${GEMINI_API_KEY:0:10}..."
    
    local response=$(curl -s -X POST "${GEMINI_API_URL}?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$json_request" 2>&1)
    
    local curl_status=$?
    debug_echo "[DEBUG] Statut curl : $curl_status"
    debug_echo "[DEBUG] Taille réponse : $(echo "$response" | wc -c) caractères"
    
    # DEBUG : afficher la réponse brute
    if [ "$SHOW_PROMPTS" = "1" ] && [ "$VERBOSE" = "1" ]; then
        {
            echo -e "${GREEN}📥 RÉPONSE GEMINI (brute) :${NC}"
            echo "$response" | head -200
            echo ""
        } >&2
    fi
    
    # Analyser les erreurs AVANT d'extraire
    if ! analyze_api_error "$response" "Gemini"; then
        debug_echo "[DEBUG] === FIN ask_gemini avec ERREUR ==="
        return 1
    fi
    
    # Extraire la réponse avec la fonction
    debug_echo "[DEBUG] Appel extract_text_from_json..."
    local extracted_id=$(extract_text_from_json "$response" "gemini")
    debug_echo "[DEBUG] ID extrait par la fonction : '$extracted_id'"
    
    if [ "$SHOW_PROMPTS" = "1" ] && [ "$VERBOSE" = "1" ] && [ -n "$extracted_id" ]; then
        echo -e "${GREEN}🔢 ID final extrait de Gemini : ${BOLD}$extracted_id${NC}" >&2
        echo "" >&2
    fi
    
    debug_echo "[DEBUG] === FIN ask_gemini, retour : '$extracted_id' ==="
    # IMPORTANT : Retourner UNIQUEMENT l'ID extrait, pas les affichages
    echo "$extracted_id"
}

# Demander à Gemini (2e avis)
ask_gemini_twice() {
    debug_echo "[DEBUG] === DÉBUT ask_gemini_twice ==="
    local title="$1"
    local authors="$2"
    local description="$3"
    local categories_list="$4"
    local previous_gemini_response="${5:-}"
    
    debug_echo "[DEBUG] Paramètres reçus :"
    debug_echo "[DEBUG]   title='${title:0:50}...'"
    debug_echo "[DEBUG]   authors='$authors'"
    debug_echo "[DEBUG]   description length=$(echo "$description" | wc -c)"
    debug_echo "[DEBUG]   categories count=$(echo "$categories_list" | wc -l)"
    debug_echo "[DEBUG]   previous_gemini='$previous_gemini_response'"
    
    # Préparer le prompt
    local prompt="Tu dois catégoriser ce livre dans LA catégorie la plus appropriée.

LIVRE À CATÉGORISER:
Titre: $title
Auteurs: $authors
Description: $(echo "$description" | cut -c1-500)

CATÉGORIES DISPONIBLES (avec hiérarchie complète):
$categories_list

INSTRUCTIONS CRITIQUES:
1. Les catégories sont affichées avec leur hiérarchie complète (Parent > Enfant > Petite-enfant)
2. Tu dois choisir UNE SEULE catégorie FINALE (la plus spécifique)
3. L'ID est indiqué entre parenthèses à la fin : (ID:XXX)
4. Réponds UNIQUEMENT avec le numéro ID, rien d'autre
5. Par exemple, si tu choisis 'LITTÉRATURE > Romans > Romans français (ID:279)', réponds juste: 279"

    # Si Gemini a déjà répondu
    if [ -n "$previous_gemini_response" ]; then
        prompt="$prompt

Note: Gemini a suggéré la catégorie ID:$previous_gemini_response
Es-tu d'accord ? Si oui réponds le même ID, sinon donne ton choix."
    fi

    # Afficher le prompt si DEBUG
    if [ "$SHOW_PROMPTS" = "1" ] && [ "$VERBOSE" = "1" ]; then
        {
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo -e "${BLUE}📤 PROMPT ENVOYÉ À CLAUDE :${NC}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "$prompt" | head -50
            echo "... [tronqué pour l'affichage]"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo ""
        } >&2
    fi

    # Échapper pour JSON
    debug_echo "[DEBUG] Échappement du prompt pour JSON..."
    local prompt_escaped=$(echo "$prompt" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    debug_echo "[DEBUG] Prompt échappé (50 car) : ${prompt_escaped:0:50}..."
    
    # Créer le JSON de la requête
    local json_request="{
        \"model\": \"claude-3-haiku-20240307\",
        \"messages\": [{
            \"role\": \"user\",
            \"content\": \"$prompt_escaped\"
        }],
        \"max_tokens\": 50
    }"
    
    # Appel à Gemini (2e avis)
    debug_echo "[DEBUG] Appel curl vers Gemini (2e avis) API..."
    debug_echo "[DEBUG] URL : $CLAUDE_API_URL"
    
    local response=$(curl -s -X POST "$CLAUDE_API_URL" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$json_request" 2>&1)
    
    local curl_status=$?
    debug_echo "[DEBUG] Statut curl : $curl_status"
    debug_echo "[DEBUG] Taille réponse : $(echo "$response" | wc -c) caractères"
    
    # DEBUG : afficher la réponse brute
    if [ "$SHOW_PROMPTS" = "1" ] && [ "$VERBOSE" = "1" ]; then
        {
            echo -e "${BLUE}📥 RÉPONSE CLAUDE (brute) :${NC}"
            echo "$response" | head -200
            echo ""
        } >&2
    fi
    
    # Analyser les erreurs AVANT d'extraire
    if ! analyze_api_error "$response" "Gemini (2e avis)"; then
        debug_echo "[DEBUG] === FIN ask_gemini_twice avec ERREUR ==="
        return 1
    fi
    
    # Extraire la réponse avec la fonction
    debug_echo "[DEBUG] Appel extract_text_from_json..."
    local extracted_id=$(extract_text_from_json "$response" "claude")
    debug_echo "[DEBUG] ID extrait par la fonction : '$extracted_id'"
    
    # Si Gemini (2e avis) dit qu'il est d'accord, prendre la suggestion
    local claude_text=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['content'][0]['text'])
except:
    pass" 2>/dev/null)
    
    debug_echo "[DEBUG] Texte complet de Gemini (2e avis) : '$claude_text'"
    
    if echo "$claude_text" | grep -qi "d'accord\|agree\|oui\|yes"; then
        debug_echo "[DEBUG] Gemini (2e avis) semble d'accord avec Gemini"
        if [ -n "$previous_gemini_response" ]; then
            extracted_id="$previous_gemini_response"
            debug_echo "[DEBUG] Utilisation de la suggestion Gemini : '$extracted_id'"
        fi
    fi
    
    if [ "$SHOW_PROMPTS" = "1" ] && [ "$VERBOSE" = "1" ] && [ -n "$extracted_id" ]; then
        echo -e "${BLUE}🔢 ID final extrait de Gemini (2e avis) : ${BOLD}$extracted_id${NC}" >&2
        echo "" >&2
    fi
    
    debug_echo "[DEBUG] === FIN ask_gemini_twice, retour : '$extracted_id' ==="
    # IMPORTANT : Retourner UNIQUEMENT l'ID extrait
    echo "$extracted_id"
}

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
    
    echo -n "   Gemini (2e avis) analyse... "
    debug_echo "[DEBUG] Appel ask_gemini_twice Round 1..."
    local claude_choice_1=$(ask_gemini_twice "$title" "$authors" "$description" "$categories_list")
    local claude_status=$?
    debug_echo "[DEBUG] Retour ask_gemini_twice Round 1 : '$claude_choice_1' (status=$claude_status)"
    
    if [ $claude_status -eq 0 ] && [ -n "$claude_choice_1" ] && [[ "$claude_choice_1" =~ ^[0-9]+$ ]]; then
        local claude_cat_1=$(get_category_with_parent "$claude_choice_1")
        echo -e "${BLUE}Gemini (2e avis) choisit : ${BOLD}$claude_cat_1${NC}"
        claude_success=1
    else
        debug_echo "[DEBUG] ERREUR : claude_choice_1 invalide : '$claude_choice_1'"
        echo -e "${RED}Gemini (2e avis) ne répond pas correctement !${NC}"
    fi
    
    # VÉRIFIER SI LES IA ONT RÉPONDU - NOUVELLE RÈGLE
    if [ $claude_success -eq 0 ]; then
        # Gemini (2e avis) n'a pas répondu = toujours échec
        echo ""
        echo -e "${RED}${BOLD}❌ ÉCHEC : Gemini (2e avis) n'a pas répondu${NC}"
        echo -e "${YELLOW}La catégorisation nécessite au minimum Gemini (2e avis)${NC}"
        return 1
    elif [ $gemini_success -eq 0 ] && [ $claude_success -eq 1 ]; then
        # Seulement Gemini (2e avis) a répondu = on prend Gemini (2e avis)
        echo ""
        echo -e "${YELLOW}${BOLD}⚠️  Seul Gemini (2e avis) a répondu - on prend son choix${NC}"
        local final_choice=$claude_choice_1
        local final_cat_name=$(get_category_with_parent "$final_choice")
        echo -e "${BLUE}Catégorie Gemini (2e avis) : ${BOLD}$final_cat_name${NC}"
        
        # Passer directement à l'application
        echo ""
        echo -e "\n${RED}${BOLD}📌 CATÉGORIE FINALE : $final_cat_name${NC}\n"
        
        # Appliquer la catégorie (copier le code d'application ici)
        echo -n "💾 Application... "
        
        # Obtenir le term_taxonomy_id
        debug_echo "[DEBUG] Recherche term_taxonomy_id pour term_id=$final_choice..."
        local term_taxonomy_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
        WHERE term_id = $final_choice AND taxonomy = 'product_cat'
        " 2>/dev/null)
        
        debug_echo "[DEBUG] term_taxonomy_id trouvé : '$term_taxonomy_id'"
        
        if [ -z "$term_taxonomy_id" ]; then
            debug_echo "[DEBUG] ERREUR : term_taxonomy_id non trouvé pour term_id=$final_choice"
            echo -e "${RED}❌ Catégorie introuvable !${NC}"
            return 1
        fi
        
        # Supprimer anciennes catégories
        debug_echo "[DEBUG] Suppression des anciennes catégories..."
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        DELETE FROM wp_${SITE_ID}_term_relationships 
        WHERE object_id = $post_id 
        AND term_taxonomy_id IN (
            SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
            WHERE taxonomy = 'product_cat'
        )
        " 2>/dev/null
        
        # Ajouter nouvelle catégorie
        debug_echo "[DEBUG] Ajout de la nouvelle catégorie term_taxonomy_id=$term_taxonomy_id..."
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        INSERT IGNORE INTO wp_${SITE_ID}_term_relationships (object_id, term_taxonomy_id)
        VALUES ($post_id, $term_taxonomy_id)
        " 2>/dev/null
        
        echo -e "${GREEN}✅ Fait!${NC}"
        
        # Stocker la catégorie de référence Google Books
        local g_category=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $post_id AND meta_key = '_g_categories' LIMIT 1" 2>/dev/null)
        
        if [ -n "$g_category" ] && [ "$g_category" != "NULL" ]; then
            safe_store_meta "$post_id" "_g_categorie_reference" "$g_category"
            debug_echo "[DEBUG] Catégorie Google Books stockée pour référence : $g_category"
        fi
        
        # Log
        mkdir -p "$LOG_DIR"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ID:$post_id - $title → $final_cat_name (Gemini (2e avis) seul)" >> "$LOG_DIR/dual_ai_categorize.log"
        
        return 0
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
        debug_echo "[DEBUG] Appel ask_gemini Round 2 avec suggestion Gemini (2e avis)=$claude_choice_1..."
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
        
        echo -n "   Gemini (2e avis) reconsidère... "
        debug_echo "[DEBUG] Appel ask_gemini_twice Round 2 avec suggestion Gemini=$gemini_choice_1..."
        local claude_choice_2=$(ask_gemini_twice "$title" "$authors" "$description" "$categories_list" "$gemini_choice_1")
        local claude_status_2=$?
        debug_echo "[DEBUG] Retour ask_gemini_twice Round 2 : '$claude_choice_2' (status=$claude_status_2)"
        
        if [ $claude_status_2 -eq 0 ] && [ -n "$claude_choice_2" ] && [[ "$claude_choice_2" =~ ^[0-9]+$ ]]; then
            local claude_cat_2=$(get_category_with_parent "$claude_choice_2")
            echo -e "${BLUE}Gemini (2e avis) change pour : ${BOLD}$claude_cat_2${NC}"
            claude_success=1
        else
            echo -e "${RED}Gemini (2e avis) échoue au round 2${NC}"
            claude_choice_2=$claude_choice_1
            claude_cat_2=$claude_cat_1
            if [ -n "$claude_choice_1" ]; then
                claude_success=1  # On garde son premier choix
            fi
        fi
        
        # Vérifier à nouveau avec la nouvelle règle
        if [ $claude_success -eq 0 ]; then
            # Gemini (2e avis) doit toujours répondre
            echo ""
            echo -e "${RED}${BOLD}❌ ÉCHEC AU ROUND 2 : Gemini (2e avis) n'a pas répondu${NC}"
            return 1
        elif [ $gemini_success -eq 0 ] && [ $claude_success -eq 1 ]; then
            # Si seulement Gemini (2e avis) répond au round 2, on prend son choix
            echo ""
            echo -e "${YELLOW}${BOLD}⚠️  Seul Gemini (2e avis) répond au round 2 - on prend son choix${NC}"
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
                echo -e "   Choix final de Gemini (2e avis) : ${BLUE}$claude_cat_2${NC}"
                # En cas de désaccord persistant, prendre Gemini (2e avis)
                local final_choice=$claude_choice_2
                echo -e "   → Choix retenu : ${BOLD}$claude_cat_2 (Gemini (2e avis))${NC}"
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
    echo -n "💾 Application... "
    
    # Obtenir le term_taxonomy_id
    debug_echo "[DEBUG] Recherche term_taxonomy_id pour term_id=$final_choice..."
    local term_taxonomy_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
    WHERE term_id = $final_choice AND taxonomy = 'product_cat'
    " 2>/dev/null)
    
    debug_echo "[DEBUG] term_taxonomy_id trouvé : '$term_taxonomy_id'"
    
    if [ -z "$term_taxonomy_id" ]; then
        debug_echo "[DEBUG] ERREUR : term_taxonomy_id non trouvé pour term_id=$final_choice"
        echo -e "${RED}❌ Catégorie introuvable !${NC}"
        return 1
    fi
    
    # Supprimer anciennes catégories
    debug_echo "[DEBUG] Suppression des anciennes catégories..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    DELETE FROM wp_${SITE_ID}_term_relationships 
    WHERE object_id = $post_id 
    AND term_taxonomy_id IN (
        SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
        WHERE taxonomy = 'product_cat'
    )
    " 2>/dev/null
    
    # Ajouter nouvelle catégorie
    debug_echo "[DEBUG] Ajout de la nouvelle catégorie term_taxonomy_id=$term_taxonomy_id..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    INSERT IGNORE INTO wp_${SITE_ID}_term_relationships (object_id, term_taxonomy_id)
    VALUES ($post_id, $term_taxonomy_id)
    " 2>/dev/null
    
    echo -e "${GREEN}✅ Fait!${NC}"
    
    # Stocker la catégorie de référence Google Books (si elle existe)
    local g_category=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT meta_value FROM wp_${SITE_ID}_postmeta 
    WHERE post_id = $post_id AND meta_key = '_g_categories' LIMIT 1" 2>/dev/null)
    
    if [ -n "$g_category" ] && [ "$g_category" != "NULL" ]; then
        safe_store_meta "$post_id" "_g_categorie_reference" "$g_category"
        debug_echo "[DEBUG] Catégorie Google Books stockée pour référence : $g_category"
    fi
    
    # Log
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ID:$post_id - $title → $final_cat_name" >> "$LOG_DIR/dual_ai_categorize.log"
    
    debug_echo "[DEBUG] === FIN categorize_with_dual_ai ==="
}

# Programme principal
clear
echo -e "${BOLD}=== SMART CATEGORIZE - DUAL AI MODE ===${NC}"
echo "Gemini + Gemini (2e avis) débattent pour trouver la meilleure catégorie"
echo "════════════════════════════════════════════════════════════════════════════"

# Vérifier les clés
debug_echo "[DEBUG] Vérification des clés API..."
debug_echo "[DEBUG] GEMINI_API_KEY : ${GEMINI_API_KEY:0:10}..."

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
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"
# Fonction pour demander 2 fois à Gemini avec prompt différent
ask_gemini_twice() {
    local title="$1"
    local authors="$2"
    local description="$3"
    local categories_list="$4"
    local previous_response="${5:-}"
    
    # Modifier légèrement le prompt pour avoir un 2e avis
    local extra="Sois très précis et choisis la catégorie la plus spécifique possible."
    
    # Appeler ask_gemini avec le prompt modifié
    ask_gemini "$title" "$authors" "$description" "$categories_list" "$previous_response"
}
