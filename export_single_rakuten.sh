#!/bin/bash
source config/settings.sh

isbn="$1"
if [ -z "$isbn" ]; then
    echo "Usage: $0 ISBN"
    exit 1
fi

# Récupérer les données du livre
book_data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT 
    pm_isbn.meta_value,
    REPLACE(pm_title.meta_value, ';', ','),
    REPLACE(pm_authors.meta_value, ';', ','),
    pm_price.meta_value,
    pm_weight.meta_value
FROM wp_${SITE_ID}_postmeta pm_isbn
JOIN wp_${SITE_ID}_postmeta pm_title ON pm_isbn.post_id = pm_title.post_id 
    AND pm_title.meta_key = '_best_title'
JOIN wp_${SITE_ID}_postmeta pm_authors ON pm_isbn.post_id = pm_authors.post_id 
    AND pm_authors.meta_key = '_best_authors'
JOIN wp_${SITE_ID}_postmeta pm_price ON pm_isbn.post_id = pm_price.post_id 
    AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_weight ON pm_isbn.post_id = pm_weight.post_id 
    AND pm_weight.meta_key = '_calculated_weight'
WHERE pm_isbn.meta_key = '_isbn' 
AND pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null)

if [ -z "$book_data" ]; then
    echo "❌ Livre non trouvé avec ISBN: $isbn"
    exit 1
fi

# Créer le CSV
output_file="export_rakuten_${isbn}_$(date +%Y%m%d_%H%M%S).csv"
echo "isbn;title;author;price;weight" > "$output_file"
echo "$book_data" | sed 's/\t/;/g' >> "$output_file"

echo "✅ Export créé : $output_file"
echo ""
echo "Contenu :"
cat "$output_file"

# Mettre à jour le statut
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
UPDATE wp_${SITE_ID}_postmeta pm1
JOIN wp_${SITE_ID}_postmeta pm2 ON pm1.post_id = pm2.post_id
SET pm1.meta_value = 'exported'
WHERE pm2.meta_key = '_isbn' 
AND pm2.meta_value = '$isbn'
AND pm1.meta_key = '_rakuten_export_status'" 2>/dev/null

mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
INSERT INTO wp_${SITE_ID}_postmeta (post_id, meta_key, meta_value)
SELECT post_id, '_rakuten_last_export', NOW()
FROM wp_${SITE_ID}_postmeta
WHERE meta_key = '_isbn' AND meta_value = '$isbn'
ON DUPLICATE KEY UPDATE meta_value = NOW()" 2>/dev/null

echo ""
echo "✅ Statut mis à jour : exported"
