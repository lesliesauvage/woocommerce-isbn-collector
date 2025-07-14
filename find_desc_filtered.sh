#!/bin/bash
clear
source config/settings.sh
source config/credentials.sh
source lib/safe_functions.sh

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

isbn="${1:-9782221503195}"

echo "🔍 RECHERCHE AVEC FILTRE STRICT"
echo "ISBN : $isbn"
echo "════════════════════════════════════════════════════════════════════"

# 1. D'ABORD identifier le livre EXACT qu'on cherche
echo "📚 Identification du livre recherché..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$GOOGLE_BOOKS_API_KEY")
TARGET_TITLE=$(echo "$response" | jq -r '.items[0].volumeInfo.title // empty' 2>/dev/null)
TARGET_AUTHOR=$(echo "$response" | jq -r '.items[0].volumeInfo.authors[0] // empty' 2>/dev/null)

if [ -z "$TARGET_TITLE" ] || [ "$TARGET_TITLE" == "null" ]; then
    echo "❌ Impossible d'identifier le livre avec cet ISBN"
    exit 1
fi

echo -e "📖 Titre recherché : ${RED}$TARGET_TITLE${NC}"
echo -e "✍️  Auteur recherché : ${RED}$TARGET_AUTHOR${NC}"
echo "⚠️  SEULES les éditions de CE livre par CET auteur seront affichées"
echo ""

# Tableaux pour stocker les résultats FILTRÉS
declare -a descriptions
declare -a years
declare -a publishers
declare -a sources
count=0

# Fonction pour vérifier et ajouter UNIQUEMENT si c'est le bon livre
add_if_correct_book() {
    local desc="$1"
    local title="$2"
    local author="$3"
    local year="$4"
    local publisher="$5"
    local source="$6"
    
    # FILTRE STRICT : Le titre ET l'auteur doivent correspondre
    if [[ "$title" == "$TARGET_TITLE" ]] && [[ "$author" == "$TARGET_AUTHOR" ]]; then
        if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt 50 ]; then
            # Éviter les doublons
            is_duplicate=0
            for existing in "${descriptions[@]}"; do
                if [ "${existing:0:100}" = "${desc:0:100}" ]; then
                    is_duplicate=1
                    break
                fi
            done
            
            if [ $is_duplicate -eq 0 ]; then
                descriptions+=("$desc")
                years+=("$year")
                publishers+=("$publisher")
                sources+=("$source")
                ((count++))
                echo -e "    ${GREEN}✓ Description trouvée${NC} ($source) : ${#desc} caractères"
            fi
        fi
    else
        # Livre rejeté
        echo -e "    ${RED}✗ REJETÉ${NC} : $title par $author (ne correspond pas)"
    fi
}

# 1. GOOGLE BOOKS
echo "📚 1. GOOGLE BOOKS"
echo "────────────────────────────────────────────────────────────────"

