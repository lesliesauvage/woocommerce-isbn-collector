#!/bin/bash
# lib/ask_claude.sh - Fonction pour interroger l'API Claude

# Demander à Claude
ask_claude() {
    debug_echo "[DEBUG] === DÉBUT ask_claude ==="
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
    
    # Appel à Claude
    debug_echo "[DEBUG] Appel curl vers Claude API..."
    debug_echo "[DEBUG] URL : $CLAUDE_API_URL"
    debug_echo "[DEBUG] API Key : ${CLAUDE_API_KEY:0:10}..."
    
    local response=$(curl -s -X POST "$CLAUDE_API_URL" \
        -H "x-api-key: $CLAUDE_API_KEY" \
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
    if ! analyze_api_error "$response" "Claude"; then
        debug_echo "[DEBUG] === FIN ask_claude avec ERREUR ==="
        return 1
    fi
    
    # Extraire la réponse avec la fonction
    debug_echo "[DEBUG] Appel extract_text_from_json..."
    local extracted_id=$(extract_text_from_json "$response" "claude")
    debug_echo "[DEBUG] ID extrait par la fonction : '$extracted_id'"
    
    # Si Claude dit qu'il est d'accord, prendre la suggestion
    local claude_text=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['content'][0]['text'])
except:
    pass" 2>/dev/null)
    
    debug_echo "[DEBUG] Texte complet de Claude : '$claude_text'"
    
    if echo "$claude_text" | grep -qi "d'accord\|agree\|oui\|yes"; then
        debug_echo "[DEBUG] Claude semble d'accord avec Gemini"
        if [ -n "$previous_gemini_response" ]; then
            extracted_id="$previous_gemini_response"
            debug_echo "[DEBUG] Utilisation de la suggestion Gemini : '$extracted_id'"
        fi
    fi
    
    if [ "$SHOW_PROMPTS" = "1" ] && [ "$VERBOSE" = "1" ] && [ -n "$extracted_id" ]; then
        echo -e "${BLUE}🔢 ID final extrait de Claude : ${BOLD}$extracted_id${NC}" >&2
        echo "" >&2
    fi
    
    debug_echo "[DEBUG] === FIN ask_claude, retour : '$extracted_id' ==="
    # IMPORTANT : Retourner UNIQUEMENT l'ID extrait
    echo "$extracted_id"
}
