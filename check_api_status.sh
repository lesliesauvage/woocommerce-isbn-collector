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

# ISBN de test (Harry Potter)
TEST_ISBN="9782070543588"

echo "📚 ISBN de test : $TEST_ISBN"
echo "📅 Date : $(date)"
echo ""

# 1. TEST GOOGLE BOOKS
echo "1️⃣ GOOGLE BOOKS API"
echo "────────────────────────────────────────────────────"
if [ -n "$GOOGLE_BOOKS_API_KEY" ]; then
    echo "   ✅ Clé API configurée"
    echo -n "   🔄 Test de connexion... "
    
    response=$(curl -s -w "\n%{http_code}" "https://www.googleapis.com/books/v1/volumes?q=isbn:$TEST_ISBN&key=$GOOGLE_BOOKS_API_KEY")
    http_code=$(echo "$response" | tail -1)
    content=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        title=$(echo "$content" | grep -o '"title":"[^"]*' | head -1 | cut -d'"' -f4)
        if [ -n "$title" ]; then
            echo "✅ OK"
            echo "   📖 Livre trouvé : $title"
        else
            echo "⚠️ Connecté mais aucun livre trouvé"
        fi
    else
        echo "❌ Erreur HTTP $http_code"
        echo "   Message : $(echo "$content" | grep -o '"message":"[^"]*' | cut -d'"' -f4)"
    fi
else
    echo "   ❌ Clé API non configurée"
fi

# 2. TEST ISBNDB
echo ""
echo "2️⃣ ISBNDB API"
echo "────────────────────────────────────────────────────"
if [ -n "$ISBNDB_API_KEY" ]; then
    echo "   ✅ Clé API configurée"
    echo -n "   🔄 Test de connexion... "
    
    response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: $ISBNDB_API_KEY" \
        "https://api2.isbndb.com/book/$TEST_ISBN")
    http_code=$(echo "$response" | tail -1)
    content=$(echo "$response" | head -n -1)
    
    if [ "$http_code" = "200" ]; then
        title=$(echo "$content" | grep -o '"title":"[^"]*' | head -1 | cut -d'"' -f4)
        if [ -n "$title" ]; then
            echo "✅ OK"
            echo "   📖 Livre trouvé : $title"
        else
            echo "⚠️ Connecté mais aucun livre trouvé"
        fi
    else
        echo "❌ Erreur HTTP $http_code"
        if [[ "$content" =~ "Unauthorized" ]]; then
            echo "   ⚠️ Clé API invalide ou expirée"
        else
            echo "   Message : $(echo "$content" | grep -o '"message":"[^"]*' | cut -d'"' -f4)"
        fi
    fi
else
    echo "   ❌ Clé API non configurée"
fi

# 3. TEST OPEN LIBRARY
echo ""
echo "3️⃣ OPEN LIBRARY API"
echo "────────────────────────────────────────────────────"
echo "   ℹ️ API gratuite sans clé"
echo -n "   🔄 Test de connexion... "

response=$(curl -s -w "\n%{http_code}" "https://openlibrary.org/api/books?bibkeys=ISBN:$TEST_ISBN&format=json&jscmd=data")
http_code=$(echo "$response" | tail -1)
content=$(echo "$response" | head -n -1)

if [ "$http_code" = "200" ]; then
    if [ "$content" != "{}" ]; then
        title=$(echo "$content" | grep -o '"title":"[^"]*' | head -1 | cut -d'"' -f4)
        if [ -n "$title" ]; then
            echo "✅ OK"
            echo "   📖 Livre trouvé : $title"
        else
            echo "✅ API accessible"
        fi
    else
        echo "⚠️ Connecté mais livre non trouvé"
    fi
else
    echo "❌ Erreur HTTP $http_code"
fi

# 4. RÉSUMÉ
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
echo "💡 Pour configurer les clés API manquantes :"
echo "   nano config/credentials.sh"
echo ""
echo "[END: check_api_status.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
