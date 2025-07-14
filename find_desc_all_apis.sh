#!/bin/bash
clear
source config/settings.sh
source config/credentials.sh
source lib/safe_functions.sh

isbn="${1:-9782221503195}"

echo "🔍 RECHERCHE SUR TOUTES LES APIs DISPONIBLES"
echo "ISBN : $isbn"
echo "════════════════════════════════════════════════════════════════════"

# Tableaux pour stocker TOUS les résultats
declare -a descriptions
declare -a titles  
declare -a authors
declare -a years
declare -a publishers
declare -a sources
count=0

# Fonction pour ajouter un résultat
add_result() {
    local desc="$1"
    local title="$2"
    local author="$3"
    local year="$4"
    local publisher="$5"
    local source="$6"
    
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
            titles+=("$title")
            authors+=("$author")
            years+=("$year")
            publishers+=("$publisher")
            sources+=("$source")
            ((count++))
            echo "    ✓ Description trouvée ($source) : ${#desc} caractères"
        fi
    fi
}

# 1. GOOGLE BOOKS - Recherche élargie
echo "📚 1. GOOGLE BOOKS"
echo "────────────────────────────────────────────────────────────────"

if [ -n "$GOOGLE_BOOKS_API_KEY" ]; then
    # Test 1: Par ISBN
    echo "  → Recherche par ISBN..."
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$GOOGLE_BOOKS_API_KEY")
    desc=$(echo "$response" | jq -r '.items[0].volumeInfo.description // empty' 2>/dev/null)
    if [ -n "$desc" ] && [ "$desc" != "null" ]; then
        title=$(echo "$response" | jq -r '.items[0].volumeInfo.title // ""')
        author=$(echo "$response" | jq -r '.items[0].volumeInfo.authors[0] // ""')
        year=$(echo "$response" | jq -r '.items[0].volumeInfo.publishedDate // "" | .[0:4]')
        publisher=$(echo "$response" | jq -r '.items[0].volumeInfo.publisher // ""')
        add_result "$desc" "$title" "$author" "$year" "$publisher" "Google Books (ISBN)"
    fi
    
    # Test 2: Dictionnaire symboles (large)
    echo "  → Recherche 'Dictionnaire symboles'..."
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Dictionnaire+symboles&maxResults=40&key=$GOOGLE_BOOKS_API_KEY")
    for i in $(seq 0 39); do
        item=$(echo "$response" | jq ".items[$i]" 2>/dev/null)
        if [ "$item" != "null" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
            title=$(echo "$item" | jq -r '.volumeInfo.title // ""')
            author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // ""')
            year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "" | .[0:4]')
            publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // ""')
            
            # Si c'est un dictionnaire des symboles avec Chevalier
            if [[ "$title" =~ [Dd]ictionnaire.*[Ss]ymbole ]] && [[ "$author" =~ Chevalier ]]; then
                add_result "$desc" "$title" "$author" "$year" "$publisher" "Google Books"
            fi
        fi
    done
    
    # Test 3: ISBN alternatifs connus
    echo "  → Recherche ISBN alternatifs..."
    for alt_isbn in "2221501861" "2221081641" "9782221081648" "2850760285"; do
        response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$alt_isbn&key=$GOOGLE_BOOKS_API_KEY")
        desc=$(echo "$response" | jq -r '.items[0].volumeInfo.description // empty' 2>/dev/null)
        if [ -n "$desc" ] && [ "$desc" != "null" ]; then
            title=$(echo "$response" | jq -r '.items[0].volumeInfo.title // ""')
            author=$(echo "$response" | jq -r '.items[0].volumeInfo.authors[0] // ""')
            year=$(echo "$response" | jq -r '.items[0].volumeInfo.publishedDate // "" | .[0:4]')
            publisher=$(echo "$response" | jq -r '.items[0].volumeInfo.publisher // ""')
            add_result "$desc" "$title" "$author" "$year" "$publisher" "Google Books (ISBN: $alt_isbn)"
        fi
    done
else
    echo "  ❌ Clé API manquante"
fi

# 2. ISBNDB
echo ""
echo "📚 2. ISBNDB"
echo "────────────────────────────────────────────────────────────────"

if [ -n "$ISBNDB_API_KEY" ]; then
    # Par ISBN
    echo "  → Recherche par ISBN..."
    response=$(curl -s -H "Authorization: $ISBNDB_API_KEY" "https://api2.isbndb.com/book/$isbn")
    desc=$(echo "$response" | jq -r '.book.synopsis // empty' 2>/dev/null)
    if [ -n "$desc" ] && [ "$desc" != "null" ]; then
        title=$(echo "$response" | jq -r '.book.title // ""')
        author=$(echo "$response" | jq -r '.book.authors[0] // ""')
        year=$(echo "$response" | jq -r '.book.date_published // "" | .[0:4]')
        publisher=$(echo "$response" | jq -r '.book.publisher // ""')
        add_result "$desc" "$title" "$author" "$year" "$publisher" "ISBNdb"
    fi
    
    # ISBN alternatifs
    echo "  → Recherche ISBN alternatifs..."
    for alt_isbn in "2221501861" "2221081641" "9782221081648"; do
        response=$(curl -s -H "Authorization: $ISBNDB_API_KEY" "https://api2.isbndb.com/book/$alt_isbn")
        desc=$(echo "$response" | jq -r '.book.synopsis // empty' 2>/dev/null)
        if [ -n "$desc" ] && [ "$desc" != "null" ]; then
            title=$(echo "$response" | jq -r '.book.title // ""')
            author=$(echo "$response" | jq -r '.book.authors[0] // ""')
            year=$(echo "$response" | jq -r '.book.date_published // "" | .[0:4]')
            publisher=$(echo "$response" | jq -r '.book.publisher // ""')
            add_result "$desc" "$title" "$author" "$year" "$publisher" "ISBNdb (ISBN: $alt_isbn)"
        fi
    done
else
    echo "  ❌ Clé API manquante"
fi

# 3. OPEN LIBRARY
echo ""
echo "📚 3. OPEN LIBRARY (gratuit)"
echo "────────────────────────────────────────────────────────────────"

# Par ISBN
echo "  → Recherche par ISBN..."
response=$(curl -s "https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data")
if [ "$response" != "{}" ]; then
    # Essayer d'extraire la description
    desc=$(echo "$response" | jq -r '.["ISBN:'$isbn'"].excerpts[0].text // empty' 2>/dev/null)
    if [ -z "$desc" ] || [ "$desc" == "null" ]; then
        desc=$(echo "$response" | jq -r '.["ISBN:'$isbn'"].description // empty' 2>/dev/null)
    fi
    
    if [ -n "$desc" ] && [ "$desc" != "null" ]; then
        title=$(echo "$response" | jq -r '.["ISBN:'$isbn'"].title // ""')
        author=$(echo "$response" | jq -r '.["ISBN:'$isbn'"].authors[0].name // ""')
        year=$(echo "$response" | jq -r '.["ISBN:'$isbn'"].publish_date // "" | .[0:4]')
        publisher=$(echo "$response" | jq -r '.["ISBN:'$isbn'"].publishers[0].name // ""')
        add_result "$desc" "$title" "$author" "$year" "$publisher" "Open Library"
    fi
fi

# ISBN alternatifs
echo "  → Recherche ISBN alternatifs..."
for alt_isbn in "2221501861" "2221081641" "9782221081648"; do
    response=$(curl -s "https://openlibrary.org/api/books?bibkeys=ISBN:$alt_isbn&format=json&jscmd=data")
    if [ "$response" != "{}" ]; then
        desc=$(echo "$response" | jq -r '.["ISBN:'$alt_isbn'"].excerpts[0].text // empty' 2>/dev/null)
        if [ -z "$desc" ] || [ "$desc" == "null" ]; then
            desc=$(echo "$response" | jq -r '.["ISBN:'$alt_isbn'"].description // empty' 2>/dev/null)
        fi
        
        if [ -n "$desc" ] && [ "$desc" != "null" ]; then
            title=$(echo "$response" | jq -r '.["ISBN:'$alt_isbn'"].title // ""')
            author=$(echo "$response" | jq -r '.["ISBN:'$alt_isbn'"].authors[0].name // ""')
            year=$(echo "$response" | jq -r '.["ISBN:'$alt_isbn'"].publish_date // "" | .[0:4]')
            publisher=$(echo "$response" | jq -r '.["ISBN:'$alt_isbn'"].publishers[0].name // ""')
            add_result "$desc" "$title" "$author" "$year" "$publisher" "Open Library (ISBN: $alt_isbn)"
        fi
    fi
done

# 4. Recherche par éditions Open Library
echo "  → Recherche par œuvres..."
# Chercher l'œuvre principale
work_response=$(curl -s "https://openlibrary.org/search.json?title=Dictionnaire+des+symboles&author=Chevalier&limit=5")
work_key=$(echo "$work_response" | jq -r '.docs[0].key // empty' 2>/dev/null)

if [ -n "$work_key" ] && [ "$work_key" != "null" ]; then
    # Récupérer les éditions de cette œuvre
    editions_response=$(curl -s "https://openlibrary.org${work_key}/editions.json")
    
    for i in $(seq 0 9); do
        edition=$(echo "$editions_response" | jq ".entries[$i]" 2>/dev/null)
        if [ "$edition" != "null" ] && [ -n "$edition" ]; then
            desc=$(echo "$edition" | jq -r '.description // empty')
            if [ -n "$desc" ] && [ "$desc" != "null" ]; then
                title=$(echo "$edition" | jq -r '.title // ""')
                author="Jean Chevalier"  # On sait que c'est lui
                year=$(echo "$edition" | jq -r '.publish_date // "" | .[0:4]')
                publisher=$(echo "$edition" | jq -r '.publishers[0] // ""')
                add_result "$desc" "$title" "$author" "$year" "$publisher" "Open Library (éditions)"
            fi
        fi
    done
fi

# AFFICHER LES RÉSULTATS
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "📋 DESCRIPTIONS TROUVÉES : $count"
echo "════════════════════════════════════════════════════════════════════"

if [ $count -eq 0 ]; then
    echo "❌ AUCUNE description trouvée sur AUCUNE API !"
    echo ""
    echo "💡 Vérifiez :"
    echo "   - Les clés API dans config/credentials.sh"
    echo "   - La connexion Internet"
    echo "   - L'ISBN est correct"
    exit 1
fi

# Afficher tous les résultats
for i in "${!descriptions[@]}"; do
    num=$((i+1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 CHOIX #$num - Source: ${sources[$i]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 Titre    : ${titles[$i]}"
    echo "✍️  Auteur   : ${authors[$i]}"
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
        
        echo ""
        echo "✅ SAUVEGARDÉ !"
        echo "Source : ${sources[$idx]}"
        echo "Longueur : ${#descriptions[$idx]} caractères"
    fi
fi
