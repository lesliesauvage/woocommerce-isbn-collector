#!/bin/bash
clear
source config/settings.sh
source lib/safe_functions.sh

isbn="${1:-9782221503195}"

echo "🔍 RECHERCHE ET SÉLECTION DE DESCRIPTIONS"
echo "ISBN : $isbn"
echo "════════════════════════════════════════════════════════════════════"

# Tableaux pour stocker toutes les infos
declare -a descriptions
declare -a titles
declare -a authors
declare -a years
declare -a publishers
declare -a sources

# Fonction pour ajouter un résultat unique
add_result() {
    local desc="$1"
    local title="$2"
    local author="$3"
    local year="$4"
    local publisher="$5"
    local source="$6"
    
    # Vérifier que la description est valide et pas déjà présente
    if [ -n "$desc" ] && [ "$desc" != "null" ] && [ ${#desc} -gt 50 ]; then
        # Vérifier les doublons basés sur les 100 premiers caractères
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
        fi
    fi
}

# 1. Recherche par ISBN exact
echo "📚 Phase 1 : Recherche par ISBN..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$GOOGLE_BOOKS_API_KEY")

# Parser chaque résultat
while IFS= read -r item; do
    if [ -n "$item" ] && [ "$item" != "null" ]; then
        desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
        title=$(echo "$item" | jq -r '.volumeInfo.title // "Titre inconnu"')
        author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // "Auteur inconnu"')
        year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]')
        publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "Éditeur inconnu"')
        
        add_result "$desc" "$title" "$author" "$year" "$publisher" "ISBN direct"
    fi
done < <(echo "$response" | jq -c '.items[]?' 2>/dev/null)

# 2. Récupérer les infos de base pour recherches élargies
book_info=$(echo "$response" | jq -r '.items[0].volumeInfo | "\(.title)|\(.authors[0])"' 2>/dev/null)
IFS='|' read -r base_title base_author <<< "$book_info"

if [ "$base_title" != "null" ] && [ -n "$base_title" ]; then
    # 3. Recherche par titre + auteur
    echo "📚 Phase 2 : Recherche par titre + auteur..."
    search_title=$(echo "$base_title" | sed 's/[[:punct:]]//g' | tr ' ' '+')
    search_author=$(echo "$base_author" | sed 's/[[:punct:]]//g' | tr ' ' '+')
    
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=$search_title+$search_author&maxResults=30&orderBy=relevance&key=$GOOGLE_BOOKS_API_KEY")
    
    while IFS= read -r item; do
        if [ -n "$item" ] && [ "$item" != "null" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
            title=$(echo "$item" | jq -r '.volumeInfo.title // "Titre inconnu"')
            author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // "Auteur inconnu"')
            year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]')
            publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "Éditeur inconnu"')
            
            add_result "$desc" "$title" "$author" "$year" "$publisher" "Titre+Auteur"
        fi
    done < <(echo "$response" | jq -c '.items[]?' 2>/dev/null)
fi

# 4. Recherches spécifiques pour Dictionnaire des symboles
if [[ "$base_title" =~ "Dictionnaire" ]] && [[ "$base_title" =~ "symboles" ]]; then
    echo "📚 Phase 3 : Recherches spécifiques Dictionnaire des symboles..."
    
    # Recherche avec co-auteur Gheerbrant
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Dictionnaire+symboles+Chevalier+Gheerbrant&maxResults=20&key=$GOOGLE_BOOKS_API_KEY")
    
    while IFS= read -r item; do
        if [ -n "$item" ] && [ "$item" != "null" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
            title=$(echo "$item" | jq -r '.volumeInfo.title // "Titre inconnu"')
            authors_array=$(echo "$item" | jq -r '.volumeInfo.authors // [] | join(", ")')
            year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]')
            publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "Éditeur inconnu"')
            
            add_result "$desc" "$title" "$authors_array" "$year" "$publisher" "Chevalier+Gheerbrant"
        fi
    done < <(echo "$response" | jq -c '.items[]?' 2>/dev/null)
    
    # Recherche avec variantes
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=Dictionnaire+symboles+mythes+rêves&maxResults=10&key=$GOOGLE_BOOKS_API_KEY")
    
    while IFS= read -r item; do
        if [ -n "$item" ] && [ "$item" != "null" ]; then
            desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
            title=$(echo "$item" | jq -r '.volumeInfo.title // "Titre inconnu"')
            author=$(echo "$item" | jq -r '.volumeInfo.authors[0] // "Auteur inconnu"')
            year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]')
            publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "Éditeur inconnu"')
            
            add_result "$desc" "$title" "$author" "$year" "$publisher" "Mythes+Rêves"
        fi
    done < <(echo "$response" | jq -c '.items[]?' 2>/dev/null)
