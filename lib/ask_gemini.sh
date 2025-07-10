#!/bin/bash
echo "[START: ask_gemini.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# lib/ask_gemini.sh - Fonction pour interroger l'API Gemini

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

    # Si Claude a déjà répondu
    if [ -n "$previous_claude_response" ]; then
        prompt="$prompt

Note: Claude a suggéré la catégorie ID:$previous_claude_response
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

echo "[END: ask_gemini.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
