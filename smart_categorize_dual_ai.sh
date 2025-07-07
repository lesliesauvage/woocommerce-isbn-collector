| cut -c1-150)...${NC}"#!/bin/bash
| cut -c1-150)...${NC}"# ⚠️  FICHIER CRITIQUE - NE JAMAIS SUPPRIMER ⚠️
| cut -c1-150)...${NC}"# smart_categorize_dual_ai.sh - Double IA qui débattent pour catégoriser
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
| cut -c1-150)...${NC}"source "$SCRIPT_DIR/config/settings.sh"
| cut -c1-150)...${NC}"source "$SCRIPT_DIR/lib/safe_functions.sh"
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Couleurs pour affichage
| cut -c1-150)...${NC}"RED="\033[0;31m"
| cut -c1-150)...${NC}"GREEN="\033[0;32m"
| cut -c1-150)...${NC}"YELLOW="\033[0;33m"
| cut -c1-150)...${NC}"BLUE="\033[0;34m"
| cut -c1-150)...${NC}"PURPLE="\033[0;35m"
| cut -c1-150)...${NC}"CYAN="\033[0;36m"
| cut -c1-150)...${NC}"BOLD="\033[1m"
| cut -c1-150)...${NC}"NC="\033[0m" # No Color
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Mode debug
# Si pas de paramètre SHOW_PROMPTS, le mettre à 0 par défaut
SHOW_PROMPTS="${SHOW_PROMPTS:-0}"
| cut -c1-150)...${NC}"SHOW_PROMPTS="1"  # FORCÉ EN DEBUG
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Fonction pour extraire le texte des réponses JSON des IA
| cut -c1-150)...${NC}"extract_text_from_json() {
| cut -c1-150)...${NC}"    local json="$1"
| cut -c1-150)...${NC}"    local api_type="$2"  # "gemini" ou "claude"
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] Extraction pour $api_type..." >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] JSON length: ${#json}" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Essayer Python en premier
| cut -c1-150)...${NC}"    local result
| cut -c1-150)...${NC}"    if [ "$api_type" = "gemini" ]; then
| cut -c1-150)...${NC}"        result=$(echo "$json" | python3 -c "
| cut -c1-150)...${NC}"import json, sys
| cut -c1-150)...${NC}"try:
| cut -c1-150)...${NC}"    data = json.load(sys.stdin)
| cut -c1-150)...${NC}"    text = data['candidates'][0]['content']['parts'][0]['text']
| cut -c1-150)...${NC}"    print(text.strip())
| cut -c1-150)...${NC}"except Exception as e:
| cut -c1-150)...${NC}"    print(f'ERREUR: {e}', file=sys.stderr)
| cut -c1-150)...${NC}"" 2>/dev/null)
| cut -c1-150)...${NC}"    else  # claude
| cut -c1-150)...${NC}"        result=$(echo "$json" | python3 -c "
| cut -c1-150)...${NC}"import json, sys
| cut -c1-150)...${NC}"try:
| cut -c1-150)...${NC}"    data = json.load(sys.stdin)
| cut -c1-150)...${NC}"    text = data['content'][0]['text']
| cut -c1-150)...${NC}"    print(text.strip())
| cut -c1-150)...${NC}"except Exception as e:
| cut -c1-150)...${NC}"    print(f'ERREUR: {e}', file=sys.stderr)
| cut -c1-150)...${NC}"" 2>/dev/null)
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] Result before cleaning: '$result'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] Result length: ${#result}" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Nettoyer le résultat - garder uniquement les chiffres
| cut -c1-150)...${NC}"    result=$(echo "$result" | tr -d '\n\r' | grep -o '[0-9]\+' | head -1)
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] Résultat extrait et nettoyé : '$result'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] Final length: ${#result}" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "$result"
| cut -c1-150)...${NC}"}
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Obtenir toutes les catégories avec leur hiérarchie
| cut -c1-150)...${NC}"get_all_categories_with_hierarchy() {
| cut -c1-150)...${NC}"    echo "[DEBUG] Récupération des catégories AVEC hiérarchie..." >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Récupérer TOUTES les catégories (pas seulement les finales)
| cut -c1-150)...${NC}"    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
| cut -c1-150)...${NC}"    WITH RECURSIVE category_path AS (
| cut -c1-150)...${NC}"        -- Cas de base : catégories sans parent
| cut -c1-150)...${NC}"        SELECT 
| cut -c1-150)...${NC}"            t.term_id,
| cut -c1-150)...${NC}"            t.name,
| cut -c1-150)...${NC}"            tt.parent,
| cut -c1-150)...${NC}"            CAST(t.name AS CHAR(1000)) AS path,
| cut -c1-150)...${NC}"            t.term_id AS final_id,
| cut -c1-150)...${NC}"            t.name AS final_name
| cut -c1-150)...${NC}"        FROM wp_${SITE_ID}_terms t
| cut -c1-150)...${NC}"        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
| cut -c1-150)...${NC}"        WHERE tt.taxonomy = 'product_cat' 
| cut -c1-150)...${NC}"        AND tt.parent = 0
| cut -c1-150)...${NC}"        AND t.term_id NOT IN (15, 16)
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        UNION ALL
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        -- Cas récursif : ajouter les enfants
| cut -c1-150)...${NC}"        SELECT 
| cut -c1-150)...${NC}"            t.term_id,
| cut -c1-150)...${NC}"            t.name,
| cut -c1-150)...${NC}"            tt.parent,
| cut -c1-150)...${NC}"            CONCAT(cp.path, ' > ', t.name) AS path,
| cut -c1-150)...${NC}"            t.term_id AS final_id,
| cut -c1-150)...${NC}"            t.name AS final_name
| cut -c1-150)...${NC}"        FROM wp_${SITE_ID}_terms t
| cut -c1-150)...${NC}"        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
| cut -c1-150)...${NC}"        JOIN category_path cp ON tt.parent = cp.term_id
| cut -c1-150)...${NC}"        WHERE tt.taxonomy = 'product_cat'
| cut -c1-150)...${NC}"    )
| cut -c1-150)...${NC}"    SELECT CONCAT(path, ' (ID:', final_id, ')') AS category_line
| cut -c1-150)...${NC}"    FROM category_path
| cut -c1-150)...${NC}"    WHERE final_id NOT IN (
| cut -c1-150)...${NC}"        SELECT DISTINCT parent 
| cut -c1-150)...${NC}"        FROM wp_${SITE_ID}_term_taxonomy 
| cut -c1-150)...${NC}"        WHERE taxonomy = 'product_cat' AND parent != 0
| cut -c1-150)...${NC}"    )
| cut -c1-150)...${NC}"    ORDER BY path
| cut -c1-150)...${NC}"    " 2>/dev/null
| cut -c1-150)...${NC}"}
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Obtenir la hiérarchie complète d'une catégorie
| cut -c1-150)...${NC}"get_category_with_parent() {
| cut -c1-150)...${NC}"    local cat_id=$1
| cut -c1-150)...${NC}"    echo "[DEBUG] Recherche hiérarchie pour cat_id='$cat_id'" >&2
| cut -c1-150)...${NC}"    [ -z "$cat_id" ] && { echo "[DEBUG] ERREUR : cat_id vide !" >&2; return; }
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Fonction récursive pour remonter toute la hiérarchie
| cut -c1-150)...${NC}"    get_full_path() {
| cut -c1-150)...${NC}"        local id=$1
| cut -c1-150)...${NC}"        local result=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
| cut -c1-150)...${NC}"        SELECT t.name, tt.parent
| cut -c1-150)...${NC}"        FROM wp_${SITE_ID}_terms t
| cut -c1-150)...${NC}"        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
| cut -c1-150)...${NC}"        WHERE t.term_id = $id" 2>/dev/null)
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        if [ -n "$result" ]; then
| cut -c1-150)...${NC}"            local name=$(echo "$result" | cut -f1)
| cut -c1-150)...${NC}"            local parent=$(echo "$result" | cut -f2)
| cut -c1-150)...${NC}"            
| cut -c1-150)...${NC}"            if [ "$parent" != "0" ] && [ -n "$parent" ]; then
| cut -c1-150)...${NC}"                local parent_path=$(get_full_path $parent)
| cut -c1-150)...${NC}"                echo "$parent_path > $name"
| cut -c1-150)...${NC}"            else
| cut -c1-150)...${NC}"                echo "$name"
| cut -c1-150)...${NC}"            fi
| cut -c1-150)...${NC}"        fi
| cut -c1-150)...${NC}"    }
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    local full_path=$(get_full_path $cat_id)
| cut -c1-150)...${NC}"    echo "[DEBUG] Hiérarchie trouvée : '$full_path'" >&2
| cut -c1-150)...${NC}"    echo "$full_path"
| cut -c1-150)...${NC}"}
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Demander à Gemini
| cut -c1-150)...${NC}"ask_gemini() {
| cut -c1-150)...${NC}"    echo "[DEBUG] === DÉBUT ask_gemini ===" >&2
| cut -c1-150)...${NC}"    local title="$1"
| cut -c1-150)...${NC}"    local authors="$2"
| cut -c1-150)...${NC}"    local description="$3"
| cut -c1-150)...${NC}"    local categories_list="$4"
| cut -c1-150)...${NC}"    local previous_claude_response="${5:-}"
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] Paramètres reçus :" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   title='${title:0:50}...'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   authors='$authors'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   description length=$(echo "$description" | wc -c)" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   categories count=$(echo "$categories_list" | wc -l)" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   previous_claude='$previous_claude_response'" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Préparer le prompt
| cut -c1-150)...${NC}"    local prompt="Tu dois catégoriser ce livre dans LA catégorie la plus appropriée.
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"LIVRE À CATÉGORISER:
| cut -c1-150)...${NC}"Titre: $title
| cut -c1-150)...${NC}"Auteurs: $authors
| cut -c1-150)...${NC}"Description: $(echo "$description" | cut -c1-500)
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"CATÉGORIES DISPONIBLES (avec hiérarchie complète):
| cut -c1-150)...${NC}"$categories_list
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"INSTRUCTIONS CRITIQUES:
| cut -c1-150)...${NC}"1. Les catégories sont affichées avec leur hiérarchie complète (Parent > Enfant > Petite-enfant)
| cut -c1-150)...${NC}"2. Tu dois choisir UNE SEULE catégorie FINALE (la plus spécifique)
| cut -c1-150)...${NC}"3. L'ID est indiqué entre parenthèses à la fin : (ID:XXX)
| cut -c1-150)...${NC}"4. Réponds UNIQUEMENT avec le numéro ID, rien d'autre
| cut -c1-150)...${NC}"5. Par exemple, si tu choisis 'LITTÉRATURE > Romans > Romans français (ID:279)', réponds juste: 279"
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"    # Si Claude a déjà répondu
| cut -c1-150)...${NC}"    if [ -n "$previous_claude_response" ]; then
| cut -c1-150)...${NC}"        prompt="$prompt
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"Note: Claude a suggéré la catégorie ID:$previous_claude_response
| cut -c1-150)...${NC}"Es-tu d'accord ? Si oui réponds le même ID, sinon donne ton choix."
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"    # Afficher le prompt si DEBUG
| cut -c1-150)...${NC}"    if [ "$SHOW_PROMPTS" = "1" ]; then
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
| cut -c1-150)...${NC}"        echo "📤 PROMPT ENVOYÉ À GEMINI :"
| cut -c1-150)...${NC}"        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
| cut -c1-150)...${NC}"        echo "$prompt" | head -50
| cut -c1-150)...${NC}"        echo "... [tronqué pour l'affichage]"
| cut -c1-150)...${NC}"        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"    # Échapper pour JSON
| cut -c1-150)...${NC}"    echo "[DEBUG] Échappement du prompt pour JSON..." >&2
| cut -c1-150)...${NC}"    local prompt_escaped=$(echo "$prompt" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
| cut -c1-150)...${NC}"    echo "[DEBUG] Prompt échappé (50 car) : ${prompt_escaped:0:50}..." >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Créer le JSON de la requête
| cut -c1-150)...${NC}"    local json_request="{
| cut -c1-150)...${NC}"        \"contents\": [{
| cut -c1-150)...${NC}"            \"parts\": [{
| cut -c1-150)...${NC}"                \"text\": \"$prompt_escaped\"
| cut -c1-150)...${NC}"            }]
| cut -c1-150)...${NC}"        }],
| cut -c1-150)...${NC}"        \"generationConfig\": {
| cut -c1-150)...${NC}"            \"temperature\": 0.3,
| cut -c1-150)...${NC}"            \"maxOutputTokens\": 20
| cut -c1-150)...${NC}"        }
| cut -c1-150)...${NC}"    }"
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Appel à Gemini
| cut -c1-150)...${NC}"    echo "[DEBUG] Appel curl vers Gemini API..." >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] URL : ${GEMINI_API_URL}?key=${GEMINI_API_KEY:0:10}..." >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    local response=$(curl -s -X POST "${GEMINI_API_URL}?key=${GEMINI_API_KEY}" \
| cut -c1-150)...${NC}"        -H "Content-Type: application/json" \
| cut -c1-150)...${NC}"        -d "$json_request" 2>&1)
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    local curl_status=$?
| cut -c1-150)...${NC}"    echo "[DEBUG] Statut curl : $curl_status" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] Taille réponse : $(echo "$response" | wc -c) caractères" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # DEBUG : afficher la réponse brute
| cut -c1-150)...${NC}"    if [ "$SHOW_PROMPTS" = "1" ]; then
| cut -c1-150)...${NC}"        echo "📥 RÉPONSE GEMINI (brute) :"
| cut -c1-150)...${NC}"        echo "$response" | head -200
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Vérifier si c'est une erreur
| cut -c1-150)...${NC}"    if echo "$response" | grep -q '"error"'; then
| cut -c1-150)...${NC}"        echo "[DEBUG] ERREUR détectée dans la réponse Gemini !" >&2
| cut -c1-150)...${NC}"        echo "[DEBUG] Erreur : $(echo "$response" | grep -o '"message":"[^"]*"')" >&2
| cut -c1-150)...${NC}"        return 1
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Extraire la réponse avec la fonction
| cut -c1-150)...${NC}"    echo "[DEBUG] Appel extract_text_from_json..." >&2
| cut -c1-150)...${NC}"    local extracted_id=$(extract_text_from_json "$response" "gemini")
| cut -c1-150)...${NC}"    echo "[DEBUG] ID extrait par la fonction : '$extracted_id'" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    if [ "$SHOW_PROMPTS" = "1" ] && [ -n "$extracted_id" ]; then
| cut -c1-150)...${NC}"        echo -e "${GREEN}🔢 ID final extrait de Gemini : ${BOLD}$extracted_id${NC}"
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] === FIN ask_gemini, retour : '$extracted_id' ===" >&2
| cut -c1-150)...${NC}"    echo "$extracted_id"
| cut -c1-150)...${NC}"}
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Demander à Claude
| cut -c1-150)...${NC}"ask_claude() {
| cut -c1-150)...${NC}"    echo "[DEBUG] === DÉBUT ask_claude ===" >&2
| cut -c1-150)...${NC}"    local title="$1"
| cut -c1-150)...${NC}"    local authors="$2"
| cut -c1-150)...${NC}"    local description="$3"
| cut -c1-150)...${NC}"    local categories_list="$4"
| cut -c1-150)...${NC}"    local previous_gemini_response="${5:-}"
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] Paramètres reçus :" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   title='${title:0:50}...'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   authors='$authors'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   description length=$(echo "$description" | wc -c)" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   categories count=$(echo "$categories_list" | wc -l)" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   previous_gemini='$previous_gemini_response'" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Préparer le prompt
| cut -c1-150)...${NC}"    local prompt="Tu dois catégoriser ce livre dans LA catégorie la plus appropriée.
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"LIVRE À CATÉGORISER:
| cut -c1-150)...${NC}"Titre: $title
| cut -c1-150)...${NC}"Auteurs: $authors
| cut -c1-150)...${NC}"Description: $(echo "$description" | cut -c1-500)
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"CATÉGORIES DISPONIBLES (avec hiérarchie complète):
| cut -c1-150)...${NC}"$categories_list
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"INSTRUCTIONS CRITIQUES:
| cut -c1-150)...${NC}"1. Les catégories sont affichées avec leur hiérarchie complète (Parent > Enfant > Petite-enfant)
| cut -c1-150)...${NC}"2. Tu dois choisir UNE SEULE catégorie FINALE (la plus spécifique)
| cut -c1-150)...${NC}"3. L'ID est indiqué entre parenthèses à la fin : (ID:XXX)
| cut -c1-150)...${NC}"4. Réponds UNIQUEMENT avec le numéro ID, rien d'autre
| cut -c1-150)...${NC}"5. Par exemple, si tu choisis 'LITTÉRATURE > Romans > Romans français (ID:279)', réponds juste: 279"
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"    # Si Gemini a déjà répondu
| cut -c1-150)...${NC}"    if [ -n "$previous_gemini_response" ]; then
| cut -c1-150)...${NC}"        prompt="$prompt
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"Note: Gemini a suggéré la catégorie ID:$previous_gemini_response
| cut -c1-150)...${NC}"Es-tu d'accord ? Si oui réponds le même ID, sinon donne ton choix."
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"    # Afficher le prompt si DEBUG
| cut -c1-150)...${NC}"    if [ "$SHOW_PROMPTS" = "1" ]; then
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
| cut -c1-150)...${NC}"        echo "📤 PROMPT ENVOYÉ À CLAUDE :"
| cut -c1-150)...${NC}"        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
| cut -c1-150)...${NC}"        echo "$prompt" | head -50
| cut -c1-150)...${NC}"        echo "... [tronqué pour l'affichage]"
| cut -c1-150)...${NC}"        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"    # Échapper pour JSON
| cut -c1-150)...${NC}"    echo "[DEBUG] Échappement du prompt pour JSON..." >&2
| cut -c1-150)...${NC}"    local prompt_escaped=$(echo "$prompt" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
| cut -c1-150)...${NC}"    echo "[DEBUG] Prompt échappé (50 car) : ${prompt_escaped:0:50}..." >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Créer le JSON de la requête
| cut -c1-150)...${NC}"    local json_request="{
| cut -c1-150)...${NC}"        \"model\": \"claude-3-haiku-20240307\",
| cut -c1-150)...${NC}"        \"messages\": [{
| cut -c1-150)...${NC}"            \"role\": \"user\",
| cut -c1-150)...${NC}"            \"content\": \"$prompt_escaped\"
| cut -c1-150)...${NC}"        }],
| cut -c1-150)...${NC}"        \"max_tokens\": 50
| cut -c1-150)...${NC}"    }"
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Appel à Claude
| cut -c1-150)...${NC}"    echo "[DEBUG] Appel curl vers Claude API..." >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] URL : $CLAUDE_API_URL" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] API Key : ${CLAUDE_API_KEY:0:10}..." >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    local response=$(curl -s -X POST "$CLAUDE_API_URL" \
| cut -c1-150)...${NC}"        -H "x-api-key: $CLAUDE_API_KEY" \
| cut -c1-150)...${NC}"        -H "anthropic-version: 2023-06-01" \
| cut -c1-150)...${NC}"        -H "content-type: application/json" \
| cut -c1-150)...${NC}"        -d "$json_request" 2>&1)
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    local curl_status=$?
| cut -c1-150)...${NC}"    echo "[DEBUG] Statut curl : $curl_status" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] Taille réponse : $(echo "$response" | wc -c) caractères" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # DEBUG : afficher la réponse brute
| cut -c1-150)...${NC}"    if [ "$SHOW_PROMPTS" = "1" ]; then
| cut -c1-150)...${NC}"        echo "📥 RÉPONSE CLAUDE (brute) :"
| cut -c1-150)...${NC}"        echo "$response" | head -200
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Vérifier si c'est une erreur
| cut -c1-150)...${NC}"    if echo "$response" | grep -q '"error"'; then
| cut -c1-150)...${NC}"        echo "[DEBUG] ERREUR détectée dans la réponse Claude !" >&2
| cut -c1-150)...${NC}"        echo "[DEBUG] Erreur : $(echo "$response" | grep -o '"message":"[^"]*"')" >&2
| cut -c1-150)...${NC}"        return 1
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Extraire la réponse avec la fonction
| cut -c1-150)...${NC}"    echo "[DEBUG] Appel extract_text_from_json..." >&2
| cut -c1-150)...${NC}"    local extracted_id=$(extract_text_from_json "$response" "claude")
| cut -c1-150)...${NC}"    echo "[DEBUG] ID extrait par la fonction : '$extracted_id'" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Si Claude dit qu'il est d'accord, prendre la suggestion
| cut -c1-150)...${NC}"    local claude_text=$(echo "$response" | python3 -c "
| cut -c1-150)...${NC}"import json, sys
| cut -c1-150)...${NC}"try:
| cut -c1-150)...${NC}"    data = json.load(sys.stdin)
| cut -c1-150)...${NC}"    print(data['content'][0]['text'])
| cut -c1-150)...${NC}"except:
| cut -c1-150)...${NC}"    pass" 2>/dev/null)
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] Texte complet de Claude : '$claude_text'" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    if echo "$claude_text" | grep -qi "d'accord\|agree\|oui\|yes"; then
| cut -c1-150)...${NC}"        echo "[DEBUG] Claude semble d'accord avec Gemini" >&2
| cut -c1-150)...${NC}"        if [ -n "$previous_gemini_response" ]; then
| cut -c1-150)...${NC}"            extracted_id="$previous_gemini_response"
| cut -c1-150)...${NC}"            echo "[DEBUG] Utilisation de la suggestion Gemini : '$extracted_id'" >&2
| cut -c1-150)...${NC}"        fi
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    if [ "$SHOW_PROMPTS" = "1" ] && [ -n "$extracted_id" ]; then
| cut -c1-150)...${NC}"        echo -e "${BLUE}🔢 ID final extrait de Claude : ${BOLD}$extracted_id${NC}"
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] === FIN ask_claude, retour : '$extracted_id' ===" >&2
| cut -c1-150)...${NC}"    echo "$extracted_id"
| cut -c1-150)...${NC}"}
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Fonction principale de catégorisation
| cut -c1-150)...${NC}"categorize_with_dual_ai() {
| cut -c1-150)...${NC}"    local post_id="$1"
| cut -c1-150)...${NC}"    echo "[DEBUG] === DÉBUT categorize_with_dual_ai pour post_id=$post_id ===" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Récupérer les infos du livre
| cut -c1-150)...${NC}"    echo "[DEBUG] Récupération des infos du livre ID $post_id..." >&2
| cut -c1-150)...${NC}"    local book_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
| cut -c1-150)...${NC}"    SELECT 
| cut -c1-150)...${NC}"        p.post_title,
| cut -c1-150)...${NC}"        IFNULL(pm_isbn.meta_value, '') as isbn,
| cut -c1-150)...${NC}"        IFNULL(pm_authors.meta_value, IFNULL(pm_authors2.meta_value, '')) as authors,
| cut -c1-150)...${NC}"        IFNULL(pm_desc.meta_value, IFNULL(pm_desc2.meta_value, '')) as description
| cut -c1-150)...${NC}"    FROM wp_${SITE_ID}_posts p
| cut -c1-150)...${NC}"    LEFT JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
| cut -c1-150)...${NC}"    LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
| cut -c1-150)...${NC}"    LEFT JOIN wp_${SITE_ID}_postmeta pm_authors2 ON p.ID = pm_authors2.post_id AND pm_authors2.meta_key = '_g_authors'
| cut -c1-150)...${NC}"    LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
| cut -c1-150)...${NC}"    LEFT JOIN wp_${SITE_ID}_postmeta pm_desc2 ON p.ID = pm_desc2.post_id AND pm_desc2.meta_key = '_g_description'
| cut -c1-150)...${NC}"    WHERE p.ID = $post_id
| cut -c1-150)...${NC}"    " 2>/dev/null)
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] book_info trouvé : $(echo "$book_info" | wc -c) caractères" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    if [ -z "$book_info" ]; then
| cut -c1-150)...${NC}"        echo "[DEBUG] ERREUR : Aucune info trouvée pour ID $post_id" >&2
| cut -c1-150)...${NC}"        echo "❌ Livre ID $post_id non trouvé"
| cut -c1-150)...${NC}"        return 1
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Parser les infos
| cut -c1-150)...${NC}"    IFS=$'\t' read -r title isbn authors description <<< "$book_info"
| cut -c1-150)...${NC}"    echo "[DEBUG] Infos parsées :" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   title='$title'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   isbn='$isbn'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   authors='$authors'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG]   description length=$(echo "$description" | wc -c)" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Nettoyer le titre s'il commence par "Livre ISBN"
| cut -c1-150)...${NC}"    if [[ "$title" =~ ^Livre[[:space:]]+[0-9]+ ]]; then
| cut -c1-150)...${NC}"        echo "[DEBUG] Titre générique détecté, recherche du vrai titre..." >&2
| cut -c1-150)...${NC}"        # Chercher _best_title ou _g_title
| cut -c1-150)...${NC}"        local real_title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
| cut -c1-150)...${NC}"        SELECT IFNULL(
| cut -c1-150)...${NC}"            (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = $post_id AND meta_key = '_best_title' LIMIT 1),
| cut -c1-150)...${NC}"            (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = $post_id AND meta_key = '_g_title' LIMIT 1)
| cut -c1-150)...${NC}"        )" 2>/dev/null)
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        if [ -n "$real_title" ] && [ "$real_title" != "NULL" ]; then
| cut -c1-150)...${NC}"            title="$real_title"
| cut -c1-150)...${NC}"            echo "[DEBUG] Vrai titre trouvé : '$title'" >&2
| cut -c1-150)...${NC}"        fi
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo ""
| cut -c1-150)...${NC}"    echo -e "📚 LIVRE : ${RED}${BOLD}$title${NC}"
| cut -c1-150)...${NC}"    echo -e "   ISBN : ${CYAN}${isbn:-N/A}${NC}"
| cut -c1-150)...${NC}"    echo -e "   Auteurs : ${BLUE}${authors:-N/A}${NC}"
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Afficher la description
| cut -c1-150)...${NC}"    if [ -n "$description" ] && [ "$description" != "NULL" ]; then
| cut -c1-150)...${NC}"        echo -e "   Description : ${YELLOW}$(echo "$description" | sed 's/<[^>]*>//g' | cut -c1-150)..."
| cut -c1-150)...${NC}"    else
| cut -c1-150)...${NC}"        echo "   Description : Non disponible"
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    echo ""
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Obtenir la liste des catégories AVEC HIÉRARCHIE
| cut -c1-150)...${NC}"    echo "📋 Récupération des catégories avec hiérarchie..."
| cut -c1-150)...${NC}"    local categories_list=$(get_all_categories_with_hierarchy)
| cut -c1-150)...${NC}"    local cat_count=$(echo "$categories_list" | wc -l)
| cut -c1-150)...${NC}"    echo "   $cat_count catégories disponibles"
| cut -c1-150)...${NC}"    echo "[DEBUG] Exemples de catégories avec hiérarchie :" >&2
| cut -c1-150)...${NC}"    echo "$categories_list" | head -5 | while read line; do
| cut -c1-150)...${NC}"        echo "[DEBUG]   $line" >&2
| cut -c1-150)...${NC}"    done
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Premier round : demander aux deux IA
| cut -c1-150)...${NC}"    echo ""
| cut -c1-150)...${NC}"    echo "🤖 ROUND 1 - Première analyse..."
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo -n "   Gemini analyse... "
| cut -c1-150)...${NC}"    echo "[DEBUG] Appel ask_gemini Round 1..." >&2
| cut -c1-150)...${NC}"    local gemini_choice_1=$(ask_gemini "$title" "$authors" "$description" "$categories_list")
| cut -c1-150)...${NC}"    echo "[DEBUG] *** RETOUR ask_gemini Round 1 ***" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] *** VALEUR BRUTE : '$gemini_choice_1'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] *** LONGUEUR : ${#gemini_choice_1}" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] *** CODE ASCII premier char : $(printf '%d' "'$gemini_choice_1'" 2>/dev/null || echo 'N/A')" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Nettoyer au cas où
| cut -c1-150)...${NC}"    gemini_choice_1=$(echo "$gemini_choice_1" | tr -d '\n\r' | grep -o '[0-9]\+' | head -1)
| cut -c1-150)...${NC}"    echo "[DEBUG] *** APRÈS NETTOYAGE : '$gemini_choice_1'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] *** LONGUEUR APRÈS : ${#gemini_choice_1}" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    if [ -n "$gemini_choice_1" ] && [[ "$gemini_choice_1" =~ ^[0-9]+$ ]]; then
| cut -c1-150)...${NC}"        echo "[DEBUG] Gemini choice valide : '$gemini_choice_1'" >&2
| cut -c1-150)...${NC}"        local gemini_cat_1=$(get_category_with_parent "$gemini_choice_1")
| cut -c1-150)...${NC}"        echo -e "${GREEN}Gemini choisit : ${BOLD}$gemini_cat_1${NC}"
| cut -c1-150)...${NC}"    else
| cut -c1-150)...${NC}"        echo "[DEBUG] ERREUR : gemini_choice_1 invalide : '$gemini_choice_1'" >&2
| cut -c1-150)...${NC}"        echo "Gemini ne répond pas correctement !"
| cut -c1-150)...${NC}"        return 1
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo -n "   Claude analyse... "
| cut -c1-150)...${NC}"    echo "[DEBUG] Appel ask_claude Round 1..." >&2
| cut -c1-150)...${NC}"    local claude_choice_1=$(ask_claude "$title" "$authors" "$description" "$categories_list")
| cut -c1-150)...${NC}"    echo "[DEBUG] *** RETOUR ask_claude Round 1 ***" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] *** VALEUR BRUTE : '$claude_choice_1'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] *** LONGUEUR : ${#claude_choice_1}" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Nettoyer au cas où
| cut -c1-150)...${NC}"    claude_choice_1=$(echo "$claude_choice_1" | tr -d '\n\r' | grep -o '[0-9]\+' | head -1)
| cut -c1-150)...${NC}"    echo "[DEBUG] *** APRÈS NETTOYAGE : '$claude_choice_1'" >&2
| cut -c1-150)...${NC}"    echo "[DEBUG] *** LONGUEUR APRÈS : ${#claude_choice_1}" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    if [ -n "$claude_choice_1" ] && [[ "$claude_choice_1" =~ ^[0-9]+$ ]]; then
| cut -c1-150)...${NC}"        echo "[DEBUG] Claude choice valide : '$claude_choice_1'" >&2
| cut -c1-150)...${NC}"        local claude_cat_1=$(get_category_with_parent "$claude_choice_1")
| cut -c1-150)...${NC}"        echo -e "${BLUE}Claude choisit : ${BOLD}$claude_cat_1${NC}"
| cut -c1-150)...${NC}"    else
| cut -c1-150)...${NC}"        echo "[DEBUG] ERREUR : claude_choice_1 invalide : '$claude_choice_1'" >&2
| cut -c1-150)...${NC}"        echo "Claude ne répond pas correctement !"
| cut -c1-150)...${NC}"        return 1
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Vérifier si accord
| cut -c1-150)...${NC}"    echo "[DEBUG] Comparaison : gemini='$gemini_choice_1' vs claude='$claude_choice_1'" >&2
| cut -c1-150)...${NC}"    if [ "$gemini_choice_1" = "$claude_choice_1" ]; then
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"        echo -e "\n${GREEN}${BOLD}✅ ACCORD IMMÉDIAT sur : $gemini_cat_1${NC}"
| cut -c1-150)...${NC}"        local final_choice=$gemini_choice_1
| cut -c1-150)...${NC}"    else
| cut -c1-150)...${NC}"        # Désaccord - Round 2
| cut -c1-150)...${NC}"        echo ""
| cut -c1-150)...${NC}"        echo -e "\n${RED}${BOLD}❌ DÉSACCORD ! Round 2...${NC}"
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        echo -n "   Gemini reconsidère... "
| cut -c1-150)...${NC}"        echo "[DEBUG] Appel ask_gemini Round 2 avec suggestion Claude=$claude_choice_1..." >&2
| cut -c1-150)...${NC}"        local gemini_choice_2=$(ask_gemini "$title" "$authors" "$description" "$categories_list" "$claude_choice_1")
| cut -c1-150)...${NC}"        echo "[DEBUG] Retour ask_gemini Round 2 : '$gemini_choice_2'" >&2
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        # Nettoyer
| cut -c1-150)...${NC}"        gemini_choice_2=$(echo "$gemini_choice_2" | tr -d '\n\r' | grep -o '[0-9]\+' | head -1)
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        if [ -n "$gemini_choice_2" ] && [[ "$gemini_choice_2" =~ ^[0-9]+$ ]]; then
| cut -c1-150)...${NC}"            local gemini_cat_2=$(get_category_with_parent "$gemini_choice_2")
| cut -c1-150)...${NC}"            echo -e "${GREEN}Gemini change pour : ${BOLD}$gemini_cat_2${NC}"
| cut -c1-150)...${NC}"        else
| cut -c1-150)...${NC}"            echo "Gemini garde son choix"
| cut -c1-150)...${NC}"            gemini_choice_2=$gemini_choice_1
| cut -c1-150)...${NC}"            gemini_cat_2=$gemini_cat_1
| cut -c1-150)...${NC}"        fi
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        echo -n "   Claude reconsidère... "
| cut -c1-150)...${NC}"        echo "[DEBUG] Appel ask_claude Round 2 avec suggestion Gemini=$gemini_choice_1..." >&2
| cut -c1-150)...${NC}"        local claude_choice_2=$(ask_claude "$title" "$authors" "$description" "$categories_list" "$gemini_choice_1")
| cut -c1-150)...${NC}"        echo "[DEBUG] Retour ask_claude Round 2 : '$claude_choice_2'" >&2
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        # Nettoyer
| cut -c1-150)...${NC}"        claude_choice_2=$(echo "$claude_choice_2" | tr -d '\n\r' | grep -o '[0-9]\+' | head -1)
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        if [ -n "$claude_choice_2" ] && [[ "$claude_choice_2" =~ ^[0-9]+$ ]]; then
| cut -c1-150)...${NC}"            local claude_cat_2=$(get_category_with_parent "$claude_choice_2")
| cut -c1-150)...${NC}"            echo -e "${BLUE}Claude change pour : ${BOLD}$claude_cat_2${NC}"
| cut -c1-150)...${NC}"        else
| cut -c1-150)...${NC}"            echo "Claude garde son choix"
| cut -c1-150)...${NC}"            claude_choice_2=$claude_choice_1
| cut -c1-150)...${NC}"            claude_cat_2=$claude_cat_1
| cut -c1-150)...${NC}"        fi
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        # Résultat final
| cut -c1-150)...${NC}"        echo "[DEBUG] Comparaison Round 2 : gemini='$gemini_choice_2' vs claude='$claude_choice_2'" >&2
| cut -c1-150)...${NC}"        if [ "$gemini_choice_2" = "$claude_choice_2" ]; then
| cut -c1-150)...${NC}"            echo ""
| cut -c1-150)...${NC}"            echo -e "\n${GREEN}${BOLD}✅ CONSENSUS TROUVÉ sur : $gemini_cat_2${NC}"
| cut -c1-150)...${NC}"            local final_choice=$gemini_choice_2
| cut -c1-150)...${NC}"        else
| cut -c1-150)...${NC}"            echo ""
| cut -c1-150)...${NC}"            echo "⚠️  PAS DE CONSENSUS"
| cut -c1-150)...${NC}"            echo "   Choix final de Gemini : $gemini_cat_2"
| cut -c1-150)...${NC}"            echo "   Choix final de Claude : $claude_cat_2"
| cut -c1-150)...${NC}"            # En cas de désaccord persistant, prendre Claude
| cut -c1-150)...${NC}"            local final_choice=$claude_choice_2
| cut -c1-150)...${NC}"            echo "   → Choix retenu : $claude_cat_2 (Claude)"
| cut -c1-150)...${NC}"        fi
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] Choix final : ID=$final_choice" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Vérifier que final_choice est valide
| cut -c1-150)...${NC}"    if [ -z "$final_choice" ] || ! [[ "$final_choice" =~ ^[0-9]+$ ]]; then
| cut -c1-150)...${NC}"        echo "[DEBUG] ERREUR : final_choice invalide : '$final_choice'" >&2
| cut -c1-150)...${NC}"        echo "❌ Erreur : Aucune catégorie valide choisie"
| cut -c1-150)...${NC}"        return 1
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Récupérer le nom complet de la catégorie finale
| cut -c1-150)...${NC}"    local final_cat_name=$(get_category_with_parent "$final_choice")
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo ""
| cut -c1-150)...${NC}"    echo -e "\n${RED}${BOLD}📌 CATÉGORIE FINALE : $final_cat_name${NC}\n"
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Appliquer la catégorie
| cut -c1-150)...${NC}"    echo -n "💾 Application... "
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Obtenir le term_taxonomy_id
| cut -c1-150)...${NC}"    echo "[DEBUG] Recherche term_taxonomy_id pour term_id=$final_choice..." >&2
| cut -c1-150)...${NC}"    local term_taxonomy_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
| cut -c1-150)...${NC}"    SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
| cut -c1-150)...${NC}"    WHERE term_id = $final_choice AND taxonomy = 'product_cat'
| cut -c1-150)...${NC}"    " 2>/dev/null)
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] term_taxonomy_id trouvé : '$term_taxonomy_id'" >&2
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    if [ -z "$term_taxonomy_id" ]; then
| cut -c1-150)...${NC}"        echo "[DEBUG] ERREUR : term_taxonomy_id non trouvé pour term_id=$final_choice" >&2
| cut -c1-150)...${NC}"        echo "❌ Catégorie introuvable !"
| cut -c1-150)...${NC}"        return 1
| cut -c1-150)...${NC}"    fi
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Supprimer anciennes catégories
| cut -c1-150)...${NC}"    echo "[DEBUG] Suppression des anciennes catégories..." >&2
| cut -c1-150)...${NC}"    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
| cut -c1-150)...${NC}"    DELETE FROM wp_${SITE_ID}_term_relationships 
| cut -c1-150)...${NC}"    WHERE object_id = $post_id 
| cut -c1-150)...${NC}"    AND term_taxonomy_id IN (
| cut -c1-150)...${NC}"        SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
| cut -c1-150)...${NC}"        WHERE taxonomy = 'product_cat'
| cut -c1-150)...${NC}"    )
| cut -c1-150)...${NC}"    " 2>/dev/null
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Ajouter nouvelle catégorie
| cut -c1-150)...${NC}"    echo "[DEBUG] Ajout de la nouvelle catégorie term_taxonomy_id=$term_taxonomy_id..." >&2
| cut -c1-150)...${NC}"    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
| cut -c1-150)...${NC}"    INSERT IGNORE INTO wp_${SITE_ID}_term_relationships (object_id, term_taxonomy_id)
| cut -c1-150)...${NC}"    VALUES ($post_id, $term_taxonomy_id)
| cut -c1-150)...${NC}"    " 2>/dev/null
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "✅ Fait!"
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    # Log
| cut -c1-150)...${NC}"    mkdir -p "$LOG_DIR"
| cut -c1-150)...${NC}"    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ID:$post_id - $title → $final_cat_name" >> "$LOG_DIR/dual_ai_categorize.log"
| cut -c1-150)...${NC}"    
| cut -c1-150)...${NC}"    echo "[DEBUG] === FIN categorize_with_dual_ai ===" >&2
| cut -c1-150)...${NC}"}
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Programme principal
| cut -c1-150)...${NC}"clear
| cut -c1-150)...${NC}"echo "=== SMART CATEGORIZE - DUAL AI MODE ==="
| cut -c1-150)...${NC}"echo "Gemini + Claude débattent pour trouver la meilleure catégorie"
| cut -c1-150)...${NC}"echo "════════════════════════════════════════════════════════════════════════════"
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Vérifier les clés
| cut -c1-150)...${NC}"echo "[DEBUG] Vérification des clés API..." >&2
| cut -c1-150)...${NC}"echo "[DEBUG] GEMINI_API_KEY : ${GEMINI_API_KEY:0:10}..." >&2
| cut -c1-150)...${NC}"echo "[DEBUG] CLAUDE_API_KEY : ${CLAUDE_API_KEY:0:10}..." >&2
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"if [ -z "$GEMINI_API_KEY" ] || [ -z "$CLAUDE_API_KEY" ]; then
| cut -c1-150)...${NC}"    echo "❌ ERREUR : Les deux clés API sont requises"
| cut -c1-150)...${NC}"    echo "Lancez : ./setup_dual_ai.sh"
| cut -c1-150)...${NC}"    exit 1
| cut -c1-150)...${NC}"fi
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Si mode debug
| cut -c1-150)...${NC}"if [ "$SHOW_PROMPTS" = "1" ]; then
| cut -c1-150)...${NC}"    echo ""
| cut -c1-150)...${NC}"    echo "🔍 MODE DEBUG ACTIVÉ - Les prompts seront affichés"
| cut -c1-150)...${NC}"    echo ""
| cut -c1-150)...${NC}"fi
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Menu
| cut -c1-150)...${NC}"if [ -z "$1" ]; then
| cut -c1-150)...${NC}"    echo ""
| cut -c1-150)...${NC}"    echo "Usage :"
| cut -c1-150)...${NC}"    echo "  ./smart_categorize_dual_ai.sh ISBN"
| cut -c1-150)...${NC}"    echo "  ./smart_categorize_dual_ai.sh -id ID"
| cut -c1-150)...${NC}"    echo "  ./smart_categorize_dual_ai.sh -batch N"
| cut -c1-150)...${NC}"    echo ""
| cut -c1-150)...${NC}"    echo "Mode debug : SHOW_PROMPTS=1 ./smart_categorize_dual_ai.sh ISBN"
| cut -c1-150)...${NC}"    echo ""
| cut -c1-150)...${NC}"    echo -n "ISBN ou ID du livre : "
| cut -c1-150)...${NC}"    read input
| cut -c1-150)...${NC}"else
| cut -c1-150)...${NC}"    input="$1"
| cut -c1-150)...${NC}"fi
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"echo "[DEBUG] Input reçu : '$input'" >&2
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"# Traiter l'input
| cut -c1-150)...${NC}"case "$input" in
| cut -c1-150)...${NC}"    -id)
| cut -c1-150)...${NC}"        echo "[DEBUG] Mode ID direct : ID=$2" >&2
| cut -c1-150)...${NC}"        categorize_with_dual_ai "$2"
| cut -c1-150)...${NC}"        ;;
| cut -c1-150)...${NC}"    -batch)
| cut -c1-150)...${NC}"        limit="${2:-5}"
| cut -c1-150)...${NC}"        echo "Catégorisation de $limit livres..."
| cut -c1-150)...${NC}"        echo "[DEBUG] Recherche de $limit livres sans catégorie..." >&2
| cut -c1-150)...${NC}"        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
| cut -c1-150)...${NC}"        SELECT DISTINCT p.ID
| cut -c1-150)...${NC}"        FROM wp_${SITE_ID}_posts p
| cut -c1-150)...${NC}"        LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
| cut -c1-150)...${NC}"        LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
| cut -c1-150)...${NC}"        WHERE p.post_type = 'product'
| cut -c1-150)...${NC}"        AND p.post_status = 'publish'
| cut -c1-150)...${NC}"        AND (tt.taxonomy != 'product_cat' OR tt.taxonomy IS NULL)
| cut -c1-150)...${NC}"        LIMIT $limit
| cut -c1-150)...${NC}"        " 2>/dev/null | while read post_id; do
| cut -c1-150)...${NC}"            echo "[DEBUG] Traitement du livre ID=$post_id" >&2
| cut -c1-150)...${NC}"            categorize_with_dual_ai "$post_id"
| cut -c1-150)...${NC}"            echo "════════════════════════════════════════════════════════════════════════════"
| cut -c1-150)...${NC}"            sleep 2  # Pause entre chaque livre
| cut -c1-150)...${NC}"        done
| cut -c1-150)...${NC}"        ;;
| cut -c1-150)...${NC}"    *)
| cut -c1-150)...${NC}"        # Chercher par ISBN
| cut -c1-150)...${NC}"        echo "[DEBUG] Recherche par ISBN : '$input'" >&2
| cut -c1-150)...${NC}"        post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
| cut -c1-150)...${NC}"        SELECT post_id FROM wp_${SITE_ID}_postmeta 
| cut -c1-150)...${NC}"        WHERE meta_key = '_isbn' AND meta_value = '$input'
| cut -c1-150)...${NC}"        LIMIT 1
| cut -c1-150)...${NC}"        " 2>/dev/null)
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        echo "[DEBUG] Post ID trouvé : '$post_id'" >&2
| cut -c1-150)...${NC}"        
| cut -c1-150)...${NC}"        if [ -n "$post_id" ]; then
| cut -c1-150)...${NC}"            categorize_with_dual_ai "$post_id"
| cut -c1-150)...${NC}"        else
| cut -c1-150)...${NC}"            echo "❌ ISBN '$input' non trouvé"
| cut -c1-150)...${NC}"        fi
| cut -c1-150)...${NC}"        ;;
| cut -c1-150)...${NC}"esac
| cut -c1-150)...${NC}"
| cut -c1-150)...${NC}"echo ""
| cut -c1-150)...${NC}"echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"