if [ -n "$GOOGLE_BOOKS_API_KEY" ]; then
    # Recherche ciblée
    echo "  → Recherche du livre exact..."
    search_query="intitle:\"$TARGET_TITLE\"+inauthor:\"$TARGET_AUTHOR\""
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=$search_query&maxResults=40&key=$GOOGLE_BOOKS_API_KEY")
    
    for i in $(seq 0 39); do
        item=$(echo "$response" | jq ".items[$i]" 2>/dev/null)
        if [ "$item" != "null" ] && [ -n "$item" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
            title=$(echo "$item" | jq -r '.volumeInfo.title // ""')
            author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // ""')
            year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "" | .[0:4]')
            publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // ""')
            
            add_if_correct_book "$desc" "$title" "$author" "$year" "$publisher" "Google Books"
        fi
    done
    
    # ISBN alternatifs MAIS toujours vérifier
    echo "  → ISBN alternatifs (avec vérification)..."
    for alt_isbn in "2221501861" "2221081641" "9782221081648" "2850760285"; do
        response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$alt_isbn&key=$GOOGLE_BOOKS_API_KEY")
        item=$(echo "$response" | jq '.items[0]' 2>/dev/null)
        if [ "$item" != "null" ] && [ -n "$item" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
            title=$(echo "$item" | jq -r '.volumeInfo.title // ""')
            author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // ""')
            year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "" | .[0:4]')
            publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // ""')
            
            add_if_correct_book "$desc" "$title" "$author" "$year" "$publisher" "Google Books (ISBN: $alt_isbn)"
        fi
    done
fi

# 2. OPEN LIBRARY
echo ""
echo "📚 2. OPEN LIBRARY"
echo "────────────────────────────────────────────────────────────────"

# Recherche par œuvre
echo "  → Recherche de l'œuvre..."
work_response=$(curl -s "https://openlibrary.org/search.json?title=$TARGET_TITLE&author=$TARGET_AUTHOR&limit=10")
docs=$(echo "$work_response" | jq -r '.docs[]' 2>/dev/null)

while IFS= read -r doc; do
    if [ -n "$doc" ] && [ "$doc" != "null" ]; then
        work_title=$(echo "$doc" | jq -r '.title // ""')
        work_author=$(echo "$doc" | jq -r '.author_name[0] // ""')
        
        # Vérifier que c'est le bon livre
        if [[ "$work_title" == "$TARGET_TITLE" ]] && [[ "$work_author" == *"$TARGET_AUTHOR"* ]]; then
            work_key=$(echo "$doc" | jq -r '.key // empty')
            
            if [ -n "$work_key" ]; then
                # Récupérer les éditions
                editions_response=$(curl -s "https://openlibrary.org${work_key}/editions.json")
                
                for j in $(seq 0 19); do
                    edition=$(echo "$editions_response" | jq ".entries[$j]" 2>/dev/null)
                    if [ "$edition" != "null" ] && [ -n "$edition" ]; then
                        desc=$(echo "$edition" | jq -r '.description // empty')
                        if [ "$desc" == "null" ] || [ -z "$desc" ]; then
                            desc=$(echo "$edition" | jq -r '.description.value // empty' 2>/dev/null)
                        fi
                        
                        if [ -n "$desc" ] && [ "$desc" != "null" ]; then
                            year=$(echo "$edition" | jq -r '.publish_date // "" | .[0:4]')
                            publisher=$(echo "$edition" | jq -r '.publishers[0] // ""')
                            
                            # On sait déjà que c'est le bon livre
                            add_if_correct_book "$desc" "$TARGET_TITLE" "$TARGET_AUTHOR" "$year" "$publisher" "Open Library"
                        fi
                    fi
                done
            fi
        fi
    fi
done <<< "$docs"

# AFFICHER LES RÉSULTATS
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "📋 DESCRIPTIONS TROUVÉES POUR LE BON LIVRE : $count"
echo "════════════════════════════════════════════════════════════════════"

if [ $count -eq 0 ]; then
    echo -e "❌ Aucune description trouvée pour ${RED}$TARGET_TITLE${NC} de ${RED}$TARGET_AUTHOR${NC}"
    exit 1
fi

# Afficher SEULEMENT les bonnes éditions
for i in "${!descriptions[@]}"; do
    num=$((i+1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 ÉDITION #$num - Source: ${sources[$i]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📚 Titre    : ${RED}$TARGET_TITLE${NC}"
    echo -e "✍️  Auteur   : ${RED}$TARGET_AUTHOR${NC}"
    echo "📅 Année    : ${years[$i]}"
    echo "🏢 Éditeur  : ${publishers[$i]}"
    echo "📏 Longueur : ${#descriptions[$i]} caractères"
    echo ""
    echo "📝 Description :"
    echo "────────────────────────────────────────────────────────────────"
    
    if [ ${#descriptions[$i]} -gt 500 ]; then
        echo "${descriptions[$i]:0:500}..."
    else
        echo "${descriptions[$i]}"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "📌 Choisir une édition (1-$count) ou 0 pour annuler :"
read -r choice

if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $count ]; then
    idx=$((choice-1))
    
    # Sauvegarder
    post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key = '_isbn' AND meta_value = '$isbn'
        LIMIT 1" 2>/dev/null)
    
    if [ -n "$post_id" ]; then
        safe_store_meta "$post_id" "_best_description" "${descriptions[$idx]}"
        safe_store_meta "$post_id" "_best_description_source" "${sources[$idx]}"
        
        echo ""
        echo -e "${GREEN}✅ SAUVEGARDÉ !${NC}"
        echo "Édition : ${years[$idx]} - ${publishers[$idx]}"
        echo "Longueur : ${#descriptions[$idx]} caractères"
    fi
fi
