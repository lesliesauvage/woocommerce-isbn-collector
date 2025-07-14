#!/bin/bash
clear
source config/settings.sh
source config/credentials.sh
source lib/safe_functions.sh

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

isbn="${1:-9782221503195}"

echo "🔍 RECHERCHE INTELLIGENTE AVEC FILTRE"
echo "ISBN : $isbn"
echo "════════════════════════════════════════════════════════════════════"

# 1. Identifier le livre cible
echo "📚 Identification du livre recherché..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$GOOGLE_BOOKS_API_KEY")
TARGET_TITLE=$(echo "$response" | jq -r '.items[0].volumeInfo.title // empty' 2>/dev/null)
TARGET_AUTHOR=$(echo "$response" | jq -r '.items[0].volumeInfo.authors[0] // empty' 2>/dev/null)

if [ -z "$TARGET_TITLE" ] || [ "$TARGET_TITLE" == "null" ]; then
    echo "❌ Impossible d'identifier le livre"
    exit 1
fi

echo -e "📖 Titre recherché : ${RED}$TARGET_TITLE${NC}"
echo -e "✍️  Auteur recherché : ${RED}$TARGET_AUTHOR${NC}"
echo ""

# Tableaux pour les résultats
declare -a descriptions
declare -a years
declare -a publishers
declare -a sources
count=0

# Fonction de filtre intelligent
add_if_matches() {
    local desc="$1"
    local title="$2"
    local author="$3"
    local year="$4"
    local publisher="$5"
    local source="$6"
    
    # Vérifications plus souples
    local title_match=0
    local author_match=0
    
    # Vérifier le titre (souple)
    if [[ "${title,,}" == "${TARGET_TITLE,,}" ]] || \
       [[ "${title,,}" == *"dictionnaire"* && "${title,,}" == *"symbole"* ]] || \
       [[ "${TARGET_TITLE,,}" == *"${title,,}"* ]] || \
       [[ "${title,,}" == *"${TARGET_TITLE,,}"* ]]; then
        title_match=1
    fi
    
    # Vérifier l'auteur (souple)
    if [[ "${author,,}" == *"chevalier"* ]] || \
       [[ "$author" == "$TARGET_AUTHOR" ]] || \
       [[ "${TARGET_AUTHOR,,}" == *"${author,,}"* ]]; then
        author_match=1
    fi
    
    # Si ça match
    if [ $title_match -eq 1 ] && [ $author_match -eq 1 ]; then
        if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt 50 ]; then
            # Éviter doublons
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
                echo -e "    ${GREEN}✓ TROUVÉ${NC} : $title ($year) - ${#desc} car."
            fi
        fi
    else
        echo -e "    ${RED}✗ Rejeté${NC} : $title / $author"
    fi
}

# 1. GOOGLE BOOKS - Recherches multiples
echo "📚 1. GOOGLE BOOKS"
echo "────────────────────────────────────────────────────────────────"

if [ -n "$GOOGLE_BOOKS_API_KEY" ]; then
    # A. Par ISBN direct (déjà fait plus haut mais on vérifie la description)
    echo "  → Par ISBN direct..."
    desc=$(echo "$response" | jq -r '.items[0].volumeInfo.description // empty' 2>/dev/null)
    if [ -n "$desc" ] && [ "$desc" != "null" ]; then
        add_if_matches "$desc" "$TARGET_TITLE" "$TARGET_AUTHOR" \
            "$(echo "$response" | jq -r '.items[0].volumeInfo.publishedDate // "?" | .[0:4]')" \
            "$(echo "$response" | jq -r '.items[0].volumeInfo.publisher // ""')" \
            "Google Books (ISBN direct)"
    fi
    
    # B. Recherche simple "Dictionnaire symboles"
    echo "  → Recherche 'Dictionnaire symboles'..."
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Dictionnaire+symboles&maxResults=40&key=$GOOGLE_BOOKS_API_KEY")
    
    for i in $(seq 0 39); do
        item=$(echo "$response" | jq ".items[$i]" 2>/dev/null)
        if [ "$item" != "null" ] && [ -n "$item" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
            title=$(echo "$item" | jq -r '.volumeInfo.title // ""')
            author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // ""')
            year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "" | .[0:4]')
            publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // ""')
            
            add_if_matches "$desc" "$title" "$author" "$year" "$publisher" "Google Books"
        fi
    done
    
    # C. Recherche avec auteur
    echo "  → Recherche 'Chevalier symboles'..."
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Chevalier+symboles&maxResults=20&key=$GOOGLE_BOOKS_API_KEY")
    
    for i in $(seq 0 19); do
        item=$(echo "$response" | jq ".items[$i]" 2>/dev/null)
        if [ "$item" != "null" ] && [ -n "$item" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
            title=$(echo "$item" | jq -r '.volumeInfo.title // ""')
            authors_list=$(echo "$item" | jq -r '.volumeInfo.authors // [] | join(", ")')
            year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "" | .[0:4]')
            publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // ""')
            
            add_if_matches "$desc" "$title" "$authors_list" "$year" "$publisher" "Google Books (auteur)"
        fi
    done
    
    # D. ISBN alternatifs
    echo "  → ISBN alternatifs (dictionnaire des symboles)..."
    for alt_isbn in "2221501861" "2221081641" "9782221081648" "2850760285"; do
        response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$alt_isbn&key=$GOOGLE_BOOKS_API_KEY")
        item=$(echo "$response" | jq '.items[0]' 2>/dev/null)
        if [ "$item" != "null" ] && [ -n "$item" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
            title=$(echo "$item" | jq -r '.volumeInfo.title // ""')
            author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // ""')
            year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "" | .[0:4]')
            publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // ""')
            
            add_if_matches "$desc" "$title" "$author" "$year" "$publisher" "Google (ISBN: $alt_isbn)"
        fi
    done
fi

# AFFICHER LES RÉSULTATS
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "📋 DESCRIPTIONS TROUVÉES : $count"
echo "════════════════════════════════════════════════════════════════════"

if [ $count -eq 0 ]; then
    echo "❌ Aucune description trouvée !"
    echo ""
    echo "💡 Essayez de copier la description depuis :"
    echo "   https://books.google.fr/books?isbn=$isbn"
    exit 1
fi

# Afficher toutes les éditions trouvées
for i in "${!descriptions[@]}"; do
    num=$((i+1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📖 ÉDITION #$num - ${YELLOW}${sources[$i]}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📚 Titre    : ${RED}Dictionnaire des symboles${NC}"
    echo -e "✍️  Auteur   : ${RED}Jean Chevalier${NC}"
    echo "📅 Année    : ${years[$i]}"
    echo "🏢 Éditeur  : ${publishers[$i]}"
    echo "📏 Longueur : ${#descriptions[$i]} caractères"
    echo ""
    echo "📝 Description :"
    echo "────────────────────────────────────────────────────────────────"
    
    if [ ${#descriptions[$i]} -gt 500 ]; then
        echo "${descriptions[$i]:0:500}..."
        echo ""
        echo "[... ${#descriptions[$i]} caractères au total]"
    else
        echo "${descriptions[$i]}"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "📌 Choisir une description (1-$count) ou 0 pour annuler :"
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
        safe_store_meta "$post_id" "_has_description" "1"
        
        echo ""
        echo -e "${GREEN}✅ DESCRIPTION SAUVEGARDÉE !${NC}"
        echo "Source : ${sources[$idx]}"
        echo "Année : ${years[$idx]}"
        echo "Longueur : ${#descriptions[$idx]} caractères"
    fi
fi
