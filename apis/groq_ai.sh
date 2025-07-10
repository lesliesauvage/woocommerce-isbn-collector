#!/bin/bash
echo "[START: groq_ai.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# API Groq IA

# Source des dépendances
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"  # Fonctions sécurisées
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"

generate_description_groq() {
    local isbn=$1
    local product_id=$2
    local title=$3
    local authors=$4
    local publisher=$5
    local pages=$6
    local binding=$7
    local categories=$8
    
    if [ -z "$GROQ_API_KEY" ]; then
        return 1
    fi
    
    sleep 0.5
    log "  → Groq IA (génération gratuite)..."
    
    # Préparer le prompt pour Groq
    local prompt="Tu es un expert en littérature française. Génère une description de vente attrayante pour ce livre d'occasion:

Titre: $title
Auteur: $authors
Éditeur: $publisher
Pages: $pages
Format: $binding
Catégories: $categories
ISBN: $isbn

Instructions:
- Description en français de 150-200 mots
- Mentionne le contenu probable du livre
- Reste factuel mais engageant
- Adapte le ton selon le type de livre
- Mentionne que c'est un livre d'occasion en bon état

Génère uniquement la description, sans introduction ni conclusion."

    # Appel API Groq avec llama3-70b
    local groq_response=$(curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "llama3-70b-8192",
            "messages": [{
                "role": "user",
                "content": "'"$(echo "$prompt" | sed 's/"/\\"/g' | tr '\n' ' ')"'"
            }],
            "temperature": 0.7,
            "max_tokens": 400
        }' 2>/dev/null)
    
    ((api_calls_groq++))
    export api_calls_groq
    
    # Extraire la description
    local groq_desc=$(echo "$groq_response" | jq -r '.choices[0].message.content' 2>/dev/null)
    
    if [ -n "$groq_desc" ] && [ "$groq_desc" != "null" ] && [ ${#groq_desc} -gt 30 ]; then
        log "    ✓ Groq IA : description générée"
        safe_store_meta "$product_id" "_groq_description" "$groq_desc"
        echo "$groq_desc"
        return 0
    else
        # En cas d'erreur, afficher le message
        local error_msg=$(echo "$groq_response" | jq -r '.error.message' 2>/dev/null)
        if [ -n "$error_msg" ] && [ "$error_msg" != "null" ]; then
            log "    ✗ Groq IA : Erreur - $error_msg"
        else
            log "    ✗ Groq IA : pas de description générée"
        fi
        return 1
    fi
}

echo "[END: groq_ai.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
