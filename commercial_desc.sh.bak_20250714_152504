#!/bin/bash
clear
cd /var/www/scripts-home-root/isbn/
source config/settings.sh
source lib/safe_functions.sh
source lib/commercial_description.sh

echo "🧪 TEST GÉNÉRATION DESCRIPTION COMMERCIALE"
echo "=========================================="

# Livre de test
test_id="16127"
test_isbn="9782070360024"

echo ""
echo "📖 Livre test : L'étranger (Camus)"
echo "ID: $test_id | ISBN: $test_isbn"
echo ""

# Vérifier la description actuelle
current_desc=$(get_meta_value "$test_id" "_best_description")
echo "📝 Description actuelle (${#current_desc} car.) :"
echo "$current_desc" | head -3
echo "..."
echo ""

# S'assurer qu'on a une description de base
echo "1️⃣ Vérification description de base..."
ensure_base_description "$test_id" "$test_isbn"

# Générer la description commerciale
echo ""
echo "2️⃣ Génération description commerciale..."
if generate_commercial_description "$test_id" "$test_isbn"; then
    echo "✅ Succès !"
    
    # Afficher la nouvelle description
    new_desc=$(get_meta_value "$test_id" "_commercial_description")
    echo ""
    echo "📢 NOUVELLE DESCRIPTION COMMERCIALE :"
    echo "─────────────────────────────────────"
    echo "$new_desc"
    echo "─────────────────────────────────────"
    echo ""
    echo "Longueur : ${#new_desc} caractères"
else
    echo "❌ Échec de la génération"
fi

echo ""
echo "Nettoyer les données de test ? (oui/non)"
read cleanup
if [ "$cleanup" = "oui" ]; then
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        DELETE FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$test_id AND meta_key IN ('_commercial_description', '_commercial_description_date')"
    echo "✅ Nettoyé"
fi
