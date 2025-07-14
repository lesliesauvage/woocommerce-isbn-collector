#!/bin/bash
clear
source config/settings.sh
source lib/safe_functions.sh

isbn="${1:-9782221503195}"

echo "🔍 RECHERCHE DES ÉDITIONS DU MÊME LIVRE AVEC DESCRIPTION"
echo "ISBN : $isbn"
echo "════════════════════════════════════════════════════════════════════"

# 1. D'abord récupérer le titre et auteur EXACT via l'ISBN
echo "📚 Récupération du livre de référence..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$GOOGLE_BOOKS_API_KEY")
reference_book=$(echo "$response" | jq -r '.items[0].volumeInfo' 2>/dev/null)

if [ "$reference_book" == "null" ] || [ -z "$reference_book" ]; then
    echo "❌ ISBN non trouvé sur Google Books"
    exit 1
fi

# Extraire les infos de référence
ref_title=$(echo "$reference_book" | jq -r '.title // empty')
ref_author=$(echo "$reference_book" | jq -r '.authors[0] // empty')
ref_desc=$(echo "$reference_book" | jq -r '.description // empty')

echo "📖 Livre recherché : $ref_title"
echo "✍️  Auteur : $ref_author"
echo "📝 Description actuelle : $([ -n "$ref_desc" ] && echo "OUI (${#ref_desc} car.)" || echo "AUCUNE")"
echo ""

# Si pas de titre ou auteur, impossible de continuer
if [ -z "$ref_title" ] || [ "$ref_title" == "null" ]; then
    echo "❌ Impossible de continuer sans titre"
    exit 1
fi

# 2. Chercher TOUTES les éditions de CE livre précis
echo "🔎 Recherche de toutes les éditions de ce livre..."
echo "════════════════════════════════════════════════════════════════════"

# Préparer la requête (titre exact + auteur)
search_query="intitle:\"$ref_title\""
[ -n "$ref_author" ] && [ "$ref_author" != "null" ] && search_query="$search_query+inauthor:\"$ref_author\""

# Faire la recherche
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=$search_query&maxResults=40&orderBy=relevance&key=$GOOGLE_BOOKS_API_KEY")

# Stocker les résultats
declare -a descriptions
declare -a years
declare -a publishers  
declare -a isbns
declare -a pages

# Parser tous les résultats
index=0
while IFS= read -r item; do
    if [ -n "$item" ] && [ "$item" != "null" ]; then
        # Extraire les infos
        item_title=$(echo "$item" | jq -r '.volumeInfo.title // empty')
        item_author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // empty')
        item_desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
        item_year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]')
        item_publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "?"')
        item_pages=$(echo "$item" | jq -r '.volumeInfo.pageCount // 0')
        item_isbn=$(echo "$item" | jq -r '.volumeInfo.industryIdentifiers[]? | select(.type == "ISBN_13" or .type == "ISBN_10") | .identifier' 2>/dev/null | head -1)
        
        # Vérifier que c'est bien le même livre (titre similaire)
        if [[ "${item_title,,}" == *"${ref_title,,}"* ]] || [[ "${ref_title,,}" == *"${item_title,,}"* ]]; then
            # Si une description existe et n'est pas déjà dans la liste
            if [ -n "$item_desc" ] && [ "$item_desc" != "null" ] && [ ${#item_desc} -gt 50 ]; then
                # Vérifier que c'est pas un doublon
                is_duplicate=0
                for existing in "${descriptions[@]}"; do
                    if [ "${existing:0:100}" = "${item_desc:0:100}" ]; then
                        is_duplicate=1
                        break
                    fi
                done
                
                if [ $is_duplicate -eq 0 ]; then
                    descriptions+=("$item_desc")
                    years+=("$item_year")
                    publishers+=("$item_publisher")
                    isbns+=("$item_isbn")
                    pages+=("$item_pages")
                    ((index++))
                fi
            fi
        fi
    fi
done < <(echo "$response" | jq -c '.items[]?' 2>/dev/null)

# Afficher les résultats triés par année
echo ""
echo "📚 ÉDITIONS TROUVÉES AVEC DESCRIPTION : $index"
echo ""

if [ $index -eq 0 ]; then
    echo "❌ Aucune édition avec description trouvée pour ce livre"
    exit 1
fi

# Créer un tableau d'indices triés par année
sorted_indices=()
for i in "${!years[@]}"; do
    sorted_indices+=("$i:${years[$i]}")
done

# Trier et afficher
IFS=$'\n' sorted=($(sort -t: -k2 -r <<<"${sorted_indices[*]}"))
unset IFS

num=1
for entry in "${sorted[@]}"; do
    i="${entry%%:*}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 ÉDITION #$num"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📅 Année    : ${years[$i]}"
    echo "🏢 Éditeur  : ${publishers[$i]}"
    echo "📕 ISBN     : ${isbns[$i]:-Non trouvé}"
    echo "📄 Pages    : ${pages[$i]}"
    echo "📏 Desc.    : ${#descriptions[$i]} caractères"
    echo ""
    echo "📝 Aperçu de la description :"
    echo "────────────────────────────────────────────────────────────────"
    
    # Afficher les 400 premiers caractères
    if [ ${#descriptions[$i]} -gt 400 ]; then
        echo "${descriptions[$i]:0:400}..."
    else
        echo "${descriptions[$i]}"
    fi
    echo ""
    
    ((num++))
done

echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "📌 Quelle description voulez-vous utiliser ?"
echo "   Entrez le numéro (1-$index) ou 0 pour annuler :"
read -r choice

# Valider et sauvegarder
if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $index ]; then
    # Retrouver l'index dans le tableau trié
    sorted_entry="${sorted[$((choice-1))]}"
    real_index="${sorted_entry%%:*}"
    
    selected_desc="${descriptions[$real_index]}"
    selected_year="${years[$real_index]}"
    selected_publisher="${publishers[$real_index]}"
    
    # Récupérer l'ID du livre dans la BDD
    post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key = '_isbn' AND meta_value = '$isbn'
        LIMIT 1" 2>/dev/null)
    
    if [ -n "$post_id" ]; then
        # Sauvegarder
        safe_store_meta "$post_id" "_best_description" "$selected_desc"
        safe_store_meta "$post_id" "_best_description_source" "google_books_edition_${selected_year}"
        safe_store_meta "$post_id" "_has_description" "1"
        
        echo ""
        echo "✅ DESCRIPTION SAUVEGARDÉE !"
        echo ""
        echo "📅 Édition : $selected_year - $selected_publisher"
        echo "📏 Longueur : ${#selected_desc} caractères"
        echo ""
        echo "💾 Sauvegardée dans _best_description"
        echo ""
        echo "📝 Début de la description :"
        echo "${selected_desc:0:200}..."
    else
        echo "❌ Erreur : Livre non trouvé dans la base"
    fi
elif [ "$choice" = "0" ]; then
    echo "❌ Annulé"
else
    echo "❌ Choix invalide"
fi
