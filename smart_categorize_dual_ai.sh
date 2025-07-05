#!/bin/bash
# ⚠️  FICHIER CRITIQUE - NE JAMAIS SUPPRIMER ⚠️
# smart_categorize_dual_ai.sh - Double IA qui débattent pour catégoriser

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

# Obtenir toutes les catégories disponibles
get_all_categories() {
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT CONCAT('ID:', t.term_id, ' - ', t.name) 
    FROM wp_${SITE_ID}_terms t
    JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
    WHERE tt.taxonomy = 'product_cat'
    AND t.term_id NOT IN (15, 16)
    ORDER BY t.name
    " 2>/dev/null
}

# Demander à Gemini
ask_gemini() {
    local title="$1"
    local authors="$2"
    local description="$3"
    local categories_list="$4"
    local previous_claude_response="${5:-}"
    
    # Préparer le prompt
    local prompt="Tu dois catégoriser ce livre dans LA catégorie la plus appropriée.

LIVRE À CATÉGORISER:
Titre: $title
Auteurs: $authors
Description: $(echo "$description" | cut -c1-500)

CATÉGORIES DISPONIBLES:
$categories_list

INSTRUCTION IMPORTANTE:
- Choisis UNE SEULE catégorie, la plus pertinente
- Réponds UNIQUEMENT avec l'ID numérique (ex: 245)
- Pas de texte, juste le nombre"

    # Si Claude a déjà répondu
    if [ -n "$previous_claude_response" ]; then
        prompt="$prompt

Note: Claude a suggéré la catégorie ID:$previous_claude_response
Es-tu d'accord ? Si oui réponds le même ID, sinon donne ton choix."
    fi

    # Échapper pour JSON
    local prompt_escaped=$(echo "$prompt" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    # Appel à Gemini
    local response=$(curl -s -X POST "${GEMINI_API_URL}?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"contents\": [{
                \"parts\": [{
                    \"text\": \"$prompt_escaped\"
                }]
            }],
            \"generationConfig\": {
                \"temperature\": 0.3,
                \"maxOutputTokens\": 10
            }
        }" 2>/dev/null)
    
    # Extraire la réponse
    echo "$response" | grep -o '"text":"[^"]*"' | sed 's/"text":"//;s/"//' | grep -o '[0-9]\+' | head -1
}

# Demander à Claude
ask_claude() {
    local title="$1"
    local authors="$2"
    local description="$3"
    local categories_list="$4"
    local previous_gemini_response="${5:-}"
    
    # Préparer le prompt
    local prompt="Tu dois catégoriser ce livre dans LA catégorie la plus appropriée.

LIVRE À CATÉGORISER:
Titre: $title
Auteurs: $authors
Description: $(echo "$description" | cut -c1-500)

CATÉGORIES DISPONIBLES:
$categories_list

INSTRUCTION IMPORTANTE:
- Choisis UNE SEULE catégorie, la plus pertinente
- Réponds UNIQUEMENT avec l'ID numérique (ex: 245)
- Pas de texte, juste le nombre"

    # Si Gemini a déjà répondu
    if [ -n "$previous_gemini_response" ]; then
        prompt="$prompt

Note: Gemini a suggéré la catégorie ID:$previous_gemini_response
Es-tu d'accord ? Si oui réponds le même ID, sinon donne ton choix."
    fi

    # Échapper pour JSON
    local prompt_escaped=$(echo "$prompt" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    # Appel à Claude
    local response=$(curl -s -X POST "$CLAUDE_API_URL" \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d "{
            \"model\": \"claude-3-haiku-20240307\",
            \"messages\": [{
                \"role\": \"user\",
                \"content\": \"$prompt_escaped\"
            }],
            \"max_tokens\": 10
        }" 2>/dev/null)
    
    # Extraire la réponse
    echo "$response" | grep -o '"text":"[^"]*"' | sed 's/"text":"//;s/"//' | grep -o '[0-9]\+' | head -1
}

