#!/bin/bash
# smart_categorize_dual_ai.sh - CATÉGORISATION INTELLIGENTE AVEC DOUBLE IA
# Version COMPLÈTE avec TOUTES les fonctionnalités + corrections de bugs
# 
# Ce script utilise deux IA (Gemini et Claude) pour débattre et trouver
# la meilleure catégorie WordPress pour un livre donné.
#
# Usage:
#   ./smart_categorize_dual_ai.sh [ISBN ou ID]
#   ./smart_categorize_dual_ai.sh -id [ID_PRODUIT]
#
# Exemples:
#   ./smart_categorize_dual_ai.sh 9782070360024
#   ./smart_categorize_dual_ai.sh 16091
#   ./smart_categorize_dual_ai.sh -id 16091
#
# Configuration requise:
#   - GEMINI_API_KEY dans config/credentials.sh
#   - CLAUDE_API_KEY dans config/credentials.sh
#
# Logs:
#   Les résultats sont enregistrés dans logs/dual_ai_categorize.log

# Charger la configuration et les fonctions sécurisées
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

# Mode debug pour voir les prompts et réponses complètes (0=non, 1=oui)
SHOW_PROMPTS=${SHOW_PROMPTS:-0}

# Mode verbose pour afficher plus d'informations
VERBOSE=${VERBOSE:-1}

# Timeout pour les appels API (en secondes)
API_TIMEOUT=${API_TIMEOUT:-30}

# Nombre maximum de tentatives en cas d'erreur
MAX_RETRIES=${MAX_RETRIES:-3}

# Délai entre les tentatives (en secondes)
RETRY_DELAY=${RETRY_DELAY:-2}

# Catégorie par défaut si aucun consensus
DEFAULT_CATEGORY_ID="272"  # LITTÉRATURE > Romans
DEFAULT_CATEGORY_NAME="LITTÉRATURE > Romans"

# Fonction pour afficher un message verbose
verbose_log() {
    [ "$VERBOSE" = "1" ] && echo "$@"
}

# Fonction pour logger dans le fichier
log_to_file() {
    local message="$1"
    local log_file="$LOG_DIR/dual_ai_categorize.log"
    
    # Créer le dossier logs si nécessaire
    [ ! -d "$LOG_DIR" ] && mkdir -p "$LOG_DIR"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$log_file"
}

# Fonction pour afficher une barre de progression
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    
    printf "\r["
    printf "%${completed}s" | tr ' ' '='
    printf "%$((width - completed))s" | tr ' ' '-'
    printf "] %d%%" $percentage
}