fi

# 5. Recherche par ISBN alternatifs connus
echo "📚 Phase 4 : ISBN alternatifs..."
alternative_isbns=(
    "2221501861"     # Bouquins 1982
    "2221081641"     # Bouquins 1997  
    "9782221081648"  # Version 13 chiffres
    "2850760285"     # Jupiter 1969
)

for alt_isbn in "${alternative_isbns[@]}"; do
    response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$alt_isbn&key=$GOOGLE_BOOKS_API_KEY")
    
    item=$(echo "$response" | jq -c '.items[0]?' 2>/dev/null)
    if [ -n "$item" ] && [ "$item" != "null" ]; then
        desc=$(echo "$item" | jq -r '.volumeInfo.description // empty')
        title=$(echo "$item" | jq -r '.volumeInfo.title // "Titre inconnu"')
        authors_array=$(echo "$item" | jq -r '.volumeInfo.authors // [] | join(", ")')
        year=$(echo "$item" | jq -r '.volumeInfo.publishedDate // "?" | .[0:4]')
        publisher=$(echo "$item" | jq -r '.volumeInfo.publisher // "Éditeur inconnu"')
        
        add_result "$desc" "$title" "$authors_array" "$year" "$publisher" "ISBN: $alt_isbn"
    fi
done

# Afficher les résultats
echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "📋 RÉSULTATS TROUVÉS : ${#descriptions[@]}"
echo "════════════════════════════════════════════════════════════════════"

# Afficher chaque résultat avec numéro
for i in "${!descriptions[@]}"; do
    num=$((i+1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 CHOIX #$num"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 Titre    : ${titles[$i]}"
    echo "✍️  Auteur   : ${authors[$i]}"
    echo "📅 Année    : ${years[$i]}"
    echo "🏢 Éditeur  : ${publishers[$i]}"
    echo "🔍 Source   : ${sources[$i]}"
    echo "📏 Longueur : ${#descriptions[$i]} caractères"
    echo ""
    echo "📝 Aperçu de la description :"
    echo "────────────────────────────────────────────────────────────────"
    
    # Afficher aperçu
    if [ ${#descriptions[$i]} -gt 300 ]; then
        echo "${descriptions[$i]:0:300}..."
    else
        echo "${descriptions[$i]}"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo ""

# Demander la sélection
if [ ${#descriptions[@]} -gt 0 ]; then
    echo "📌 Quelle description voulez-vous sauvegarder ?"
    echo "   Entrez le numéro (1-${#descriptions[@]}) ou 0 pour annuler :"
    read -r choice
    
    # Valider le choix
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#descriptions[@]} ]; then
        index=$((choice-1))
        selected_desc="${descriptions[$index]}"
        
        # Récupérer l'ID du livre
        post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT post_id FROM wp_${SITE_ID}_postmeta 
            WHERE meta_key = '_isbn' AND meta_value = '$isbn'
            LIMIT 1" 2>/dev/null)
        
        if [ -n "$post_id" ]; then
            # Sauvegarder la description
            safe_store_meta "$post_id" "_best_description" "$selected_desc"
            safe_store_meta "$post_id" "_best_description_source" "google_books_${years[$index]}"
            
            # Mettre à jour aussi les autres champs si meilleurs
            safe_store_meta "$post_id" "_best_title" "${titles[$index]}"
            safe_store_meta "$post_id" "_best_authors" "${authors[$index]}"
            safe_store_meta "$post_id" "_best_publisher" "${publishers[$index]}"
            
            echo ""
            echo "✅ DESCRIPTION SAUVEGARDÉE !"
            echo ""
            echo "📖 Titre    : ${titles[$index]}"
            echo "✍️  Auteur   : ${authors[$index]}"
            echo "📅 Année    : ${years[$index]}"
            echo "🏢 Éditeur  : ${publishers[$index]}"
            echo "📏 Longueur : ${#selected_desc} caractères"
            echo ""
            echo "💾 Métadonnées mises à jour :"
            echo "   - _best_description"
            echo "   - _best_description_source" 
            echo "   - _best_title"
            echo "   - _best_authors"
            echo "   - _best_publisher"
        else
            echo "❌ Erreur : Livre non trouvé dans la base (ISBN: $isbn)"
        fi
    elif [ "$choice" = "0" ]; then
        echo "❌ Sélection annulée"
    else
        echo "❌ Choix invalide"
    fi
else
    echo "❌ Aucune description trouvée"
fi
