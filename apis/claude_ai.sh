#!/bin/bash
echo "[START: claude_ai.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# API Claude AI pour génération de descriptions

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

generate_description_claude() {
    local isbn=$1
    local product_id=$2
    local title=$3
    local authors=$4
    local publisher=$5
    local pages=$6
    local binding=$7
    local categories=$8
    
    # Vérifier la clé API
    if [ -z "$CLAUDE_API_KEY" ]; then
        echo "[DEBUG] Claude API key manquante" >&2
        return 1
    fi
    
    echo "[DEBUG] Appel Claude AI pour ISBN $isbn..." >&2
    
    # Préparer le prompt
    local prompt="Tu es un expert en littérature française spécialisé dans la vente de livres d'occasion. Génère une description de vente attrayante et informative pour ce livre :

Titre: $title
Auteur(s): $authors
Éditeur: $publisher
Pages: $pages
Format: $binding
Catégories: $categories
ISBN: $isbn

Instructions importantes :
- Description en français de 200-300 mots
- Commence par un résumé captivant du contenu
- Mentionne les thèmes principaux et l'intérêt du livre
- Inclus des informations sur l'auteur si pertinent
- Adapte le ton selon le genre (sérieux pour académique, engageant pour fiction)
- Termine par une phrase sur l'état du livre d'occasion
- Ne pas inclure de prix ou d'informations commerciales
- Reste factuel tout en étant vendeur

Génère uniquement la description, sans titre ni introduction."

    # Échapper le prompt pour JSON
    local prompt_escaped=$(echo "$prompt" | sed 's/"/\\"/g' | tr '\n' ' ')
    
    # Construire la requête JSON
    local json_request='{
        "model": "claude-3-haiku-20240307",
        "max_tokens": 1024,
        "messages": [{
            "role": "user",
            "content": "'"$prompt_escaped"'"
        }],
        "temperature": 0.7
    }'
    
    echo "[DEBUG] Envoi requête à Claude API..." >&2
    
    # Appel API Claude
    local claude_response=$(curl -s -X POST https://api.anthropic.com/v1/messages \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "$json_request" 2>&1)
    
    local curl_status=$?
    
    echo "[DEBUG] Statut curl: $curl_status" >&2
    
    if [ $curl_status -ne 0 ]; then
        echo "[DEBUG] Erreur curl: $claude_response" >&2
        return 1
    fi
    
    # Vérifier la réponse
    if [ -z "$claude_response" ]; then
        echo "[DEBUG] Réponse vide de Claude" >&2
        return 1
    fi
    
    echo "[DEBUG] Réponse reçue, extraction du contenu..." >&2
    
    # Extraire la description
    local claude_desc=$(echo "$claude_response" | jq -r '.content[0].text' 2>/dev/null)
    
    # Vérifier les erreurs
    if [ -z "$claude_desc" ] || [ "$claude_desc" = "null" ]; then
        local error_type=$(echo "$claude_response" | jq -r '.error.type' 2>/dev/null)
        local error_msg=$(echo "$claude_response" | jq -r '.error.message' 2>/dev/null)
        
        if [ -n "$error_type" ] && [ "$error_type" != "null" ]; then
            echo "[DEBUG] Erreur Claude: $error_type - $error_msg" >&2
            
            # Gestion spécifique des erreurs
            case "$error_type" in
                "authentication_error")
                    echo "❌ ERREUR CRITIQUE : Clé API Claude invalide" >&2
                    echo "   Vérifiez CLAUDE_API_KEY dans config/credentials.sh" >&2
                    ;;
                "rate_limit_error")
                    echo "❌ ERREUR : Limite de taux Claude atteinte" >&2
                    echo "   Attendez quelques minutes avant de réessayer" >&2
                    ;;
                "invalid_request_error")
                    echo "❌ ERREUR : Requête invalide" >&2
                    echo "   Vérifiez les données envoyées" >&2
                    ;;
                *)
                    echo "❌ ERREUR Claude : $error_type" >&2
                    ;;
            esac
        else
            echo "[DEBUG] Impossible d'extraire la description" >&2
            echo "[DEBUG] Réponse brute: ${claude_response:0:200}..." >&2
        fi
        return 1
    fi
    
    # Vérifier la longueur
    if [ ${#claude_desc} -lt 50 ]; then
        echo "[DEBUG] Description trop courte: ${#claude_desc} caractères" >&2
        return 1
    fi
    
    echo "[DEBUG] Description générée avec succès: ${#claude_desc} caractères" >&2
    
    # Stocker la description
    safe_store_meta "$product_id" "_claude_description" "$claude_desc"
    safe_store_meta "$product_id" "_description_source" "claude_ai"
    safe_store_meta "$product_id" "_description_date" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Retourner la description
    echo "$claude_desc"
    return 0
}

# Fonction pour tester la connexion Claude
test_claude_connection() {
    if [ -z "$CLAUDE_API_KEY" ]; then
        echo "❌ Clé API Claude non configurée"
        return 1
    fi
    
    echo "Test de connexion à Claude AI..."
    
    local test_response=$(curl -s -X POST https://api.anthropic.com/v1/messages \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d '{
            "model": "claude-3-haiku-20240307",
            "max_tokens": 10,
            "messages": [{
                "role": "user",
                "content": "Réponds juste OK"
            }]
        }' 2>&1)
    
    if echo "$test_response" | grep -q '"type":"message"'; then
        echo "✅ Connexion Claude AI OK"
        return 0
    else
        local error=$(echo "$test_response" | jq -r '.error.message' 2>/dev/null)
        echo "❌ Erreur Claude : ${error:-Connexion impossible}"
        return 1
    fi
}

# Export des fonctions
export -f generate_description_claude
export -f test_claude_connection

echo "[END: claude_ai.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
