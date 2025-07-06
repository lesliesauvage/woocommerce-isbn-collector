#!/bin/bash
# ⚠️  FICHIER CRITIQUE - NE JAMAIS SUPPRIMER ⚠️
# smart_categorize_dual_ai.sh - Double IA qui débattent pour catégoriser

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

# Mode debug
SHOW_PROMPTS="1"  # FORCÉ EN DEBUG

# Obtenir toutes les catégories finales disponibles
get_all_categories() {
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT CONCAT('ID:', t.term_id, ' - ', t.name) 
    FROM wp_${SITE_ID}_terms t
    JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
    WHERE tt.taxonomy = 'product_cat'
    AND t.term_id NOT IN (15, 16)
    AND NOT EXISTS (
        SELECT 1 FROM wp_${SITE_ID}_term_taxonomy tt2 
        WHERE tt2.parent = t.term_id 
        AND tt2.taxonomy = 'product_cat'
    )
    ORDER BY t.name
    " 2>/dev/null
}

# Obtenir la hiérarchie complète d'une catégorie
get_category_with_parent() {
    local cat_id=$1
    [ -z "$cat_id" ] && return
    
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
    
    get_full_path $cat_id
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

    # Afficher le prompt si DEBUG
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📤 PROMPT ENVOYÉ À GEMINI :"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$prompt"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
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
    
    # DEBUG : afficher la réponse brute
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo "📥 RÉPONSE GEMINI (brute) :"
        echo "$response" | python3 -m json.tool 2>/dev/null | head -20 || echo "$response" | head -100
        echo ""
    fi
    
    # Extraire la réponse avec une méthode robuste
    local extracted_id=""
    
    # Méthode 1 : Python
    extracted_id=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    text = data['candidates'][0]['content']['parts'][0]['text']
    # Extraire les chiffres
    import re
    numbers = re.findall(r'\d+', text)
    if numbers:
        print(numbers[0])
except:
    pass
" 2>/dev/null)
    
    # Méthode 2 : Si Python échoue, utiliser sed
    if [ -z "$extracted_id" ]; then
        extracted_id=$(echo "$response" | grep -o '"text":"[^"]*"' | sed 's/"text":"//;s/"//' | grep -o '[0-9]\+' | head -1)
    fi
    
    if [ "$SHOW_PROMPTS" = "1" ] && [ -n "$extracted_id" ]; then
        echo "🔢 ID extrait de Gemini : $extracted_id"
        echo ""
    fi
    
    echo "$extracted_id"
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

    # Afficher le prompt si DEBUG
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📤 PROMPT ENVOYÉ À CLAUDE :"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "$prompt"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
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
            \"max_tokens\": 20
        }" 2>/dev/null)
    
    # DEBUG : afficher la réponse brute
    if [ "$SHOW_PROMPTS" = "1" ]; then
        echo "📥 RÉPONSE CLAUDE (brute) :"
        echo "$response" | python3 -m json.tool 2>/dev/null | head -20 || echo "$response" | head -100
        echo ""
    fi
    
    # Extraire la réponse
    local extracted_id=""
    
    # Méthode 1 : Python
    local claude_text=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['content'][0]['text'])
except:
    pass
" 2>/dev/null)
    
    # Si Claude dit qu'il est d'accord, prendre la suggestion
    if echo "$claude_text" | grep -qi "accord\|agree"; then
        extracted_id="$previous_gemini_response"
    else
        # Extraire les chiffres
        extracted_id=$(echo "$claude_text" | grep -o '[0-9]\+' | head -1)
    fi
    
    # Méthode 2 : Si extraction échoue
    if [ -z "$extracted_id" ]; then
        extracted_id=$(echo "$response" | grep -o '"text":"[^"]*"' | sed 's/"text":"//;s/"//' | grep -o '[0-9]\+' | head -1)
    fi
    
    if [ "$SHOW_PROMPTS" = "1" ] && [ -n "$extracted_id" ]; then
        echo "🔢 ID extrait de Claude : $extracted_id"
        echo ""
    fi
    
    echo "$extracted_id"
}

