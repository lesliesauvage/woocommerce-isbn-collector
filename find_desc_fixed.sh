#!/bin/bash
clear
source config/settings.sh
source lib/safe_functions.sh

isbn="${1:-9782221503195}"

echo "🔍 RECHERCHE DE DESCRIPTIONS (VERSION CORRIGÉE)"
echo "ISBN : $isbn"
echo "════════════════════════════════════════════════════════════════════"

# Tableaux pour stocker les résultats
declare -a descriptions
declare -a titles
declare -a authors
declare -a years
declare -a publishers

# Compteur
count=0

# 1. Recherche simple
echo "📚 Recherche 'Dictionnaire des symboles'..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Dictionnaire+des+symboles&maxResults=20&key=$GOOGLE_BOOKS_API_KEY")

# Vérifier que c'est du JSON valide
if echo "$response" | jq empty 2>/dev/null; then
    # Extraire chaque livre un par un
    total_items=$(echo "$response" | jq -r '.totalItems // 0')
    echo "Résultats trouvés : $total_items"
    
    for i in $(seq 0 19); do
        item=$(echo "$response" | jq ".items[$i]" 2>/dev/null)
        if [ "$item" != "null" ] && [ -n "$item" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty' 2>/dev/null)
            if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt 100 ]; then
                title=$(echo "$item" | jq -r '.volumeInfo.title // "?"' 2>/dev/null)
                author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // "?"' 2>/dev/null)
                year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]' 2>/dev/null)
                publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "?"' 2>/dev/null)
                
                # Vérifier que c'est bien un dictionnaire des symboles
                if [[ "$title" =~ [Dd]ictionnaire.*[Ss]ymbole ]] || [[ "$title" =~ [Ss]ymbole.*[Dd]ictionnaire ]]; then
                    descriptions+=("$desc")
                    titles+=("$title")
                    authors+=("$author")
                    years+=("$year")
                    publishers+=("$publisher")
                    ((count++))
                    echo "  ✓ Trouvé : $title ($year)"
                fi
            fi
        fi
    done
else
    echo "❌ Erreur API Google Books"
fi

# 2. Recherche avec Chevalier
echo ""
echo "📚 Recherche 'Dictionnaire symboles Chevalier'..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Dictionnaire+symboles+Chevalier&maxResults=10&key=$GOOGLE_BOOKS_API_KEY")

if echo "$response" | jq empty 2>/dev/null; then
    for i in $(seq 0 9); do
        item=$(echo "$response" | jq ".items[$i]" 2>/dev/null)
        if [ "$item" != "null" ] && [ -n "$item" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty' 2>/dev/null)
            if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt 100 ]; then
                title=$(echo "$item" | jq -r '.volumeInfo.title // "?"' 2>/dev/null)
                author_list=$(echo "$item" | jq -r '.volumeInfo.authors // [] | join(", ")' 2>/dev/null)
                year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]' 2>/dev/null)
                publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "?"' 2>/dev/null)
                
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
                    authors+=("$author_list")
                    years+=("$year")
                    publishers+=("$publisher")
                    ((count++))
                    echo "  ✓ Trouvé : $title ($year)"
                fi
            fi
        fi
    done
fi

# 3. ISBN alternatifs connus du Dictionnaire des symboles
echo ""
echo "📚 Recherche par ISBN alternatifs..."
alt_isbns=(
    "2221501861"      # Bouquins
    "2221081641"      # Bouquins 1997
    "9782221081648"   # 13 chiffres
    "2850760285"      # Jupiter
)

for alt_isbn in "${alt_isbns[@]}"; do
    echo "  Test ISBN : $alt_isbn"
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$alt_isbn&key=$GOOGLE_BOOKS_API_KEY")
    
    if echo "$response" | jq empty 2>/dev/null; then
        item=$(echo "$response" | jq '.items[0]' 2>/dev/null)
        if [ "$item" != "null" ] && [ -n "$item" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty' 2>/dev/null)
            if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt 100 ]; then
                title=$(echo "$item" | jq -r '.volumeInfo.title // "?"' 2>/dev/null)
                author_list=$(echo "$item" | jq -r '.volumeInfo.authors // [] | join(", ")' 2>/dev/null)
                year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]' 2>/dev/null)
                publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "?"' 2>/dev/null)
                
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
                    authors+=("$author_list")
                    years+=("$year")
                    publishers+=("$publisher")
                    ((count++))
                    echo "    ✓ Trouvé : $title ($year)"
                fi
            fi
        fi
    fi
done

# Afficher les résultats
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "📋 DESCRIPTIONS TROUVÉES : $count"
echo "════════════════════════════════════════════════════════════════════"

if [ $count -eq 0 ]; then
    echo "❌ Aucune description trouvée"
    echo ""
    echo "💡 Vérifiez manuellement sur :"
    echo "   https://books.google.fr/books?q=isbn:$isbn"
    exit 1
fi

# Afficher chaque résultat
for i in "${!descriptions[@]}"; do
    num=$((i+1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 OPTION #$num"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 Titre    : ${titles[$i]}"
    echo "✍️  Auteur   : ${authors[$i]}"
    echo "📅 Année    : ${years[$i]}"
    echo "🏢 Éditeur  : ${publishers[$i]}"
    echo "📏 Longueur : ${#descriptions[$i]} caractères"
    echo ""
    echo "📝 Description :"
    echo "────────────────────────────────────────────────────────────────"
    
    # Afficher 500 caractères
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
echo "📌 Quelle description choisir ? (1-$count, ou 0 pour annuler) :"
read -r choice

if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $count ]; then
    idx=$((choice-1))
    
    # Récupérer l'ID du livre
    post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key = '_isbn' AND meta_value = '$isbn'
        LIMIT 1" 2>/dev/null)
    
    if [ -n "$post_id" ]; then
        # Sauvegarder
        safe_store_meta "$post_id" "_best_description" "${descriptions[$idx]}"
        safe_store_meta "$post_id" "_best_description_source" "manual_selection"
        safe_store_meta "$post_id" "_has_description" "1"
        
        echo ""
        echo "✅ DESCRIPTION SAUVEGARDÉE !"
        echo ""
        echo "📖 ${titles[$idx]}"
        echo "📅 ${years[$idx]} - ${publishers[$idx]}"
        echo "📏 ${#descriptions[$idx]} caractères sauvegardés"
    else
        echo "❌ Livre non trouvé dans la base de données"
    fi
elif [ "$choice" = "0" ]; then
    echo "❌ Annulé"
else
    echo "❌ Choix invalide"
fi
