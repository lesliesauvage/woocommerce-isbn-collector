#!/bin/bash
clear
source config/settings.sh
source lib/safe_functions.sh

echo "=== CATÉGORISATION INTELLIGENTE PAR GROQ ==="
echo ""

# Fonction pour pré-filtrer les catégories selon le type de livre
filter_categories() {
    local book_type=$1
    
    case "$book_type" in
        "fiction")
            # Pour la fiction, prendre toutes les catégories Roman*
            safe_mysql "
                SELECT CONCAT(t.term_id, ':', t.name)
                FROM wp_${SITE_ID}_terms t
                JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
                WHERE tt.taxonomy = 'product_cat'
                AND (t.name LIKE '%Roman%' OR t.name LIKE '%Fiction%' 
                     OR t.name LIKE '%Nouvelle%' OR t.name LIKE '%Récit%')
                AND tt.parent != 0  -- EXCLURE les catégories principales !
                ORDER BY t.name"
            ;;
        "religion")
            # Pour le religieux, prendre les catégories appropriées
            safe_mysql "
                SELECT CONCAT(t.term_id, ':', t.name)
                FROM wp_${SITE_ID}_terms t
                JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
                WHERE tt.taxonomy = 'product_cat'
                AND (t.name LIKE '%Relig%' OR t.name LIKE '%Spirit%' 
                     OR t.name LIKE '%Mystic%' OR t.name LIKE '%Ésotér%'
                     OR t.name LIKE '%Théolog%' OR t.name LIKE '%Foi%')
                AND tt.parent != 0  -- EXCLURE les catégories principales !
                ORDER BY t.name"
            ;;
    esac
}

echo "📚 TEST 1 : L'ÉTRANGER (FICTION)"
echo "════════════════════════════════"

# Pré-filtrer pour la fiction
fiction_cats=$(filter_categories "fiction" | tr '\n' '|')
cat_count=$(echo "$fiction_cats" | tr '|' '\n' | wc -l)

echo "Catégories pré-filtrées : $cat_count (au lieu de 695)"
echo ""

prompt="Livre : L'étranger de Albert Camus

Catégories possibles :
$fiction_cats

Choisis LA catégorie la plus appropriée.
Réponds UNIQUEMENT : ID|Nom"

response=$(curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$prompt" '{
        model: "llama3-70b-8192",
        messages: [{role: "user", content: $prompt}],
        temperature: 0.1,
        max_tokens: 20
    }')")

choice1=$(echo "$response" | jq -r '.choices[0].message.content' | head -1)
echo "✅ GROQ A CHOISI : $choice1"
echo ""

# Test 2
echo "📚 TEST 2 : LA RÉVÉLATION D'ARÈS (RELIGIEUX)"
echo "═══════════════════════════════════════════"

# Pré-filtrer pour le religieux
religion_cats=$(filter_categories "religion" | tr '\n' '|')
cat_count2=$(echo "$religion_cats" | tr '|' '\n' | wc -l)

echo "Catégories pré-filtrées : $cat_count2"
echo ""

prompt2="Livre : La Révélation d'Arès de Michel Potay (texte mystique/religieux)

Catégories possibles :
$religion_cats

Choisis LA catégorie la plus appropriée.
Réponds UNIQUEMENT : ID|Nom"

response2=$(curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg prompt "$prompt2" '{
        model: "llama3-70b-8192",
        messages: [{role: "user", content: $prompt}],
        temperature: 0.1,
        max_tokens: 20
    }')")

choice2=$(echo "$response2" | jq -r '.choices[0].message.content' | head -1)
echo "✅ GROQ A CHOISI : $choice2"
echo ""

echo "══════════════════════════════════════════════════"
echo "📊 RÉSULTATS :"
echo "──────────────"
echo "1. L'Étranger → $choice1"
echo "2. La Révélation → $choice2"
echo ""
echo "Cette fois, on a exclu les catégories principales !"
echo ""

# Bonus : montrer les catégories qui étaient disponibles
echo "📋 Pour info, voici les catégories fiction disponibles :"
echo "$fiction_cats" | tr '|' '\n' | head -10
echo "..."
