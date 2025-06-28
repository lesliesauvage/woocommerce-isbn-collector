#!/bin/bash

# Test des modèles Groq disponibles
GROQ_API_KEY="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"

echo "Test de l'API Groq avec llama3-70b..."

response=$(curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "llama3-70b-8192",
        "messages": [{
            "role": "user",
            "content": "Génère une description de 50 mots pour un livre sur les écrevisses"
        }],
        "temperature": 0.7,
        "max_tokens": 100
    }')

echo "Réponse:"
echo "$response" | jq '.'

description=$(echo "$response" | jq -r '.choices[0].message.content' 2>/dev/null)
echo ""
echo "Description extraite:"
echo "$description"