# Fonction pour extraire le texte de la réponse JSON avec gestion d'erreur améliorée
extract_text_from_json() {
    local json_response="$1"
    local api_type="$2"
    
    echo "[DEBUG] Extraction pour $api_type..." >&2
    echo "[DEBUG] JSON length: ${#json_response}" >&2
    
    # Vérifier que la réponse n'est pas vide
    if [ -z "$json_response" ]; then
        echo "[DEBUG] ERREUR : Réponse JSON vide" >&2
        return 1
    fi
    
    # Afficher un extrait de la réponse pour debug
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo "[DEBUG] Extrait réponse (200 car) : ${json_response:0:200}..." >&2
    fi
    
    local result=""
    if [ "$api_type" = "gemini" ]; then
        # Extraction pour Gemini
        result=$(echo "$json_response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null | tr -d '\n' | sed 's/[[:space:]]\+/ /g')
        
        # Si échec, essayer une autre structure
        if [ -z "$result" ]; then
            result=$(echo "$json_response" | jq -r '.candidates[0].output // empty' 2>/dev/null | tr -d '\n' | sed 's/[[:space:]]\+/ /g')
        fi
    else
        # Extraction pour Claude
        result=$(echo "$json_response" | jq -r '.content[0].text // empty' 2>/dev/null | tr -d '\n' | sed 's/[[:space:]]\+/ /g')
        
        # Si échec, essayer une autre structure
        if [ -z "$result" ]; then
            result=$(echo "$json_response" | jq -r '.completion // empty' 2>/dev/null | tr -d '\n' | sed 's/[[:space:]]\+/ /g')
        fi
    fi
    
    echo "[DEBUG] Result before cleaning: '$result'" >&2
    echo "[DEBUG] Result length: ${#result}" >&2
    
    # Nettoyer et extraire juste le nombre
    local clean_result=$(echo "$result" | grep -oE '[0-9]+' | head -1)
    echo "[DEBUG] Résultat extrait et nettoyé : '$clean_result'" >&2
    echo "[DEBUG] Final length: ${#clean_result}" >&2
    
    # Valider que c'est bien un nombre
    if [[ "$clean_result" =~ ^[0-9]+$ ]]; then
        echo "$clean_result"
        return 0
    else
        echo "[DEBUG] ERREUR : Pas un nombre valide" >&2
        return 1
    fi
}

# Fonction pour faire un appel API avec retry
api_call_with_retry() {
    local api_function="$1"
    shift
    local args=("$@")
    
    local attempt=1
    local result=""
    
    while [ $attempt -le $MAX_RETRIES ]; do
        verbose_log "   Tentative $attempt/$MAX_RETRIES..."
        
        # Appeler la fonction API
        result=$("$api_function" "${args[@]}")
        
        # Vérifier si on a un résultat valide
        if [ -n "$result" ] && [[ "$result" =~ ^[0-9]+$ ]]; then
            echo "$result"
            return 0
        fi
        
        # Si c'était la dernière tentative, abandonner
        if [ $attempt -eq $MAX_RETRIES ]; then
            echo "[DEBUG] Échec après $MAX_RETRIES tentatives" >&2
            return 1
        fi
        
        # Attendre avant de réessayer
        verbose_log "   Échec, nouvelle tentative dans ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
        
        ((attempt++))
    done
    
    return 1
}

# Fonction pour demander à Gemini avec gestion d'erreur améliorée
ask_gemini() {
    local title="$1"
    local authors="$2"
    local description="$3"
    local categories="$4"
    local previous_claude="$5"
    
    echo "[DEBUG] === DÉBUT ask_gemini ===" >&2
    echo "[DEBUG] Paramètres reçus :" >&2
    echo "[DEBUG]   title='${title:0:20}...'" >&2
    echo "[DEBUG]   authors='$authors'" >&2
    echo "[DEBUG]   description length=${#description}" >&2
    echo "[DEBUG]   categories count=$(echo "$categories" | wc -l)" >&2
    echo "[DEBUG]   previous_claude='$previous_claude'" >&2
    
    # Construire le prompt de manière structurée
    local prompt="Tu es un expert en classification de livres. Tu dois catégoriser ce livre dans LA catégorie la plus précise possible.

INFORMATIONS DU LIVRE:
- Titre: $title
- Auteur(s): $authors
- Description: ${description:0:500}...

CATÉGORIES DISPONIBLES (format ID:Chemin > Complet):
$categories

RÈGLES STRICTES À SUIVRE:
1. Tu DOIS choisir une catégorie qui existe dans la liste ci-dessus
2. Réponds UNIQUEMENT avec l'ID numérique de la catégorie choisie
3. Un seul nombre, rien d'autre (pas de texte, pas d'explication)
4. L'ID doit être un nombre entre 1 et 9999
5. Ne jamais inventer un ID qui n'est pas dans la liste"

    # Ajouter la suggestion de Claude si présente
    if [ -n "$previous_claude" ]; then
        prompt="$prompt

CONTEXTE ADDITIONNEL:
Claude suggère la catégorie ID $previous_claude. 
Prends en compte cette suggestion, mais choisis la catégorie que TU juges la plus appropriée.
Si tu es d'accord avec Claude, réponds avec le même ID.
Sinon, choisis un ID différent de la liste."
    fi
    
    # Ajouter des exemples pour guider
    prompt="$prompt

EXEMPLES DE RÉPONSES CORRECTES:
- Si c'est un roman français classique → cherche l'ID de 'Romans > Romans français'
- Si c'est un livre pour enfants → cherche l'ID dans la section ENFANTS
- Si c'est une BD → cherche l'ID dans la section BANDE DESSINÉE

RAPPEL: Réponds UNIQUEMENT avec l'ID numérique, rien d'autre."

    # Debug : afficher le prompt complet si demandé
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo "════════════════════════════════════════════════════════════" >&2
        echo "[PROMPT GEMINI COMPLET]" >&2
        echo "$prompt" >&2
        echo "════════════════════════════════════════════════════════════" >&2
    fi

    # Échapper le prompt pour JSON (gérer les apostrophes, guillemets, retours ligne)
    echo "[DEBUG] Échappement du prompt pour JSON..." >&2
    local escaped_prompt=$(echo "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')
    echo "[DEBUG] Prompt échappé (50 car) : ${escaped_prompt:0:50}..." >&2

    # Construire le payload JSON
    local json_payload=$(cat <<EOF
{
    "contents": [{
        "parts": [{
            "text": "$escaped_prompt"
        }]
    }],
    "generationConfig": {
        "temperature": 0.1,
        "maxOutputTokens": 20,
        "topK": 1,
        "topP": 0.1
    },
    "safetySettings": [
        {
            "category": "HARM_CATEGORY_HARASSMENT",
            "threshold": "BLOCK_NONE"
        },
        {
            "category": "HARM_CATEGORY_HATE_SPEECH",
            "threshold": "BLOCK_NONE"
        },
        {
            "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
            "threshold": "BLOCK_NONE"
        },
        {
            "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
            "threshold": "BLOCK_NONE"
        }
    ]
}
EOF
)

    # Debug : afficher le payload si demandé
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo "[JSON PAYLOAD GEMINI]" >&2
        echo "$json_payload" | jq '.' 2>/dev/null || echo "$json_payload" >&2
    fi

    # Appel API avec timeout et gestion d'erreur
    echo "[DEBUG] Appel curl vers Gemini API..." >&2
    local response=$(curl -s -X POST \
        --max-time "$API_TIMEOUT" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY" 2>/dev/null)
    
    local curl_status=$?
    echo "[DEBUG] URL : https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY:0:10}..." >&2
    echo "[DEBUG] Statut curl : $curl_status" >&2
    echo "[DEBUG] Taille réponse : ${#response} caractères" >&2
    
    # Vérifier le statut curl
    if [ $curl_status -ne 0 ]; then
        echo "[DEBUG] ERREUR curl : code $curl_status" >&2
        return 1
    fi
    
    # Debug : afficher la réponse complète si demandé
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo "════════════════════════════════════════════════════════════" >&2
        echo "[RÉPONSE GEMINI BRUTE]" >&2
        echo "$response" | jq '.' 2>/dev/null || echo "$response" >&2
        echo "════════════════════════════════════════════════════════════" >&2
    fi
    
    # Vérifier les erreurs dans la réponse
    if echo "$response" | grep -q '"error"'; then
        echo "[DEBUG] ERREUR détectée dans la réponse Gemini !" >&2
        local error_message=$(echo "$response" | jq -r '.error.message // "Erreur inconnue"' 2>/dev/null)
        echo "[DEBUG] Message d'erreur : $error_message" >&2
        log_to_file "ERREUR Gemini : $error_message"
        return 1
    fi
    
    # Vérifier si la réponse contient des candidats
    local has_candidates=$(echo "$response" | jq -r '.candidates // empty' 2>/dev/null)
    if [ -z "$has_candidates" ]; then
        echo "[DEBUG] ERREUR : Pas de candidats dans la réponse" >&2
        return 1
    fi
    
    # Extraire l'ID uniquement
    echo "[DEBUG] Appel extract_text_from_json..." >&2
    local extracted_id=$(extract_text_from_json "$response" "gemini")
    local extract_status=$?
    
    echo "[DEBUG] ID extrait par la fonction : '$extracted_id' (status: $extract_status)" >&2
    
    # Vérifier que l'extraction a réussi
    if [ $extract_status -ne 0 ] || [ -z "$extracted_id" ]; then
        echo "[DEBUG] ERREUR : Extraction échouée" >&2
        return 1
    fi
    
    # Valider que l'ID est dans une plage raisonnable
    if [ "$extracted_id" -lt 1 ] || [ "$extracted_id" -gt 9999 ]; then
        echo "[DEBUG] ERREUR : ID hors limites ($extracted_id)" >&2
        return 1
    fi
    
    echo "[DEBUG] === FIN ask_gemini, retour : '$extracted_id' ===" >&2
    
    # Retourner UNIQUEMENT l'ID
    echo "$extracted_id"
}

# Fonction pour demander à Claude avec gestion d'erreur améliorée
ask_claude() {
    local title="$1"
    local authors="$2"
    local description="$3"
    local categories="$4"
    local previous_gemini="$5"
    
    echo "[DEBUG] === DÉBUT ask_claude ===" >&2
    echo "[DEBUG] Paramètres reçus :" >&2
    echo "[DEBUG]   title='${title:0:20}...'" >&2
    echo "[DEBUG]   authors='$authors'" >&2
    echo "[DEBUG]   description length=${#description}" >&2
    echo "[DEBUG]   categories count=$(echo "$categories" | wc -l)" >&2
    echo "[DEBUG]   previous_gemini='$previous_gemini'" >&2
    
    # Construire le prompt de manière structurée
    local prompt="Tu es un expert en classification de livres. Tu dois catégoriser ce livre dans LA catégorie la plus précise possible.

INFORMATIONS DU LIVRE:
- Titre: $title
- Auteur(s): $authors
- Description: ${description:0:500}...

CATÉGORIES DISPONIBLES (format ID:Chemin > Complet):
$categories

RÈGLES STRICTES À SUIVRE:
1. Tu DOIS choisir une catégorie qui existe dans la liste ci-dessus
2. Réponds UNIQUEMENT avec l'ID numérique de la catégorie choisie
3. Un seul nombre, rien d'autre (pas de texte, pas d'explication)
4. L'ID doit être un nombre entre 1 et 9999
5. Ne jamais inventer un ID qui n'est pas dans la liste"

    # Ajouter la suggestion de Gemini si présente
    if [ -n "$previous_gemini" ]; then
        prompt="$prompt

CONTEXTE ADDITIONNEL:
Gemini suggère la catégorie ID $previous_gemini.
Prends en compte cette suggestion, mais choisis la catégorie que TU juges la plus appropriée.
Si tu es d'accord avec Gemini, réponds avec le même ID.
Sinon, choisis un ID différent de la liste."
    fi
    
    # Ajouter des exemples pour guider
    prompt="$prompt

EXEMPLES DE RÉPONSES CORRECTES:
- Si c'est un roman français classique → cherche l'ID de 'Romans > Romans français'
- Si c'est un livre pour enfants → cherche l'ID dans la section ENFANTS
- Si c'est une BD → cherche l'ID dans la section BANDE DESSINÉE

RAPPEL: Réponds UNIQUEMENT avec l'ID numérique, rien d'autre."

    # Debug : afficher le prompt complet si demandé
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo "════════════════════════════════════════════════════════════" >&2
        echo "[PROMPT CLAUDE COMPLET]" >&2
        echo "$prompt" >&2
        echo "════════════════════════════════════════════════════════════" >&2
    fi

    # Échapper le prompt pour JSON
    echo "[DEBUG] Échappement du prompt pour JSON..." >&2
    local escaped_prompt=$(echo "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')
    echo "[DEBUG] Prompt échappé (50 car) : ${escaped_prompt:0:50}..." >&2

    # Construire le payload JSON pour Claude
    local json_payload=$(cat <<EOF
{
    "model": "claude-3-haiku-20240307",
    "max_tokens": 20,
    "temperature": 0.1,
    "messages": [{
        "role": "user",
        "content": "$escaped_prompt"
    }]
}
EOF
)

    # Debug : afficher le payload si demandé
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo "[JSON PAYLOAD CLAUDE]" >&2
        echo "$json_payload" | jq '.' 2>/dev/null || echo "$json_payload" >&2
    fi

    # Appel API Claude avec timeout et gestion d'erreur
    echo "[DEBUG] Appel curl vers Claude API..." >&2
    local response=$(curl -s -X POST https://api.anthropic.com/v1/messages \
        --max-time "$API_TIMEOUT" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "$json_payload" 2>/dev/null)
    
    local curl_status=$?
    echo "[DEBUG] URL : https://api.anthropic.com/v1/messages" >&2
    echo "[DEBUG] API Key : ${CLAUDE_API_KEY:0:10}..." >&2
    echo "[DEBUG] Statut curl : $curl_status" >&2
    echo "[DEBUG] Taille réponse : ${#response} caractères" >&2
    
    # Vérifier le statut curl
    if [ $curl_status -ne 0 ]; then
        echo "[DEBUG] ERREUR curl : code $curl_status" >&2
        return 1
    fi
    
    # Debug : afficher la réponse complète si demandé
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo "════════════════════════════════════════════════════════════" >&2
        echo "[RÉPONSE CLAUDE BRUTE]" >&2
        echo "$response" | jq '.' 2>/dev/null || echo "$response" >&2
        echo "════════════════════════════════════════════════════════════" >&2
    fi
    
    # Vérifier les erreurs dans la réponse
    if echo "$response" | grep -q '"error"'; then
        echo "[DEBUG] ERREUR détectée dans la réponse Claude !" >&2
        local error_type=$(echo "$response" | jq -r '.error.type // "unknown"' 2>/dev/null)
        local error_message=$(echo "$response" | jq -r '.error.message // "Erreur inconnue"' 2>/dev/null)
        echo "[DEBUG] Type d'erreur : $error_type" >&2
        echo "[DEBUG] Message : $error_message" >&2
        log_to_file "ERREUR Claude : $error_type - $error_message"
        return 1
    fi
    
    # Extraire l'ID
    echo "[DEBUG] Appel extract_text_from_json..." >&2
    local extracted_id=$(extract_text_from_json "$response" "claude")
    local extract_status=$?
    
    echo "[DEBUG] ID extrait par la fonction : '$extracted_id' (status: $extract_status)" >&2
    
    # Si l'extraction via jq a échoué, essayer directement
    if [ $extract_status -ne 0 ] || [ -z "$extracted_id" ]; then
        echo "[DEBUG] Tentative d'extraction alternative..." >&2
        extracted_id=$(echo "$response" | grep -oE '"text":"[0-9]+"' | grep -oE '[0-9]+' | head -1)
        echo "[DEBUG] Extraction alternative : '$extracted_id'" >&2
    fi
    
    # Vérifier que l'extraction a réussi
    if [ -z "$extracted_id" ]; then
        echo "[DEBUG] ERREUR : Aucun ID extrait" >&2
        return 1
    fi
    
    # Valider que l'ID est dans une plage raisonnable
    if [ "$extracted_id" -lt 1 ] || [ "$extracted_id" -gt 9999 ]; then
        echo "[DEBUG] ERREUR : ID hors limites ($extracted_id)" >&2
        return 1
    fi
    
    echo "[DEBUG] === FIN ask_claude, retour : '$extracted_id' ===" >&2
    
    # Retourner UNIQUEMENT l'ID
    echo "$extracted_id"
}

# Fonction pour obtenir la hiérarchie complète d'une catégorie
get_category_hierarchy() {
    local cat_id="$1"
    
    echo "[DEBUG] Recherche hiérarchie pour cat_id='$cat_id'" >&2
    
    # Vérifier que l'ID est valide
    if [ -z "$cat_id" ] || ! [[ "$cat_id" =~ ^[0-9]+$ ]]; then
        echo "[DEBUG] ERREUR : ID invalide '$cat_id'" >&2
        return 1
    fi
    
    # Requête récursive pour obtenir la hiérarchie complète
    local hierarchy=$(safe_mysql "
        WITH RECURSIVE cat_path AS (
            -- Catégorie de départ
            SELECT 
                t.term_id,
                t.name,
                tt.parent,
                t.name as path
            FROM wp_${SITE_ID}_terms t
            JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
            WHERE t.term_id = '$cat_id'
            AND tt.taxonomy = 'product_cat'
            
            UNION ALL
            
            -- Remonter la hiérarchie
            SELECT 
                t.term_id,
                t.name,
                tt.parent,
                CONCAT(t.name, ' > ', cp.path) as path
            FROM wp_${SITE_ID}_terms t
            JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
            JOIN cat_path cp ON tt.term_id = cp.parent
            WHERE tt.taxonomy = 'product_cat'
        )
        SELECT path FROM cat_path
        WHERE parent = 0
        LIMIT 1")
    
    # Si pas de résultat avec la requête récursive, essayer simple
    if [ -z "$hierarchy" ]; then
        echo "[DEBUG] Requête récursive sans résultat, essai simple..." >&2
        hierarchy=$(safe_mysql "
            SELECT t.name 
            FROM wp_${SITE_ID}_terms t
            JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
            WHERE t.term_id = '$cat_id'
            AND tt.taxonomy = 'product_cat'
            LIMIT 1")
    fi
    
    echo "[DEBUG] Hiérarchie trouvée : '$hierarchy'" >&2
    echo "$hierarchy"
}

# Fonction pour valider qu'une catégorie existe
validate_category_exists() {
    local cat_id="$1"
    
    # Vérifier que l'ID est valide
    if [ -z "$cat_id" ] || ! [[ "$cat_id" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    local exists=$(safe_mysql "
        SELECT COUNT(*) 
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE t.term_id = '$cat_id'
        AND tt.taxonomy = 'product_cat'")
    
    [ "$exists" = "1" ]
}

# Fonction pour afficher les catégories disponibles de manière formatée
display_available_categories() {
    echo ""
    echo "📂 CATÉGORIES DISPONIBLES"
    echo "════════════════════════════════════════════════════════════════════════════"
    
    # Récupérer un échantillon de catégories principales
    local main_categories=$(safe_mysql "
        SELECT CONCAT('  • ', t.name, ' (ID:', t.term_id, ')')
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE tt.taxonomy = 'product_cat'
        AND tt.parent = 0
        ORDER BY t.name
        LIMIT 10")
    
    echo "$main_categories"
    echo "  ... et bien d'autres"
    echo ""
}

# Fonction pour afficher l'analyse en cours
display_analysis_progress() {
    local step=$1
    local message=$2
    
    case $step in
        1) echo "🔍 Étape 1/4 : $message" ;;
        2) echo "🤖 Étape 2/4 : $message" ;;
        3) echo "🤔 Étape 3/4 : $message" ;;
        4) echo "✅ Étape 4/4 : $message" ;;
    esac
}

# Fonction principale de catégorisation avec double IA
categorize_with_dual_ai() {
    local product_id="$1"
    
    echo "[DEBUG] === DÉBUT categorize_with_dual_ai pour post_id=$product_id ===" >&2
    log_to_file "Début catégorisation pour produit ID: $product_id"
    
    # Afficher la progression
    display_analysis_progress 1 "Récupération des informations du livre..."
    
    # Récupérer les infos du livre avec échappement correct
    echo "[DEBUG] Récupération des infos du livre ID $product_id..." >&2
    local book_info=$(safe_mysql "
        SELECT 
            REPLACE(p.post_title, \"'\", \"\\\\'\") as title,
            pm_isbn.meta_value as isbn,
            COALESCE(pm_authors.meta_value, pm_g_authors.meta_value) as authors,
            COALESCE(pm_desc.meta_value, pm_g_desc.meta_value) as description
        FROM wp_${SITE_ID}_posts p
        LEFT JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_g_authors ON p.ID = pm_g_authors.post_id AND pm_g_authors.meta_key = '_g_authors'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_g_desc ON p.ID = pm_g_desc.post_id AND pm_g_desc.meta_key = '_g_description'
        WHERE p.ID = '$product_id'")
    
    echo "[DEBUG] book_info trouvé : ${#book_info} caractères" >&2
    
    # Vérifier qu'on a bien des données
    if [ -z "$book_info" ]; then
        echo "❌ ERREUR : Impossible de récupérer les informations du livre"
        log_to_file "ERREUR : Pas de données pour le produit ID: $product_id"
        return 1
    fi
    
    # Parser les infos avec gestion des apostrophes
    IFS=$'\t' read -r title isbn authors description <<< "$book_info"
    
    echo "[DEBUG] Infos parsées :" >&2
    echo "[DEBUG]   title='${title:0:50}...'" >&2
    echo "[DEBUG]   isbn='$isbn'" >&2
    echo "[DEBUG]   authors='$authors'" >&2
    echo "[DEBUG]   description length=${#description}" >&2
    
    # Si le titre est générique, chercher le vrai titre
    if [[ "$title" =~ ^Livre[[:space:]].*$ ]] || [[ "$title" =~ ^Book[[:space:]].*$ ]]; then
        echo "[DEBUG] Titre générique détecté, recherche du vrai titre..." >&2
        local real_title=$(safe_mysql "
            SELECT COALESCE(
                (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = '$product_id' AND meta_key = '_best_title'),
                (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = '$product_id' AND meta_key = '_g_title')
            )")
        if [ -n "$real_title" ]; then
            title="$real_title"
            echo "[DEBUG] Vrai titre trouvé : '$title'" >&2
        fi
    fi
    
    # Récupérer aussi la catégorie Google Books pour référence
    local google_categories=$(safe_mysql "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = '$product_id' AND meta_key = '_g_categories'")
    
    # Afficher les informations du livre
    echo ""
    echo "📚 LIVRE À CATÉGORISER"
    echo "════════════════════════════════════════════════════════════════════════════"
    echo "   📖 Titre : $title"
    echo "   📗 ISBN : $isbn"
    echo "   ✍️  Auteurs : ${authors:-Non renseigné}"
    echo "   📝 Description : ${description:0:100}..."
    if [ -n "$google_categories" ]; then
        echo "   🏷️  Catégories Google : $google_categories"
    fi
    echo ""
    
    # Afficher la progression
    display_analysis_progress 2 "Chargement des catégories WordPress..."
    
    # Récupérer toutes les catégories avec hiérarchie
    echo "📋 Récupération des catégories avec hiérarchie..."
    echo "[DEBUG] Récupération des catégories AVEC hiérarchie..." >&2
    
    # Requête optimisée pour récupérer toutes les catégories avec leur chemin complet
    local categories_list=$(safe_mysql "
        WITH RECURSIVE cat_hierarchy AS (
            -- Toutes les catégories de base
            SELECT 
                t.term_id,
                t.name,
                tt.parent,
                t.name as full_path,
                0 as level
            FROM wp_${SITE_ID}_terms t
            JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
            WHERE tt.taxonomy = 'product_cat'
            AND tt.parent = 0
            
            UNION ALL
            
            -- Catégories enfants
            SELECT 
                t.term_id,
                t.name,
                tt.parent,
                CONCAT(ch.full_path, ' > ', t.name) as full_path,
                ch.level + 1
            FROM wp_${SITE_ID}_terms t
            JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
            JOIN cat_hierarchy ch ON tt.parent = ch.term_id
            WHERE tt.taxonomy = 'product_cat'
        )
        SELECT CONCAT(term_id, ':', full_path) 
        FROM cat_hierarchy
        ORDER BY full_path")
    
    local cat_count=$(echo "$categories_list" | wc -l)
    echo "   ✅ $cat_count catégories disponibles"
    
    # Debug : afficher quelques exemples de catégories
    if [ "$VERBOSE" = "1" ]; then
        echo ""
        echo "   Exemples de catégories :"
        echo "$categories_list" | head -10 | while read cat; do
            local cat_id=$(echo "$cat" | cut -d':' -f1)
            local cat_path=$(echo "$cat" | cut -d':' -f2-)
            echo "     • $cat_path (ID:$cat_id)"
        done
        echo "     ..."
    fi
    
    # Préparer le format pour les IAs
    local categories_for_ai=$(echo "$categories_list" | tr '\n' '\n')
    
    # Afficher la progression
    display_analysis_progress 3 "Analyse par intelligence artificielle..."
    
    # ROUND 1 - Première analyse
    echo ""
    echo "🤖 ROUND 1 - Première analyse indépendante"
    echo "──────────────────────────────────────────────────────────────────────"
    
    # Demander à Gemini avec retry
    echo -n "   🔵 Gemini analyse... "
    echo "[DEBUG] Appel ask_gemini Round 1..." >&2
    local gemini_choice=$(api_call_with_retry ask_gemini "$title" "$authors" "$description" "$categories_for_ai" "")
    echo "[DEBUG] Retour ask_gemini Round 1 : '$gemini_choice'" >&2
    
    # Obtenir la hiérarchie de la catégorie choisie
    local gemini_hierarchy=""
    if [ -n "$gemini_choice" ] && validate_category_exists "$gemini_choice"; then
        gemini_hierarchy=$(get_category_hierarchy "$gemini_choice")
        echo "Gemini choisit : $gemini_hierarchy (ID:$gemini_choice)"
        log_to_file "Round 1 - Gemini choisit : $gemini_hierarchy (ID:$gemini_choice)"
    else
        echo "Gemini : ❌ choix invalide ou erreur"
        log_to_file "Round 1 - Gemini : erreur ou choix invalide ($gemini_choice)"
        gemini_choice=""
    fi
    
    # Demander à Claude avec retry
    echo -n "   🟣 Claude analyse... "
    echo "[DEBUG] Appel ask_claude Round 1..." >&2
    local claude_choice=$(api_call_with_retry ask_claude "$title" "$authors" "$description" "$categories_for_ai" "")
    echo "[DEBUG] Retour ask_claude Round 1 : '$claude_choice'" >&2
    
    # Obtenir la hiérarchie
    local claude_hierarchy=""
    if [ -n "$claude_choice" ] && validate_category_exists "$claude_choice"; then
        claude_hierarchy=$(get_category_hierarchy "$claude_choice")
        echo "Claude choisit : $claude_hierarchy (ID:$claude_choice)"
        log_to_file "Round 1 - Claude choisit : $claude_hierarchy (ID:$claude_choice)"
    else
        echo "Claude : ❌ choix invalide ou erreur"
        log_to_file "Round 1 - Claude : erreur ou choix invalide ($claude_choice)"
        claude_choice=""
    fi
    
    # Comparer les choix
    echo "[DEBUG] Comparaison : gemini='$gemini_choice' vs claude='$claude_choice'" >&2
    
    # Vérifier le consensus immédiat
    if [ "$gemini_choice" = "$claude_choice" ] && [ -n "$gemini_choice" ]; then
        echo ""
        echo ""
        echo "✅ CONSENSUS IMMÉDIAT !"
        echo "══════════════════════════════════════════════════════════════════════════"
        echo "Les deux IA sont d'accord sur : $gemini_hierarchy"
        local final_choice="$gemini_choice"
        log_to_file "CONSENSUS IMMÉDIAT sur : $gemini_hierarchy (ID:$final_choice)"
    else
        # ROUND 2 - Débat entre les IAs
        echo ""
        echo ""
        echo "❌ DÉSACCORD INITIAL"
        echo ""
        echo "🔄 ROUND 2 - Débat et reconsidération"
        echo "──────────────────────────────────────────────────────────────────────"
        
        # Gemini reconsidère avec la suggestion de Claude
        if [ -n "$claude_choice" ]; then
            echo -n "   🔵 Gemini reconsidère avec la suggestion de Claude... "
            echo "[DEBUG] Appel ask_gemini Round 2 avec suggestion Claude=$claude_choice..." >&2
            local gemini_choice2=$(api_call_with_retry ask_gemini "$title" "$authors" "$description" "$categories_for_ai" "$claude_choice")
            echo "[DEBUG] Retour ask_gemini Round 2 : '$gemini_choice2'" >&2
            
            if [ -n "$gemini_choice2" ] && validate_category_exists "$gemini_choice2"; then
                local gemini_hierarchy2=$(get_category_hierarchy "$gemini_choice2")
                if [ "$gemini_choice2" != "$gemini_choice" ]; then
                    echo "Gemini CHANGE pour : $gemini_hierarchy2 (ID:$gemini_choice2)"
                    log_to_file "Round 2 - Gemini change pour : $gemini_hierarchy2 (ID:$gemini_choice2)"
                else
                    echo "Gemini MAINTIENT : $gemini_hierarchy"
                    log_to_file "Round 2 - Gemini maintient son choix"
                fi
                gemini_choice="$gemini_choice2"
            else
                echo "Gemini garde son choix initial"
            fi
        fi
        
        # Claude reconsidère avec la suggestion de Gemini
        if [ -n "$gemini_choice" ]; then
            echo -n "   🟣 Claude reconsidère avec la suggestion de Gemini... "
            echo "[DEBUG] Appel ask_claude Round 2 avec suggestion Gemini=$gemini_choice..." >&2
            local claude_choice2=$(api_call_with_retry ask_claude "$title" "$authors" "$description" "$categories_for_ai" "$gemini_choice")
            echo "[DEBUG] Retour ask_claude Round 2 : '$claude_choice2'" >&2
            
            if [ -n "$claude_choice2" ] && validate_category_exists "$claude_choice2"; then
                local claude_hierarchy2=$(get_category_hierarchy "$claude_choice2")
                if [ "$claude_choice2" != "$claude_choice" ]; then
                    echo "Claude CHANGE pour : $claude_hierarchy2 (ID:$claude_choice2)"
                    log_to_file "Round 2 - Claude change pour : $claude_hierarchy2 (ID:$claude_choice2)"
                else
                    echo "Claude MAINTIENT : $claude_hierarchy"
                    log_to_file "Round 2 - Claude maintient son choix"
                fi
                claude_choice="$claude_choice2"
            else
                echo "Claude garde son choix initial"
            fi
        fi
        
        # Vérifier le consensus après round 2
        echo "[DEBUG] Comparaison Round 2 : gemini='$gemini_choice' vs claude='$claude_choice'" >&2
        
        if [ "$gemini_choice" = "$claude_choice" ] && [ -n "$gemini_choice" ]; then
            echo ""
            echo ""
            echo "✅ CONSENSUS TROUVÉ APRÈS DÉBAT !"
            echo "══════════════════════════════════════════════════════════════════════════"
            echo "Les deux IA s'accordent finalement sur : $(get_category_hierarchy "$gemini_choice")"
            local final_choice="$gemini_choice"
            log_to_file "CONSENSUS APRÈS DÉBAT sur : $(get_category_hierarchy "$final_choice") (ID:$final_choice)"
        else
            # Pas de consensus - arbitrage nécessaire
            echo ""
            echo ""
            echo "⚠️  PAS DE CONSENSUS - ARBITRAGE NÉCESSAIRE"
            echo "══════════════════════════════════════════════════════════════════════════"
            
            # Logique d'arbitrage : privilégier le choix le plus spécifique ou Gemini par défaut
            if [ -n "$gemini_choice" ] && validate_category_exists "$gemini_choice"; then
                local final_choice="$gemini_choice"
                echo "Choix retenu : Proposition de Gemini"
                echo "→ $(get_category_hierarchy "$final_choice")"
                log_to_file "ARBITRAGE : Choix de Gemini retenu - $(get_category_hierarchy "$final_choice") (ID:$final_choice)"
            elif [ -n "$claude_choice" ] && validate_category_exists "$claude_choice"; then
                local final_choice="$claude_choice"
                echo "Choix retenu : Proposition de Claude"
                echo "→ $(get_category_hierarchy "$final_choice")"
                log_to_file "ARBITRAGE : Choix de Claude retenu - $(get_category_hierarchy "$final_choice") (ID:$final_choice)"
            else
                # Aucun choix valide - catégorie par défaut
                local final_choice="$DEFAULT_CATEGORY_ID"
                echo "❌ AUCUN CHOIX VALIDE - Catégorie par défaut"
                echo "→ $DEFAULT_CATEGORY_NAME"
                log_to_file "DÉFAUT : Aucun choix valide, catégorie par défaut - $DEFAULT_CATEGORY_NAME (ID:$final_choice)"
            fi
        fi
    fi
    
    # Afficher le choix final de manière claire
    echo "[DEBUG] Choix final : ID=$final_choice" >&2
    local final_hierarchy=$(get_category_hierarchy "$final_choice")
    echo ""
    echo ""
    echo "📌 CATÉGORIE FINALE RETENUE"
    echo "══════════════════════════════════════════════════════════════════════════"
    echo "   🏷️  $final_hierarchy"
    echo "   🔢 ID : $final_choice"
    echo ""
    
    # Afficher la progression
    display_analysis_progress 4 "Application de la catégorie..."
    
    # Appliquer la catégorie
    echo -n "💾 Mise à jour de la base de données... "
    
    # Récupérer le term_taxonomy_id
    echo "[DEBUG] Recherche term_taxonomy_id pour term_id=$final_choice..." >&2
    local term_taxonomy_id=$(safe_mysql "
        SELECT term_taxonomy_id 
        FROM wp_${SITE_ID}_term_taxonomy 
        WHERE term_id = '$final_choice' 
        AND taxonomy = 'product_cat'")
    
    echo "[DEBUG] term_taxonomy_id trouvé : '$term_taxonomy_id'" >&2
    
    if [ -n "$term_taxonomy_id" ]; then
        # Supprimer les anciennes catégories
        echo "[DEBUG] Suppression des anciennes catégories..." >&2
        safe_mysql "DELETE FROM wp_${SITE_ID}_term_relationships 
                   WHERE object_id = '$product_id' 
                   AND term_taxonomy_id IN (
                       SELECT term_taxonomy_id 
                       FROM wp_${SITE_ID}_term_taxonomy 
                       WHERE taxonomy = 'product_cat'
                   )"
        
        # Ajouter la nouvelle catégorie
        echo "[DEBUG] Ajout de la nouvelle catégorie term_taxonomy_id=$term_taxonomy_id..." >&2
        safe_mysql "INSERT INTO wp_${SITE_ID}_term_relationships 
                   (object_id, term_taxonomy_id) 
                   VALUES ('$product_id', '$term_taxonomy_id')
                   ON DUPLICATE KEY UPDATE term_taxonomy_id = '$term_taxonomy_id'"
        
        echo "✅ Catégorie appliquée avec succès !"
        
        # Stocker la catégorie Google Books comme référence si disponible
        if [ -n "$google_categories" ]; then
            echo "[DEBUG] Catégorie Google Books stockée pour référence : $google_categories" >&2
            safe_store_meta "$product_id" "_g_categorie_reference" "$google_categories"
        fi
        
        # Stocker des métadonnées sur la catégorisation
        safe_store_meta "$product_id" "_ai_category_id" "$final_choice"
        safe_store_meta "$product_id" "_ai_category_name" "$final_hierarchy"
        safe_store_meta "$product_id" "_ai_category_date" "$(date '+%Y-%m-%d %H:%M:%S')"
        safe_store_meta "$product_id" "_ai_category_consensus" "$([ "$gemini_choice" = "$claude_choice" ] && echo "yes" || echo "no")"
        
        log_to_file "Catégorisation terminée avec succès pour produit ID: $product_id"
    else
        echo "❌ ERREUR : Impossible d'appliquer la catégorie (term_taxonomy_id non trouvé)"
        log_to_file "ERREUR : term_taxonomy_id non trouvé pour term_id=$final_choice"
        return 1
    fi
    
    echo "[DEBUG] === FIN categorize_with_dual_ai ===" >&2
}

# Fonction pour afficher l'aide
show_help() {
    echo "Usage: $0 [OPTIONS] [ISBN ou ID]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help        Afficher cette aide"
    echo "  -v, --verbose     Mode verbose (affiche plus d'informations)"
    echo "  -q, --quiet       Mode silencieux (moins d'informations)"
    echo "  -d, --debug       Mode debug (affiche les prompts et réponses)"
    echo "  -id               Forcer l'interprétation comme ID produit"
    echo ""
    echo "EXEMPLES:"
    echo "  $0 9782070360024           # ISBN"
    echo "  $0 16091                   # ID produit"
    echo "  $0 -id 16091               # Forcer comme ID"
    echo "  $0 -d 9782070360024        # Mode debug"
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
#                            PROGRAMME PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════

# Effacer l'écran pour une présentation propre
clear

# Afficher l'en-tête du programme
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║             SMART CATEGORIZE - DUAL AI MODE v2.0                         ║"
echo "║          Gemini + Claude débattent pour trouver                         ║"
echo "║              la meilleure catégorie WordPress                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Traiter les options de ligne de commande
input=""
force_id=0

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -q|--quiet)
            VERBOSE=0
            shift
            ;;
        -d|--debug)
            SHOW_PROMPTS=1
            DEBUG=1
            shift
            ;;
        -id)
            force_id=1
            shift
            ;;
        *)
            input="$1"
            shift
            ;;
    esac
done

# Vérifier les clés API
verbose_log "🔐 Vérification des clés API..."
echo "[DEBUG] Vérification des clés API..." >&2
echo "[DEBUG] GEMINI_API_KEY : ${GEMINI_API_KEY:0:10}..." >&2
echo "[DEBUG] CLAUDE_API_KEY : ${CLAUDE_API_KEY:0:10}..." >&2

if [ -z "$GEMINI_API_KEY" ] || [ -z "$CLAUDE_API_KEY" ]; then
    echo "❌ ERREUR : Les clés API sont requises"
    echo ""
    echo "📝 Configuration requise dans config/credentials.sh :"
    echo ""
    echo "export GEMINI_API_KEY='votre-clé-gemini'"
    echo "export CLAUDE_API_KEY='votre-clé-claude'"
    echo ""
    echo "🔗 Obtenir les clés :"
    echo "   • Gemini : https://makersuite.google.com/app/apikey"
    echo "   • Claude : https://console.anthropic.com/api"
    echo ""
    exit 1
fi

verbose_log "✅ Clés API vérifiées"

# Si pas d'input fourni, demander
if [ -z "$input" ]; then
    # Afficher quelques catégories disponibles
    display_available_categories
    
    echo "📝 ENTRÉE REQUISE"
    echo "════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Vous pouvez entrer :"
    echo "  • Un ISBN (10 ou 13 chiffres) : 9782070360024"
    echo "  • Un ID de produit WordPress : 16091"
    echo ""
    read -p "ISBN ou ID produit : " input
fi

echo "[DEBUG] Input reçu : '$input'" >&2

# Nettoyer l'input (enlever tirets, espaces)
input=$(echo "$input" | tr -d '-' | tr -d ' ')
echo "[DEBUG] Input nettoyé : '$input'" >&2

# Déterminer si c'est un ID ou un ISBN
if [ $force_id -eq 1 ] || [[ "$input" =~ ^[0-9]{1,6}$ ]]; then
    echo "[DEBUG] Input reconnu comme ID produit" >&2
    product_id="$input"
    
    # Récupérer l'ISBN correspondant
    isbn=$(safe_get_meta "$product_id" "_isbn")
    
    if [ -z "$isbn" ]; then
        echo ""
        echo "❌ ERREUR : Aucun livre trouvé avec l'ID $product_id"
        echo ""
        echo "Vérifiez que :"
        echo "  • L'ID existe dans WordPress"
        echo "  • C'est bien un produit de type 'product'"
        echo "  • Il a un ISBN défini dans _isbn"
        echo ""
        exit 1
    fi
    
elif [[ "$input" =~ ^[0-9]{10}$ ]] || [[ "$input" =~ ^[0-9]{13}$ ]]; then
    echo "[DEBUG] Input reconnu comme ISBN" >&2
    isbn="$input"
    
    echo "[DEBUG] Recherche par ISBN : '$isbn'" >&2
    
    # Trouver l'ID produit correspondant
    product_id=$(safe_mysql "
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key = '_isbn' AND meta_value = '$isbn' 
        LIMIT 1")
    
    echo "[DEBUG] Post ID trouvé : '$product_id'" >&2
    
    if [ -z "$product_id" ]; then
        echo ""
        echo "❌ ERREUR : Aucun livre trouvé avec l'ISBN $isbn"
        echo ""
        echo "Suggestions :"
        echo "  1. Vérifiez l'ISBN"
        echo "  2. Ajoutez d'abord le livre avec : ./add_book_minimal.sh $isbn"
        echo "  3. Ou utilisez l'ID du produit si vous le connaissez"
        echo ""
        exit 1
    fi
else
    echo ""
    echo "❌ ERREUR : Format invalide"
    echo ""
    echo "Formats acceptés :"
    echo "  • ISBN-10 : 2070360024"
    echo "  • ISBN-13 : 9782070360024"
    echo "  • ID produit : 16091"
    echo ""
    echo "Les tirets et espaces sont ignorés automatiquement."
    echo ""
    exit 1
fi

# Afficher ce qu'on a trouvé
echo ""
echo "✅ LIVRE TROUVÉ"
echo "════════════════════════════════════════════════════════════════════════════"
echo "   📗 ID Produit : #$product_id"
echo "   📘 ISBN : $isbn"
echo ""

# Lancer la catégorisation
categorize_with_dual_ai "$product_id"

# Afficher les informations finales
echo ""
echo "📊 INFORMATIONS COMPLÉMENTAIRES"
echo "════════════════════════════════════════════════════════════════════════════"
echo "   📁 Logs détaillés : $LOG_DIR/dual_ai_categorize.log"
echo "   ⏱️  Heure de fin : $(date '+%H:%M:%S')"
echo ""

# Message de fin
echo "✨ Catégorisation terminée avec succès !"
echo ""