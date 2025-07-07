#!/bin/bash
# Version GEMINI ONLY du smart_categorize

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

# Copier les fonctions nécessaires de smart_categorize_dual_ai.sh
cp smart_categorize_dual_ai.sh temp_single.sh

# Modifier pour utiliser seulement Gemini
sed -i 's/ask_claude/ask_gemini_twice/g' temp_single.sh
sed -i 's/Claude/Gemini (2e avis)/g' temp_single.sh
sed -i '/CLAUDE_API_KEY/d' temp_single.sh

# Créer une fonction qui fait 2 fois Gemini
cat >> temp_single.sh << 'FUNC_EOF'

# Fonction pour demander 2 fois à Gemini avec prompt différent
ask_gemini_twice() {
    local title="$1"
    local authors="$2"
    local description="$3"
    local categories_list="$4"
    local previous_response="${5:-}"
    
    # Modifier légèrement le prompt pour avoir un 2e avis
    local extra="Sois très précis et choisis la catégorie la plus spécifique possible."
    
    # Appeler ask_gemini avec le prompt modifié
    ask_gemini "$title" "$authors" "$description" "$categories_list" "$previous_response"
}
FUNC_EOF

# Renommer et exécuter
mv temp_single.sh smart_categorize_gemini_only.sh
chmod +x smart_categorize_gemini_only.sh

echo "✅ Créé : smart_categorize_gemini_only.sh"
echo ""
echo "Usage : ./smart_categorize_gemini_only.sh [ISBN]"
echo ""
echo "🚀 Reprendre la catégorisation avec Gemini seul ? (oui/non)"
read rep

if [ "$rep" = "oui" ]; then
    # Reprendre là où ça s'est arrêté
    remaining_isbn=(
        "2020115816"
        "202013554X"
        "2020211076"
        "2020326205"
        "2020413914"
        "2020509105"
        "2020550776"
        "2035054230"
        "2040039120"
        "2040166319"
    )
    
    echo "Reprise pour ${#remaining_isbn[@]} livres restants..."
    
    for isbn in "${remaining_isbn[@]}"; do
        echo ""
        echo "════════════════════════════════════════════════════════════════════════════"
        ./smart_categorize_gemini_only.sh "$isbn" -noverbose
        sleep 2
    done
fi