# Fonction principale de catégorisation
categorize_with_dual_ai() {
    local post_id="$1"
    
    # Récupérer les infos du livre
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
    
    # Afficher la description
    if [ -n "$description" ] && [ "$description" != "NULL" ]; then
        echo "   Description : $(echo "$description" | sed 's/<[^>]*>//g' | cut -c1-150)..."
    else
        echo "   Description : Non disponible"
    fi
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
    if [ -n "$gemini_choice_1" ]; then
        local gemini_cat_1=$(get_category_with_parent "$gemini_choice_1")
        echo "Gemini choisit : $gemini_cat_1"
    else
        echo "Gemini ne répond pas !"
        return 1
    fi
    
    echo -n "   Claude analyse... "
    local claude_choice_1=$(ask_claude "$title" "$authors" "$description" "$categories_list")
    if [ -n "$claude_choice_1" ]; then
        local claude_cat_1=$(get_category_with_parent "$claude_choice_1")
        echo "Claude choisit : $claude_cat_1"
    else
        echo "Claude ne répond pas !"
        return 1
    fi
    
    # Vérifier si accord
    if [ "$gemini_choice_1" = "$claude_choice_1" ]; then
        echo ""
        echo "✅ ACCORD IMMÉDIAT sur : $gemini_cat_1"
        local final_choice=$gemini_choice_1
    else
        # Désaccord - Round 2
        echo ""
        echo "❌ DÉSACCORD ! Round 2..."
        
        echo -n "   Gemini reconsidère... "
        local gemini_choice_2=$(ask_gemini "$title" "$authors" "$description" "$categories_list" "$claude_choice_1")
        if [ -n "$gemini_choice_2" ]; then
            local gemini_cat_2=$(get_category_with_parent "$gemini_choice_2")
            echo "Gemini change pour : $gemini_cat_2"
        else
            echo "Gemini ne change pas d'avis"
            gemini_choice_2=$gemini_choice_1
            gemini_cat_2=$gemini_cat_1
        fi
        
        echo -n "   Claude reconsidère... "
        local claude_choice_2=$(ask_claude "$title" "$authors" "$description" "$categories_list" "$gemini_choice_1")
        if [ -n "$claude_choice_2" ]; then
            local claude_cat_2=$(get_category_with_parent "$claude_choice_2")
            echo "Claude change pour : $claude_cat_2"
        else
            echo "Claude ne change pas d'avis"
            claude_choice_2=$claude_choice_1
            claude_cat_2=$claude_cat_1
        fi
        
        # Résultat final
        if [ "$gemini_choice_2" = "$claude_choice_2" ]; then
            echo ""
            echo "✅ CONSENSUS TROUVÉ sur : $gemini_cat_2"
            local final_choice=$gemini_choice_2
        else
            echo ""
            echo "⚠️  PAS DE CONSENSUS"
            echo "   Choix final de Gemini : $gemini_cat_2"
            echo "   Choix final de Claude : $claude_cat_2"
            # En cas de désaccord persistant, prendre Claude
            local final_choice=$claude_choice_2
            echo "   → Choix retenu : $claude_cat_2 (Claude)"
        fi
    fi
    
    # Récupérer le nom complet de la catégorie finale
    local final_cat_name=$(get_category_with_parent "$final_choice")
    
    echo ""
    echo "📌 CATÉGORIE FINALE : $final_cat_name"
    
    # Appliquer la catégorie
    echo -n "💾 Application... "
    
    # Obtenir le term_taxonomy_id
    local term_taxonomy_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
    WHERE term_id = $final_choice AND taxonomy = 'product_cat'
    " 2>/dev/null)
    
    if [ -z "$term_taxonomy_id" ]; then
        echo "❌ Catégorie introuvable !"
        return 1
    fi
    
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
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ID:$post_id - $title → $final_cat_name" >> "$LOG_DIR/dual_ai_categorize.log"
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

# Si mode debug
if [ "$SHOW_PROMPTS" = "1" ]; then
    echo ""
    echo "🔍 MODE DEBUG ACTIVÉ - Les prompts seront affichés"
    echo ""
fi

# Menu
if [ -z "$1" ]; then
    echo ""
    echo "Usage :"
    echo "  ./smart_categorize_dual_ai.sh ISBN"
    echo "  ./smart_categorize_dual_ai.sh -id ID"
    echo "  ./smart_categorize_dual_ai.sh -batch N"
    echo ""
    echo "Mode debug : SHOW_PROMPTS=1 ./smart_categorize_dual_ai.sh ISBN"
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
echo "📊 Logs : $LOG_DIR/dual_ai_categorize.log"