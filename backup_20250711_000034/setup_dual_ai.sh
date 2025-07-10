#!/bin/bash
clear

echo "=== CONFIGURATION GEMINI + CLAUDE ==="
echo "Date : $(date)"
echo "════════════════════════════════════════════════════"
echo ""

# 1. Vérifier/ajouter les clés dans credentials.sh
echo "📝 Configuration des clés API pour la double IA"
echo ""

# Charger les clés existantes
if [ -f config/credentials.sh ]; then
    source config/credentials.sh
    echo "✅ Fichier credentials.sh trouvé"
else
    echo "❌ Fichier credentials.sh manquant !"
    exit 1
fi

echo ""
# Gemini
if [ -z "$GEMINI_API_KEY" ]; then
    echo "1️⃣ GEMINI (Google) - GRATUIT"
    echo "════════════════════════════════"
    echo "📌 Obtenir une clé sur : https://makersuite.google.com/app/apikey"
    echo "   - Connectez-vous avec votre compte Google"
    echo "   - Cliquez sur 'Create API Key'"
    echo "   - Copiez la clé"
    echo ""
    echo "Collez votre clé Gemini ici :"
    read -s GEMINI_KEY
    echo ""
    if [ -n "$GEMINI_KEY" ]; then
        echo "✅ Clé Gemini reçue : ${GEMINI_KEY:0:20}..."
    else
        echo "⚠️  Pas de clé Gemini fournie"
    fi
else
    GEMINI_KEY="$GEMINI_API_KEY"
    echo "✅ Clé Gemini déjà configurée : ${GEMINI_KEY:0:20}..."
fi

# Claude
echo ""
if [ -z "$CLAUDE_API_KEY" ]; then
    echo "2️⃣ CLAUDE (Anthropic) - PAYANT" 
    echo "════════════════════════════════"
    echo "📌 Obtenir une clé sur : https://console.anthropic.com/"
    echo "   - Créez un compte"
    echo "   - Allez dans 'API Keys'"
    echo "   - Créez une nouvelle clé"
    echo "   ⚠️  Nécessite une carte bancaire"
    echo ""
    echo "Collez votre clé Claude ici (ou ENTRÉE pour ignorer) :"
    read -s CLAUDE_KEY
    echo ""
    if [ -n "$CLAUDE_KEY" ]; then
        echo "✅ Clé Claude reçue : ${CLAUDE_KEY:0:20}..."
    else
        echo "⚠️  Pas de clé Claude - Mode Gemini seul"
    fi
else
    CLAUDE_KEY="$CLAUDE_API_KEY"
    echo "✅ Clé Claude déjà configurée : ${CLAUDE_KEY:0:20}..."
fi

# Mettre à jour credentials.sh
echo ""
echo "3️⃣ Mise à jour de config/credentials.sh..."

# Sauvegarder l'ancien
cp config/credentials.sh config/credentials.sh.bak.$(date +%Y%m%d_%H%M%S)

cat > config/credentials.sh << EOF
#!/bin/bash
# Fichier de credentials - NE PAS COMMITER
# CE FICHIER N'EST PAS SYNCHRONISÉ SUR GITHUB

# API Keys existantes
GROQ_API_KEY="$GROQ_API_KEY"
GOOGLE_API_KEY="$GOOGLE_API_KEY"
ISBNDB_API_KEY="$ISBNDB_API_KEY"

# Nouvelles IA pour catégorisation avancée
GEMINI_API_KEY="$GEMINI_KEY"
CLAUDE_API_KEY="$CLAUDE_KEY"

# URLs des APIs
GEMINI_API_URL="https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
CLAUDE_API_URL="https://api.anthropic.com/v1/messages"
EOF

chmod 600 config/credentials.sh
echo "✅ Fichier mis à jour"

# Test des APIs
echo ""
echo "4️⃣ Test de connexion aux APIs..."
echo "════════════════════════════════════════"

# Test Gemini
if [ -n "$GEMINI_KEY" ]; then
    echo -n "Test Gemini... "
    response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=$GEMINI_KEY" 2>/dev/null)
    if echo "$response" | grep -q "models"; then
        echo "✅ Connexion OK"
    else
        echo "❌ Erreur : $(echo "$response" | grep -o '"message":"[^"]*"' | head -1)"
    fi
fi

# Test Claude
if [ -n "$CLAUDE_KEY" ]; then
    echo -n "Test Claude... "
    response=$(curl -s -X POST https://api.anthropic.com/v1/messages \
        -H "x-api-key: $CLAUDE_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d '{
            "model": "claude-3-haiku-20240307",
            "messages": [{"role": "user", "content": "Réponds juste OK"}],
            "max_tokens": 10
        }' 2>/dev/null)
    
    if echo "$response" | grep -q "OK\|ok"; then
        echo "✅ Connexion OK"
    else
        echo "❌ Erreur : $(echo "$response" | grep -o '"message":"[^"]*"' | head -1)"
    fi
fi

# Résumé final
echo ""
echo "════════════════════════════════════════"
echo "📊 CONFIGURATION FINALE :"
echo ""

source config/settings.sh

# Vérifier quelles IA sont disponibles
ai_count=0
[ -n "$GROQ_API_KEY" ] && ((ai_count++)) && echo "✅ Groq configuré (analyse de base)"
[ -n "$GEMINI_API_KEY" ] && ((ai_count++)) && echo "✅ Gemini configuré (catégorisation)"
[ -n "$CLAUDE_API_KEY" ] && ((ai_count++)) && echo "✅ Claude configuré (validation)"

echo ""
if [ $ai_count -ge 2 ]; then
    echo "🎯 Mode DUAL AI activé : Les IA vont débattre pour trouver la meilleure catégorie !"
else
    echo "⚠️  Mode SINGLE AI : Une seule IA disponible"
fi

echo ""
echo "📋 Prochaine étape :"
echo "   ./smart_categorize_dual_ai.sh    # Utiliser la double IA"
echo ""
echo "💡 Note : Ce fichier setup_dual_ai.sh peut être réutilisé pour changer les clés"
echo ""
