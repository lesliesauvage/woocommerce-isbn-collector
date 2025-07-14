#!/bin/bash
clear
source config/settings.sh
source lib/safe_functions.sh

isbn="${1:-9782221503195}"

echo "🔍 RECHERCHE SIMPLE DE DESCRIPTIONS"
echo "ISBN : $isbn"
echo "════════════════════════════════════════════════════════════════════"

# Tableaux pour stocker les résultats
declare -a descriptions
declare -a titles
declare -a authors
declare -a years
declare -a publishers
declare -a isbns

# Fonction pour ajouter un résultat
add_result() {
    local desc="$1"
    local title="$2"
    local author="$3"
    local year="$4"
    local publisher="$5"
    local isbn_found="$6"
    
    if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt 100 ]; then
        descriptions+=("$desc")
        titles+=("$title")
        authors+=("$author")
        years+=("$year")
        publishers+=("$publisher")
        isbns+=("$isbn_found")
    fi
}

# 1. Recherche simple "Dictionnaire des symboles"
echo "📚 Test 1 : Recherche simple 'Dictionnaire des symboles'..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Dictionnaire+des+symboles&maxResults=40&key=$GOOGLE_BOOKS_API_KEY")

while IFS= read -r item; do
    desc=$(echo "$item" | jq -r '.description // empty')
    title=$(echo "$item" | jq -r '.title // ""')
    authors_arr=$(echo "$item" | jq -r '.authors // [] | join(", ")')
    year=$(echo "$item" | jq -r '.publishedDate // "?" | .[0:4]')
    publisher=$(echo "$item" | jq -r '.publisher // "?"')
    isbn_item=$(echo "$item" | jq -r '.industryIdentifiers[]? | select(.type == "ISBN_13" or .type == "ISBN_10") | .identifier' 2>/dev/null | head -1)
    
    # Vérifier si c'est bien un dictionnaire des symboles
    if [[ "$title" =~ [Dd]ictionnaire.*[Ss]ymbole ]] || [[ "$title" =~ [Ss]ymbole.*[Dd]ictionnaire ]]; then
        add_result "$desc" "$title" "$authors_arr" "$year" "$publisher" "$isbn_item"
    fi
done < <(echo "$response" | jq -r '.items[]?.volumeInfo' 2>/dev/null)

# 2. Recherche "Dictionnaire symboles Chevalier"
echo "📚 Test 2 : Avec auteur Chevalier..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Dictionnaire+symboles+Chevalier&maxResults=20&key=$GOOGLE_BOOKS_API_KEY")

while IFS= read -r item; do
    desc=$(echo "$item" | jq -r '.description // empty')
    title=$(echo "$item" | jq -r '.title // ""')
    authors_arr=$(echo "$item" | jq -r '.authors // [] | join(", ")')
    year=$(echo "$item" | jq -r '.publishedDate // "?" | .[0:4]')
    publisher=$(echo "$item" | jq -r '.publisher // "?"')
    isbn_item=$(echo "$item" | jq -r '.industryIdentifiers[]? | .identifier' 2>/dev/null | head -1)
    
    add_result "$desc" "$title" "$authors_arr" "$year" "$publisher" "$isbn_item"
done < <(echo "$response" | jq -r '.items[]?.volumeInfo' 2>/dev/null)

# 3. Recherche avec Gheerbrant (co-auteur)
echo "📚 Test 3 : Avec Gheerbrant..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=symboles+Chevalier+Gheerbrant&maxResults=20&key=$GOOGLE_BOOKS_API_KEY")

while IFS= read -r item; do
    desc=$(echo "$item" | jq -r '.description // empty')
    title=$(echo "$item" | jq -r '.title // ""')
    authors_arr=$(echo "$item" | jq -r '.authors // [] | join(", ")')
    year=$(echo "$item" | jq -r '.publishedDate // "?" | .[0:4]')
    publisher=$(echo "$item" | jq -r '.publisher // "?"')
    isbn_item=$(echo "$item" | jq -r '.industryIdentifiers[]? | .identifier' 2>/dev/null | head -1)
    
    if [[ "$title" =~ [Dd]ictionnaire ]] || [[ "$title" =~ [Ss]ymbole ]]; then
        add_result "$desc" "$title" "$authors_arr" "$year" "$publisher" "$isbn_item"
    fi
done < <(echo "$response" | jq -r '.items[]?.volumeInfo' 2>/dev/null)

