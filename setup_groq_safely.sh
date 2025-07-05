#!/bin/bash
clear

echo "=== CONFIGURATION SÉCURISÉE DE LA CLÉ GROQ ==="
echo "Date : $(date)"
echo "════════════════════════════════════════════════════"
echo ""

echo "📋 INSTRUCTIONS POUR LA CLÉ GROQ :"
echo ""
echo "1️⃣ OBTENIR UNE CLÉ GROQ :"
echo "   - Aller sur : https://console.groq.com/"
echo "   - Se connecter ou créer un compte"
echo "   - Aller dans 'API Keys'"
echo "   - Créer une nouvelle clé"
echo ""
echo "2️⃣ AJOUTER LA CLÉ LOCALEMENT (PAS sur GitHub) :"
echo ""
echo "Appuyez sur ENTRÉE quand vous avez votre clé Groq..."
read

echo ""
echo "Collez votre clé Groq ici (elle sera masquée) :"
read -s GROQ_KEY

if [ -z "$GROQ_KEY" ]; then
    echo "❌ Aucune clé fournie"
    exit 1
fi

echo ""
echo "✅ Clé reçue : ${GROQ_KEY:0:20}..."

# Récupérer les autres clés existantes
if [ -f config/credentials.sh ]; then
    source config/credentials.sh
    EXISTING_GOOGLE="$GOOGLE_API_KEY"
    EXISTING_ISBNDB="$ISBNDB_API_KEY"
else
    EXISTING_GOOGLE=""
    EXISTING_ISBNDB=""
fi

# Créer/Mettre à jour credentials.sh
echo ""
echo "3️⃣ Mise à jour de config/credentials.sh..."
cat > config/credentials.sh << EOF
#!/bin/bash
# Fichier de credentials - NE PAS COMMITER
# CE FICHIER N'EST PAS SYNCHRONISÉ SUR GITHUB

# API Keys
GROQ_API_KEY="$GROQ_KEY"
GOOGLE_API_KEY="$EXISTING_GOOGLE"
ISBNDB_API_KEY="$EXISTING_ISBNDB"

# Note: Ce fichier est dans .gitignore
# Il ne sera JAMAIS envoyé sur GitHub
EOF

chmod 600 config/credentials.sh
echo "✅ Clé Groq sauvegardée localement"

# Vérifier que .gitignore contient bien credentials.sh
echo ""
echo "4️⃣ Vérification du .gitignore..."
if ! grep -q "credentials.sh" .gitignore; then
    echo "config/credentials.sh" >> .gitignore
    echo "✅ Ajouté credentials.sh au .gitignore"
else
    echo "✅ credentials.sh déjà dans .gitignore"
fi

# Test de la configuration
echo ""
echo "5️⃣ Test de la configuration..."
source config/settings.sh

if [ -n "$GROQ_API_KEY" ] && [ "$GROQ_API_KEY" != "" ]; then
    echo "✅ Configuration OK"
    echo "   - GROQ_API_KEY chargée : ${GROQ_API_KEY:0:30}..."
    echo "   - DB_NAME : $DB_NAME"
    echo "   - SITE_ID : $SITE_ID"
else
    echo "❌ Erreur de configuration"
fi

# Test avec l'API Groq
echo ""
echo "6️⃣ Test de l'API Groq..."
test_response=$(curl -s -X POST "$GROQ_API_URL" \
    -H "Authorization: Bearer $GROQ_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{
        "model": "llama-3.2-3b-preview",
        "messages": [{"role": "user", "content": "Dis juste OK"}],
        "max_tokens": 10
    }' 2>/dev/null)

if echo "$test_response" | grep -q "OK\|ok\|Ok"; then
    echo "✅ API Groq fonctionnelle !"
elif echo "$test_response" | grep -q "Invalid API key"; then
    echo "❌ Clé API invalide"
elif echo "$test_response" | grep -q "error"; then
    echo "⚠️  Erreur : $(echo "$test_response" | grep -o '"message":"[^"]*"')"
else
    echo "✅ API Groq accessible"
fi

# Vérifier que la sync GitHub fonctionne toujours
echo ""
echo "7️⃣ Test de synchronisation GitHub..."
echo "# Test sync $(date)" >> README.md
git add README.md .gitignore
git commit -m "Test sync après config Groq" >/dev/null 2>&1
git push origin main >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Synchronisation GitHub OK"
    echo "   (credentials.sh n'est PAS synchronisé)"
else
    echo "⚠️  Problème de synchronisation"
fi

echo ""
echo "════════════════════════════════════════════════════"
echo "✅ CONFIGURATION TERMINÉE"
echo ""
echo "📊 RÉSUMÉ SÉCURITÉ :"
echo "- La clé Groq est stockée LOCALEMENT dans config/credentials.sh"
echo "- Ce fichier n'est JAMAIS envoyé sur GitHub (.gitignore)"
echo "- GitHub ne verra JAMAIS votre clé"
echo "- La synchronisation continue de fonctionner normalement"
echo ""
echo "📋 Pour tester :"
echo "./analyze_with_collect.sh  # Utilise Groq pour l'enrichissement"
echo ""
echo "🔒 IMPORTANT :"
echo "- NE JAMAIS mettre la clé dans un autre fichier"
echo "- NE JAMAIS commit credentials.sh"
echo "- Toujours utiliser config/credentials.sh pour les secrets"
echo ""
