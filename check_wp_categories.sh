#!/bin/bash
source config/settings.sh

echo "📚 CATÉGORIES WORDPRESS DES LIVRES"
echo "════════════════════════════════════════"

# Pour chaque livre de test
for id in 16127 16091 16089 16087 16128; do
    title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_title FROM wp_${SITE_ID}_posts WHERE ID=$id")
    
    categories=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT GROUP_CONCAT(t.name SEPARATOR ' > ')
        FROM wp_${SITE_ID}_term_relationships tr
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
        WHERE tr.object_id = $id
        AND tt.taxonomy = 'product_cat'
        GROUP BY tr.object_id")
    
    echo ""
    echo "ID: $id - $title"
    echo "→ Catégorie WP: $categories"
done

echo ""
echo "📊 LISTE DES CATÉGORIES WORDPRESS UTILISÉES :"
echo "────────────────────────────────────────────"
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    SELECT t.name as 'Catégorie WordPress', COUNT(*) as 'Nombre de livres'
    FROM wp_${SITE_ID}_term_relationships tr
    JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
    JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
    JOIN wp_${SITE_ID}_posts p ON tr.object_id = p.ID
    WHERE tt.taxonomy = 'product_cat'
    AND p.post_type = 'product'
    GROUP BY t.name
    ORDER BY COUNT(*) DESC
    LIMIT 20"
