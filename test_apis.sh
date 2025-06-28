#!/bin/bash
# Script de test des APIs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/utils.sh"

echo "=== Test des APIs ==="
echo ""

# ISBN de test
TEST_ISBN="9782290019436"  # Un ISBN français connu

echo "Test avec ISBN : $TEST_ISBN"
echo ""

# Test Google Books
echo "1. Test Google Books..."
response=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$TEST_ISBN")
if [[ "$response" == *"items"* ]]; then
    title=$(echo "$response" | jq -r '.items[0].volumeInfo.title' 2>/dev/null)
    echo "   ✓ Google Books OK - Trouvé: $title"
else
    echo "   ✗ Google Books ERREUR"
fi

# Test ISBNdb
echo "2. Test ISBNdb..."
response=$(curl -s -H "Authorization: $ISBNDB_KEY" "https://api2.isbndb.com/book/$TEST_ISBN")
if [[ ! "$response" =~ "unauthorized" ]] && [[ "$response" == *"book"* ]]; then
    echo "   ✓ ISBNdb OK"
else
    echo "   ✗ ISBNdb ERREUR - Vérifiez la clé API"
fi

# Test Open Library
echo "3. Test Open Library..."
response=$(curl -s "https://openlibrary.org/api/books?bibkeys=ISBN:$TEST_ISBN&format=json")
if [ "$response" != "{}" ]; then
    echo "   ✓ Open Library OK"
else
    echo "   ✗ Open Library ERREUR"
fi

# Test Groq
if [ -n "$GROQ_API_KEY" ]; then
    echo "4. Test Groq IA..."
    response=$(curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "llama3-70b-8192",
            "messages": [{"role": "user", "content": "Dis juste OK"}],
            "max_tokens": 10
        }')
    
    if [[ "$response" == *"choices"* ]]; then
        echo "   ✓ Groq IA OK"
    else
        error=$(echo "$response" | jq -r '.error.message' 2>/dev/null)
        echo "   ✗ Groq IA ERREUR: $error"
    fi
else
    echo "4. Groq IA non configuré"
fi

# Test MySQL
echo "5. Test MySQL..."
mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1" >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ MySQL OK"
else
    echo "   ✗ MySQL ERREUR - Vérifiez les identifiants"
fi

echo ""
echo "Tests terminés."
