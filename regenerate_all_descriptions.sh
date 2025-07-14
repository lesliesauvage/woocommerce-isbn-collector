#!/bin/bash
cd /var/www/scripts-home-root/isbn/
source config/settings.sh
source lib/safe_functions.sh
source lib/commercial_description.sh

echo "🔄 RÉGÉNÉRATION DES DESCRIPTIONS COMMERCIALES"
echo "============================================="

# Paramètres
limit="${1:-10}"
force="${2:-no}"

echo ""
echo "📊 Paramètres :"
echo "- Limite : $limit livres"
echo "- Mode force : $force"
echo ""

# Chercher les livres sans description commerciale
echo "🔍 Recherche des livres à traiter..."

if [ "$force" = "force" ]; then
    # Mode force : tous les livres avec un titre
    query="
    SELECT DISTINCT p.ID, pm_isbn.meta_value as isbn
    FROM wp_${SITE_ID}_posts p
    JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
    WHERE p.post_type = 'product'
    AND p.post_status = 'publish'
    AND pm_title.meta_value IS NOT NULL
    ORDER BY p.ID DESC
    LIMIT $limit"
else
    # Mode normal : seulement ceux sans description commerciale
    query="
    SELECT DISTINCT p.ID, pm_isbn.meta_value as isbn
    FROM wp_${SITE_ID}_posts p
    JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
    WHERE p.post_type = 'product'
    AND p.post_status = 'publish'
    AND p.ID NOT IN (
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key = '_commercial_description'
    )
    ORDER BY p.ID DESC
    LIMIT $limit"
fi

books=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "$query")

if [ -z "$books" ]; then
    echo "✅ Aucun livre à traiter"
    exit 0
fi

# Compter
total=$(echo "$books" | wc -l)
echo "📚 $total livre(s) à traiter"
echo ""

# Traiter chaque livre
count=0
success=0
failed=0

while IFS=$'\t' read -r id isbn; do
    ((count++))
    
    title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key='_best_title' LIMIT 1")
    
    echo "[$count/$total] 📖 $title (ID: $id)"
    
    # S'assurer d'avoir une description de base
    ensure_base_description "$id" "$isbn"
    
    # Générer la description commerciale
    if generate_commercial_description "$id" "$isbn"; then
        ((success++))
        echo "  ✅ Description commerciale générée"
    else
        ((failed++))
        echo "  ❌ Échec génération"
    fi
    
    # Pause pour éviter rate limit
    [ $count -lt $total ] && sleep 2
    echo ""
done <<< "$books"

# Résumé
echo "═══════════════════════════════════════════"
echo "📊 RÉSUMÉ :"
echo "- Total traité : $count"
echo "- ✅ Succès : $success"
echo "- ❌ Échecs : $failed"
echo "═══════════════════════════════════════════"