# 4. Recherche par ISBN alternatifs connus
echo "📚 Test 4 : ISBN alternatifs..."
for alt_isbn in "2221501861" "2221081641" "9782221081648" "2850760285" "2221068122"; do
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$alt_isbn&key=$GOOGLE_BOOKS_API_KEY")
    
    desc=$(echo "$response" | jq -r '.items[0]?.volumeInfo.description // empty' 2>/dev/null)
    if [ -n "$desc" ] && [ "$desc" != "null" ]; then
        title=$(echo "$response" | jq -r '.items[0].volumeInfo.title // ""')
        authors_arr=$(echo "$response" | jq -r '.items[0].volumeInfo.authors // [] | join(", ")')
        year=$(echo "$response" | jq -r '.items[0].volumeInfo.publishedDate // "?" | .[0:4]')
        publisher=$(echo "$response" | jq -r '.items[0].volumeInfo.publisher // "?"')
        
        add_result "$desc" "$title" "$authors_arr" "$year" "$publisher" "$alt_isbn"
    fi
done

# 5. Recherche plus large
echo "📚 Test 5 : Recherche large 'symboles mythes rêves'..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=symboles+mythes+rêves+dictionnaire&maxResults=20&key=$GOOGLE_BOOKS_API_KEY")

while IFS= read -r item; do
    desc=$(echo "$item" | jq -r '.description // empty')
    title=$(echo "$item" | jq -r '.title // ""')
    authors_arr=$(echo "$item" | jq -r '.authors // [] | join(", ")')
    year=$(echo "$item" | jq -r '.publishedDate // "?" | .[0:4]')
    publisher=$(echo "$item" | jq -r '.publisher // "?"')
    isbn_item=$(echo "$item" | jq -r '.industryIdentifiers[]? | .identifier' 2>/dev/null | head -1)
    
    # Filtrer pour avoir le bon livre
    if [[ "$authors_arr" =~ Chevalier ]] && [[ "$title" =~ [Dd]ictionnaire ]]; then
        add_result "$desc" "$title" "$authors_arr" "$year" "$publisher" "$isbn_item"
    fi
done < <(echo "$response" | jq -r '.items[]?.volumeInfo' 2>/dev/null)

# Dédupliquer basé sur les 100 premiers caractères
declare -A seen
unique_indices=()

for i in "${!descriptions[@]}"; do
    key="${descriptions[$i]:0:100}"
    if [ -z "${seen[$key]}" ]; then
        seen[$key]=1
        unique_indices+=($i)
    fi
done

# Afficher les résultats
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "📋 RÉSULTATS UNIQUES : ${#unique_indices[@]}"
echo "════════════════════════════════════════════════════════════════════"

if [ ${#unique_indices[@]} -eq 0 ]; then
    echo "❌ Aucune description trouvée"
    echo ""
    echo "💡 Essayez de copier-coller la description depuis :"
    echo "   https://books.google.fr/books?q=isbn:$isbn"
    exit 1
fi

# Afficher chaque résultat
num=1
for i in "${unique_indices[@]}"; do
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 CHOIX #$num"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 Titre    : ${titles[$i]}"
    echo "✍️  Auteurs  : ${authors[$i]}"
    echo "📅 Année    : ${years[$i]}"
    echo "🏢 Éditeur  : ${publishers[$i]}"
    echo "📕 ISBN     : ${isbns[$i]:-Non trouvé}"
    echo "📏 Longueur : ${#descriptions[$i]} caractères"
    echo ""
    echo "📝 Description :"
    echo "────────────────────────────────────────────────────────────────"
    
    # Afficher plus de texte pour mieux voir
    if [ ${#descriptions[$i]} -gt 600 ]; then
        echo "${descriptions[$i]:0:600}..."
        echo ""
        echo "[... ${#descriptions[$i]} caractères au total]"
    else
        echo "${descriptions[$i]}"
    fi
    
    ((num++))
done

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "📌 Choisissez une description (1-${#unique_indices[@]}) ou 0 pour annuler :"
read -r choice

if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#unique_indices[@]} ]; then
    # Récupérer l'index réel
    real_index=${unique_indices[$((choice-1))]}
    selected_desc="${descriptions[$real_index]}"
    
    # Sauvegarder dans la BDD
    post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key = '_isbn' AND meta_value = '$isbn'
        LIMIT 1" 2>/dev/null)
    
    if [ -n "$post_id" ]; then
        safe_store_meta "$post_id" "_best_description" "$selected_desc"
        safe_store_meta "$post_id" "_best_description_source" "google_books_manual_${years[$real_index]}"
        safe_store_meta "$post_id" "_has_description" "1"
        
        echo ""
        echo "✅ SAUVEGARDÉ !"
        echo "📖 ${titles[$real_index]}"
        echo "📅 ${years[$real_index]} - ${publishers[$real_index]}"
        echo "📏 ${#selected_desc} caractères"
    else
        echo "❌ Livre non trouvé dans la base"
    fi
elif [ "$choice" = "0" ]; then
    echo "❌ Annulé"
else
    echo "❌ Choix invalide"
fi
