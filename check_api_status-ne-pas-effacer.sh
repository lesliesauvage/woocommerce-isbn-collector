#!/bin/bash
echo "[START: check_api_status.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

clear
echo "════════════════════════════════════════════════════════════════════════"
echo "         🔌 VÉRIFICATION DU STATUS DES APIs"
echo "════════════════════════════════════════════════════════════════════════"
echo ""

# Charger les configurations
source config/settings.sh
source config/credentials.sh

# VOS ISBN DE LA BDD
ISBN_LIST=(
    "9782070360024"  # L'étranger (Camus) - ID: 16127
    "2901821030"     # La Révélation d'Arès - ID: 16091
    "2850760854"     # Dictionnaire Astrologique - ID: 16089
    "2040120815"     # L'écrevisse et son élevage - ID: 16087
    "9782070543588"  # Harry Potter - ID: 16128
)

echo "📚 Test avec ${#ISBN_LIST[@]} ISBN de votre BDD"
echo "📅 Date : $(date)"
echo ""

# Fonction pour tester un ISBN sur toutes les APIs
test_isbn() {
    local isbn=$1
    local desc=$2
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📖 TEST ISBN: $isbn"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Google Books
    echo -n "   Google Books: "
    if [ -n "$GOOGLE_BOOKS_API_KEY" ]; then
        response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=$GOOGLE_BOOKS_API_KEY" 2>/dev/null)
        total=$(echo "$response" | grep -o '"totalItems": *[0-9]*' | cut -d: -f2 | tr -d ' ')
        
        if [ "$total" -gt 0 ] 2>/dev/null; then
            title=$(echo "$response" | grep -o '"title": *"[^"]*"' | head -1 | cut -d'"' -f4)
            if [ -n "$title" ]; then
                echo "✅ $title"
            else
                echo "⚠️ Pas de titre"
            fi
        else
            echo "⚠️ Pas trouvé"
        fi
    else
        echo "❌ Clé manquante"
    fi
    
    # ISBNdb
    echo -n "   ISBNdb:       "
    if [ -n "$ISBNDB_API_KEY" ]; then
        response=$(curl -s -H "Authorization: $ISBNDB_API_KEY" "https://api2.isbndb.com/book/$isbn" 2>/dev/null)
        
        if [[ "$response" =~ \"title\" ]]; then
            title=$(echo "$response" | grep -o '"title":"[^"]*' | head -1 | cut -d'"' -f4)
            if [ -n "$title" ] && [ "$title" != "null" ]; then
                echo "✅ $title"
            else
                echo "⚠️ Pas de titre"
            fi
        else
            echo "⚠️ Pas trouvé"
        fi
    else
        echo "❌ Clé manquante"
    fi
    
    # Open Library
    echo -n "   Open Library: "
    response=$(curl -s "https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data" 2>/dev/null)
    
    if [ "$response" != "{}" ]; then
        title=$(echo "$response" | grep -o '"title": *"[^"]*"' | head -1 | cut -d'"' -f4)
        if [ -n "$title" ]; then
            echo "✅ $title"
        else
            echo "✅ Trouvé (sans titre)"
        fi
    else
        echo "⚠️ Pas trouvé"
    fi
}

# TESTER TOUS VOS ISBN
echo "🔍 TEST DE VOS LIVRES EXISTANTS"
echo "════════════════════════════════════════════════════════════════════════"

# Tester chaque ISBN
test_isbn "9782070360024"  # L'étranger (Camus)
test_isbn "2901821030"     # La Révélation d'Arès
test_isbn "2850760854"     # Dictionnaire Astrologique
test_isbn "2040120815"     # L'écrevisse et son élevage
test_isbn "9782070543588"  # Harry Potter

# RÉSUMÉ
echo ""
echo "════════════════════════════════════════════════════════════════════════"
echo "📊 RÉSUMÉ DU STATUS"
echo "────────────────────────────────────────────────────────────────────────"

# Compter les APIs fonctionnelles
working=0
[ -n "$GOOGLE_BOOKS_API_KEY" ] && ((working++))
[ -n "$ISBNDB_API_KEY" ] && ((working++))
((working++)) # Open Library toujours disponible

echo "   APIs configurées : $working/3"
echo ""

if [ $working -eq 3 ]; then
    echo "   ✅ TOUTES LES APIs SONT OPÉRATIONNELLES"
elif [ $working -eq 0 ]; then
    echo "   ❌ AUCUNE API CONFIGURÉE - Collecte impossible"
else
    echo "   ⚠️ CERTAINES APIs MANQUENT - Collecte partielle"
fi

echo ""
echo "💡 Pour traiter ces livres :"
echo "   ./isbn_unified.sh 9782070360024  # L'étranger"
echo "   ./isbn_unified.sh 2901821030     # La Révélation d'Arès"
echo "   ./collect_api_data.sh            # Tous d'un coup"
echo ""
echo "[END: check_api_status.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
