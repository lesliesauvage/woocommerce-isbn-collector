#!/bin/bash
clear
source config/settings.sh
source lib/safe_functions.sh

isbn="${1:-9782221503195}"

echo "🔍 RECHERCHE DES ÉDITIONS DU MÊME LIVRE PAR LE MÊME AUTEUR"
echo "ISBN : $isbn"
echo "════════════════════════════════════════════════════════════════════"

# 1. D'ABORD récupérer le titre et auteur EXACT de CE livre
echo "📚 Identification du livre..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$GOOGLE_BOOKS_API_KEY")

if ! echo "$response" | jq empty 2>/dev/null; then
    echo "❌ Erreur API"
    exit 1
fi

# Extraire les infos EXACTES
ref_title=$(echo "$response" | jq -r '.items[0].volumeInfo.title // empty' 2>/dev/null)
ref_author=$(echo "$response" | jq -r '.items[0].volumeInfo.authors[0] // empty' 2>/dev/null)

if [ -z "$ref_title" ] || [ "$ref_title" == "null" ]; then
    echo "❌ Impossible de trouver le titre pour cet ISBN"
    exit 1
fi

echo "📖 Titre recherché : $ref_title"
echo "✍️  Auteur recherché : $ref_author"
echo ""

# 2. Chercher UNIQUEMENT ce livre par cet auteur
echo "🔎 Recherche des éditions de CE livre par CET auteur..."
echo "════════════════════════════════════════════════════════════════════"

# Recherche ciblée
search_query="intitle:\"$ref_title\"+inauthor:\"$ref_author\""
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=$search_query&maxResults=40&key=$GOOGLE_BOOKS_API_KEY")

# Tableaux pour stocker SEULEMENT les bonnes éditions
declare -a descriptions
declare -a years
declare -a publishers
declare -a isbns
count=0

# Parser SEULEMENT les livres qui correspondent EXACTEMENT
for i in $(seq 0 39); do
    item=$(echo "$response" | jq ".items[$i]" 2>/dev/null)
    if [ "$item" != "null" ] && [ -n "$item" ]; then
        # Vérifier titre et auteur
        item_title=$(echo "$item" | jq -r '.volumeInfo.title // ""' 2>/dev/null)
        item_author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // ""' 2>/dev/null)
        
        # VÉRIFIER QUE C'EST BIEN LE MÊME LIVRE ET LE MÊME AUTEUR
        if [[ "$item_title" == "$ref_title" ]] && [[ "$item_author" == "$ref_author" ]]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty' 2>/dev/null)
            
            # Si une description existe
            if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt 100 ]; then
                year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]' 2>/dev/null)
                publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "?"' 2>/dev/null)
                isbn_found=$(echo "$item" | jq -r '.volumeInfo.industryIdentifiers[]? | select(.type == "ISBN_13" or .type == "ISBN_10") | .identifier' 2>/dev/null | head -1)
                
                # Éviter les doublons de description
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
                    isbns+=("$isbn_found")
                    ((count++))
                    echo "  ✓ Édition trouvée : $year - $publisher"
                fi
            fi
        fi
    fi
done

# Afficher les résultats
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "📋 ÉDITIONS AVEC DESCRIPTION : $count"
echo "════════════════════════════════════════════════════════════════════"

if [ $count -eq 0 ]; then
    echo "❌ Aucune édition avec description trouvée"
    echo "   pour '$ref_title' de $ref_author"
    exit 1
fi

# Trier par année et afficher
for i in "${!years[@]}"; do
    echo "${years[$i]}:$i"
done | sort -r | while IFS=: read -r year idx; do
    num=$((${idx}+1))
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 ÉDITION #$num - $ref_title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✍️  Auteur   : $ref_author"
    echo "📅 Année    : ${years[$idx]}"
    echo "🏢 Éditeur  : ${publishers[$idx]}"
    echo "📕 ISBN     : ${isbns[$idx]:-Non trouvé}"
    echo "📏 Longueur : ${#descriptions[$idx]} caractères"
    echo ""
    echo "📝 Description :"
    echo "────────────────────────────────────────────────────────────────"
    
    if [ ${#descriptions[$idx]} -gt 500 ]; then
        echo "${descriptions[$idx]:0:500}..."
    else
        echo "${descriptions[$idx]}"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "📌 Numéro de l'édition à choisir (1-$count) ou 0 pour annuler :"
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
        safe_store_meta "$post_id" "_best_description_source" "edition_${years[$idx]}"
        
        echo ""
        echo "✅ SAUVEGARDÉ !"
        echo "📅 Édition ${years[$idx]} - ${publishers[$idx]}"
        echo "📏 ${#descriptions[$idx]} caractères"
    fi
elif [ "$choice" = "0" ]; then
    echo "❌ Annulé"
fi