# Fonction principale de catégorisation
categorize_with_dual_ai() {
    local post_id="$1"
    
    # Récupérer les infos du livre
    local book_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT 
        p.post_title,
        IFNULL(pm_isbn.meta_value, '') as isbn,
        IFNULL(pm_authors.meta_value, '') as authors,
        IFNULL(pm_desc.meta_value, '') as description
    FROM wp_${SITE_ID}_posts p
    LEFT JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
    WHERE p.ID = $post_id
    " 2>/dev/null)
    
    if [ -z "$book_info" ]; then
        echo "❌ Livre ID $post_id non trouvé"
        return 1
    fi
    
    # Parser les infos
    IFS=$'\t' read -r title isbn authors description <<< "$book_info"
    
    echo ""
    echo "📚 LIVRE : $title"
    echo "   ISBN : ${isbn:-N/A}"
    echo "   Auteurs : ${authors:-N/A}"
    echo ""
    
    # Obtenir la liste des catégories
    echo "📋 Récupération des catégories..."
    local categories_list=$(get_all_categories)
    local cat_count=$(echo "$categories_list" | wc -l)
    echo "   $cat_count catégories disponibles"
    
    # Premier round : demander aux deux IA
    echo ""
    echo "🤖 ROUND 1 - Première analyse..."
    
    echo -n "   Gemini analyse... "
    local gemini_choice_1=$(ask_gemini "$title" "$authors" "$description" "$categories_list")
    echo "Choix: ID:$gemini_choice_1"
    
    echo -n "   Claude analyse... "
    local claude_choice_1=$(ask_claude "$title" "$authors" "$description" "$categories_list")
    echo "Choix: ID:$claude_choice_1"
    
    # Vérifier si accord
    if [ "$gemini_choice_1" = "$claude_choice_1" ]; then
        echo ""
        echo "✅ ACCORD IMMÉDIAT ! Catégorie ID:$gemini_choice_1"
        local final_choice=$gemini_choice_1
    else
        # Désaccord - Round 2
        echo ""
        echo "❌ DÉSACCORD ! Round 2..."
        
        echo -n "   Gemini reconsidère (sachant que Claude propose ID:$claude_choice_1)... "
        local gemini_choice_2=$(ask_gemini "$title" "$authors" "$description" "$categories_list" "$claude_choice_1")
        echo "Nouveau choix: ID:$gemini_choice_2"
        
        echo -n "   Claude reconsidère (sachant que Gemini propose ID:$gemini_choice_1)... "
        local claude_choice_2=$(ask_claude "$title" "$authors" "$description" "$categories_list" "$gemini_choice_1")
        echo "Nouveau choix: ID:$claude_choice_2"
        
        # Résultat final
        if [ "$gemini_choice_2" = "$claude_choice_2" ]; then
            echo ""
            echo "✅ CONSENSUS TROUVÉ ! Catégorie ID:$gemini_choice_2"
            local final_choice=$gemini_choice_2
        else
            echo ""
            echo "⚠️  PAS DE CONSENSUS"
            echo "   Choix final de Gemini : ID:$gemini_choice_2"
            echo "   Choix final de Claude : ID:$claude_choice_2"
            # En cas de désaccord persistant, prendre Gemini (ou Claude selon préférence)
            local final_choice=$claude_choice_2
            echo "   → Choix retenu : ID:$final_choice (Claude)"
        fi
    fi
    
    # Récupérer le nom de la catégorie
    local category_name=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT name FROM wp_${SITE_ID}_terms WHERE term_id = $final_choice
    " 2>/dev/null)
    
    echo ""
    echo "📌 CATÉGORIE FINALE : $category_name (ID:$final_choice)"
    
    # Appliquer la catégorie
    echo -n "💾 Application... "
    
    # Obtenir le term_taxonomy_id
    local term_taxonomy_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
    WHERE term_id = $final_choice AND taxonomy = 'product_cat'
    " 2>/dev/null)
    
    # Supprimer anciennes catégories
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    DELETE FROM wp_${SITE_ID}_term_relationships 
    WHERE object_id = $post_id 
    AND term_taxonomy_id IN (
        SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
        WHERE taxonomy = 'product_cat'
    )
    " 2>/dev/null
    
    # Ajouter nouvelle catégorie
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    INSERT IGNORE INTO wp_${SITE_ID}_term_relationships (object_id, term_taxonomy_id)
    VALUES ($post_id, $term_taxonomy_id)
    " 2>/dev/null
    
    echo "✅ Fait!"
    
    # Log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ID:$post_id - $title → $category_name (Gemini:$gemini_choice_1→$gemini_choice_2, Claude:$claude_choice_1→$claude_choice_2)" >> logs/dual_ai_categorize.log
}

# Programme principal
clear
echo "=== SMART CATEGORIZE - DUAL AI MODE ==="
echo "Gemini + Claude débattent pour trouver la meilleure catégorie"
echo "════════════════════════════════════════════════════"

# Vérifier les clés
if [ -z "$GEMINI_API_KEY" ] || [ -z "$CLAUDE_API_KEY" ]; then
    echo "❌ ERREUR : Les deux clés API sont requises"
    echo "Lancez : ./setup_dual_ai.sh"
    exit 1
fi

# Menu
if [ -z "$1" ]; then
    echo ""
    echo "Usage :"
    echo "  ./smart_categorize_dual_ai.sh ISBN"
    echo "  ./smart_categorize_dual_ai.sh -id ID"
    echo "  ./smart_categorize_dual_ai.sh -batch N"
    echo ""
    echo -n "ISBN ou ID du livre : "
    read input
else
    input="$1"
fi

# Traiter l'input
case "$input" in
    -id)
        categorize_with_dual_ai "$2"
        ;;
    -batch)
        limit="${2:-5}"
        echo "Catégorisation de $limit livres..."
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
            categorize_with_dual_ai "$post_id"
            echo "════════════════════════════════════════════════════"
            sleep 2  # Pause entre chaque livre
        done
        ;;
    *)
        # Chercher par ISBN
        post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key = '_isbn' AND meta_value = '$input'
        LIMIT 1
        " 2>/dev/null)
        
        if [ -n "$post_id" ]; then
            categorize_with_dual_ai "$post_id"
        else
            echo "❌ ISBN '$input' non trouvé"
        fi
        ;;
esac

echo ""
echo "📊 Logs : logs/dual_ai_categorize.log"
