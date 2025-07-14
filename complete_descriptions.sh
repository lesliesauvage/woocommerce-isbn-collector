#!/bin/bash
clear
source config/settings.sh
source lib/safe_functions.sh

isbn="${1:-9782221503195}"

echo "🔍 TEST COMPLET : RECHERCHE + 3 DESCRIPTIONS"
echo "ISBN : $isbn"
echo "════════════════════════════════════════════════════════════════════"

# Récupérer les infos du livre
book_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT 
        pm.post_id,
        p.post_title,
        (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = pm.post_id AND meta_key = '_best_authors' LIMIT 1),
        (SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id = pm.post_id AND meta_key = '_price' LIMIT 1)
    FROM wp_${SITE_ID}_postmeta pm
    JOIN wp_${SITE_ID}_posts p ON p.ID = pm.post_id
    WHERE pm.meta_key = '_isbn' AND pm.meta_value = '$isbn'
    LIMIT 1" 2>/dev/null)

if [ -z "$book_info" ]; then
    echo "❌ ISBN non trouvé dans la base"
    exit 1
fi

IFS=$'\t' read -r post_id title authors price <<< "$book_info"

echo "📖 Titre : $title"
echo "✍️  Auteur : $authors"
echo "💰 Prix : ${price}€"
echo ""

# 1. RECHERCHE DE LA MEILLEURE DESCRIPTION
echo "1️⃣ RECHERCHE D'ÉDITIONS POUR RÉCUPÉRER UNE DESCRIPTION"
echo "─────────────────────────────────────────────────────────"

# Recherche Google Books
search_title=$(echo "$title" | sed 's/[[:punct:]]//g' | cut -d' ' -f1-4)
search_author=$(echo "$authors" | cut -d',' -f1 | sed 's/[[:punct:]]//g')
search_query=$(echo "$search_title+$search_author" | sed 's/ /+/g')
echo "🔎 Recherche : $search_query"

response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=$search_query&maxResults=40&key=$GOOGLE_BOOKS_API_KEY")

# Trouver la meilleure description
best_desc=$(echo "$response" | jq -r '.items[]? | 
    select(.volumeInfo.description != null) |
    select(.volumeInfo.title | test("'"${title:0:20}"'"; "i")) |
    select(.volumeInfo.authors[0] | test("'"$search_author"'"; "i")) |
    {desc: .volumeInfo.description, date: .volumeInfo.publishedDate, length: (.volumeInfo.description | length)} |
    "\(.date)|\(.length)|\(.desc)"' 2>/dev/null | sort -t'|' -k2 -nr | head -1 | cut -d'|' -f3)

if [ -n "$best_desc" ]; then
    echo "✅ Description trouvée (${#best_desc} caractères)"
    echo "$best_desc"
    echo ""
    
    # Sauvegarder
    safe_store_meta "$post_id" "_best_description" "$best_desc"
    echo "💾 Sauvegardée dans _best_description"
else
    echo "❌ Aucune description trouvée"
fi

echo ""
echo ""

# 2. GÉNÉRATION DESCRIPTION COMMERCIALE
echo "2️⃣ DESCRIPTION COMMERCIALE (pour le site)"
echo "─────────────────────────────────────────────────────────"

# Utiliser commercial_desc.sh qui marche
echo "Génération via commercial_desc.sh..."
./commercial_desc.sh "$isbn" -save -quiet >/dev/null 2>&1

# Récupérer et afficher
commercial_desc=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT meta_value FROM wp_${SITE_ID}_postmeta 
    WHERE post_id = $post_id AND meta_key = '_commercial_description'
    LIMIT 1" 2>/dev/null)

if [ -n "$commercial_desc" ] && [ "$commercial_desc" != "NULL" ]; then
    echo "$commercial_desc"
    echo ""
    echo "📊 Longueur : ${#commercial_desc} caractères"
else
    echo "❌ Erreur génération"
fi

echo ""
echo ""

# 3. GÉNÉRATION MESSAGE NÉGOCIATION  
echo "3️⃣ MESSAGE NÉGOCIATION (réponse privée au client)"
echo "─────────────────────────────────────────────────────────"

# Calculer les prix
reduced_price=$((price - 2))

# SUPER PROMPT DE VENDEUR
negotiation_msg=$(curl -s -X POST https://api.anthropic.com/v1/messages \
    -H "Content-Type: application/json" \
    -H "x-api-key: $CLAUDE_API_KEY" \
    -H "anthropic-version: 2023-06-01" \
    -d '{
        "model": "claude-3-haiku-20240307",
        "max_tokens": 250,
        "messages": [
            {
                "role": "user",
                "content": "Tu es un vendeur expert en psychologie de vente sur Leboncoin/Vinted. Un acheteur négocie sur '"$title"' de '"$authors"' que je vends '"$price"'€. Il propose '"$reduced_price"'€.\n\nÉcris une réponse de VENDEUR MALIN qui :\n\n1. NE PARLE JAMAIS des prix des concurrents\n2. NE DIT PAS qu'\''il y a d'\''autres acheteurs (argument faible)\n3. VALORISE SUBTILEMENT l'\''expertise unique de l'\''auteur DIFFÉREMMENT de la description commerciale\n4. Crée une CONNEXION ÉMOTIONNELLE (\"ce livre va vous transformer\", \"vous allez découvrir\", etc.)\n5. Utilise la RARETÉ psychologique (\"exemplaire particulièrement soigné\", \"édition recherchée\")\n6. ANCRE la valeur (\"pour moins qu'\''un restaurant, vous avez 1060 pages de sagesse\")\n7. Reste FERME sur le prix SANS être désagréable\n8. Termine EXACTEMENT par : \"Qu'\''en dites-vous ?\"\n\nTon : Amical mais professionnel, comme un libraire passionné.\nDébut : \"Bonjour,\"\nMax 120 mots. Sois SUBTIL et PSYCHOLOGUE."
            }
        ]
    }' | jq -r '.content[0].text' 2>/dev/null)

if [ -n "$negotiation_msg" ] && [ "$negotiation_msg" != "null" ]; then
    echo "$negotiation_msg"
    echo ""
    echo "📊 Longueur : ${#negotiation_msg} caractères"
    safe_store_meta "$post_id" "_negotiation_message" "$negotiation_msg"
    echo "💾 Sauvegardé dans _negotiation_message"
else
    echo "❌ Erreur génération"
    echo "Debug: $negotiation_msg"
fi
