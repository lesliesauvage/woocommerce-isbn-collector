#!/bin/bash
echo "[START: commercial_description.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2

# Générer une description commerciale qui fait vendre
generate_commercial_description() {
    local post_id="$1"
    local isbn="$2"
    
    echo "[DEBUG] Génération description commerciale pour #$post_id" >&2
    
    # Récupérer les données du livre
    local title=$(get_meta_value "$post_id" "_best_title")
    local authors=$(get_meta_value "$post_id" "_best_authors")
    local publisher=$(get_meta_value "$post_id" "_best_publisher")
    local pages=$(get_meta_value "$post_id" "_best_pages")
    local binding=$(get_meta_value "$post_id" "_best_binding")
    local language=$(get_meta_value "$post_id" "_g_language")
    local pub_date=$(get_meta_value "$post_id" "_g_publishedDate")
    local categories=$(get_meta_value "$post_id" "_g_categories")
    local subjects=$(get_meta_value "$post_id" "_o_subjects")
    
    # Description actuelle (factuelle)
    local current_desc=$(get_meta_value "$post_id" "_best_description")
    
    # Si pas de description de base, arrêter
    if [ -z "$current_desc" ] || [ ${#current_desc} -lt 20 ]; then
        echo "[ERROR] Pas de description de base pour générer la version commerciale" >&2
        return 1
    fi
    
    # Préparer le prompt pour Claude
    local prompt="Tu es un expert en vente de livres d'occasion. Crée une description commerciale qui fait vendre ce livre.

INFORMATIONS DU LIVRE :
Titre : $title
Auteurs : $authors
Éditeur : $publisher
Pages : $pages
Format : $binding
Langue : $language
Année : $pub_date
Catégories : $categories
Sujets : $subjects

DESCRIPTION ACTUELLE (factuelle) :
$current_desc

INSTRUCTIONS :
1. Commence par une phrase d'accroche qui capte l'attention
2. Mets en valeur les points forts du livre :
   - L'expertise/réputation de l'auteur
   - L'importance du sujet traité
   - La qualité éditoriale
   - L'intérêt pour le lecteur
3. Utilise des mots qui déclenchent l'émotion et l'envie
4. Termine par un appel à l'action subtil
5. Maximum 300 mots, style fluide et engageant
6. Évite les superlatifs excessifs, reste crédible

Écris UNIQUEMENT la description commerciale, sans commentaires."

    # Appeler Claude
    local api_response=$(curl -s -X POST "$CLAUDE_API_URL" \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "{
            \"model\": \"claude-3-haiku-20240307\",
            \"messages\": [{
                \"role\": \"user\",
                \"content\": $(echo "$prompt" | jq -Rs .)
            }],
            \"max_tokens\": 500
        }" 2>&1)
    
    # Vérifier les erreurs
    if echo "$api_response" | grep -q '"error"'; then
        echo "[ERROR] Erreur Claude API : $api_response" >&2
        return 1
    fi
    
    # Extraire la description
    local commercial_desc=$(echo "$api_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['content'][0]['text'].strip())
except:
    pass" 2>/dev/null)
    
    if [ -n "$commercial_desc" ] && [ ${#commercial_desc} -gt 50 ]; then
        # Sauvegarder la description commerciale
        safe_store_meta "$post_id" "_commercial_description" "$commercial_desc"
        safe_store_meta "$post_id" "_commercial_description_date" "$(date '+%Y-%m-%d %H:%M:%S')"
        
        # Mettre à jour la description principale avec la version commerciale
        safe_store_meta "$post_id" "_best_description" "$commercial_desc"
        safe_store_meta "$post_id" "_best_description_source" "claude_commercial"
        
        echo "[SUCCESS] Description commerciale générée (${#commercial_desc} caractères)" >&2
        return 0
    else
        echo "[ERROR] Description commerciale trop courte ou vide" >&2
        return 1
    fi
}

# Fonction pour enrichir la description de base si elle manque
ensure_base_description() {
    local post_id="$1"
    local isbn="$2"
    
    # Vérifier si on a déjà une description
    local current_desc=$(get_meta_value "$post_id" "_best_description")
    if [ -n "$current_desc" ] && [ ${#current_desc} -gt 50 ]; then
        echo "[DEBUG] Description existante suffisante" >&2
        return 0
    fi
    
    echo "[INFO] Génération description de base nécessaire" >&2
    
    # Récupérer les données
    local title=$(get_meta_value "$post_id" "_best_title")
    local authors=$(get_meta_value "$post_id" "_best_authors")
    local publisher=$(get_meta_value "$post_id" "_best_publisher")
    local pages=$(get_meta_value "$post_id" "_best_pages")
    local categories=$(get_meta_value "$post_id" "_g_categories")
    local subjects=$(get_meta_value "$post_id" "_o_subjects")
    
    # Prompt pour description de base
    local prompt="Génère une description factuelle pour ce livre :

Titre : $title
Auteurs : $authors
Éditeur : $publisher
Pages : $pages
Catégories : $categories
Sujets : $subjects

Écris une description de 150-200 mots qui :
- Présente le contenu du livre
- Explique les thèmes abordés
- Mentionne le public cible
- Reste factuelle et informative

Réponds UNIQUEMENT avec la description."

    # Essayer Groq d'abord (plus économique)
    if [ -n "$GROQ_API_KEY" ]; then
        local groq_response=$(curl -s -X POST "https://api.groq.com/openai/v1/chat/completions" \
            -H "Authorization: Bearer $GROQ_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{
                \"model\": \"mixtral-8x7b-32768\",
                \"messages\": [{\"role\": \"user\", \"content\": $(echo "$prompt" | jq -Rs .)}],
                \"max_tokens\": 300,
                \"temperature\": 0.7
            }" 2>&1)
        
        local base_desc=$(echo "$groq_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'].strip())
except:
    pass" 2>/dev/null)
        
        if [ -n "$base_desc" ] && [ ${#base_desc} -gt 50 ]; then
            safe_store_meta "$post_id" "_best_description" "$base_desc"
            safe_store_meta "$post_id" "_best_description_source" "groq_ai"
            safe_store_meta "$post_id" "_groq_description" "$base_desc"
            echo "[SUCCESS] Description de base générée par Groq" >&2
            return 0
        fi
    fi
    
    # Si Groq échoue, essayer Claude
    if [ -n "$CLAUDE_API_KEY" ]; then
        local claude_response=$(curl -s -X POST "$CLAUDE_API_URL" \
            -H "x-api-key: $CLAUDE_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "{
                \"model\": \"claude-3-haiku-20240307\",
                \"messages\": [{\"role\": \"user\", \"content\": $(echo "$prompt" | jq -Rs .)}],
                \"max_tokens\": 300
            }" 2>&1)
        
        local base_desc=$(echo "$claude_response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['content'][0]['text'].strip())
except:
    pass" 2>/dev/null)
        
        if [ -n "$base_desc" ] && [ ${#base_desc} -gt 50 ]; then
            safe_store_meta "$post_id" "_best_description" "$base_desc"
            safe_store_meta "$post_id" "_best_description_source" "claude_ai"
            safe_store_meta "$post_id" "_claude_description" "$base_desc"
            echo "[SUCCESS] Description de base générée par Claude" >&2
            return 0
        fi
    fi
    
    # Dernière option : description générique
    local generic_desc="$title est un ouvrage de $authors publié par $publisher. "
    generic_desc+="Ce livre de $pages pages explore les thèmes suivants : ${categories:-littérature}. "
    generic_desc+="Un livre incontournable pour tous ceux qui s'intéressent à ce domaine."
    
    safe_store_meta "$post_id" "_best_description" "$generic_desc"
    safe_store_meta "$post_id" "_best_description_source" "generic"
    echo "[WARNING] Description générique utilisée" >&2
    return 0
}

echo "[END: commercial_description.sh] $(date '+%Y-%m-%d %H:%M:%S')" >&2
