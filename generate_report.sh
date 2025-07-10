#!/bin/bash
echo "[START: generate_report.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# Script pour générer un rapport détaillé

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"  # Fonctions sécurisées
source "$SCRIPT_DIR/lib/database.sh"

echo "=== RAPPORT DÉTAILLÉ DES DONNÉES COLLECTÉES ==="
echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Statistiques générales
echo "📊 STATISTIQUES GÉNÉRALES"
echo "========================"

total_products=$(mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "
    SELECT COUNT(*) FROM wp_${SITE_ID}_posts 
    WHERE post_type = 'product' AND post_status = 'publish';")

products_with_isbn=$(mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "
    SELECT COUNT(DISTINCT post_id) FROM wp_${SITE_ID}_postmeta 
    WHERE meta_key = '_isbn' AND meta_value != '';")

products_enriched=$(mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "
    SELECT COUNT(DISTINCT post_id) FROM wp_${SITE_ID}_postmeta 
    WHERE meta_key = '_api_collect_status' AND meta_value = 'completed';")

products_with_desc=$(mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "
    SELECT COUNT(DISTINCT post_id) FROM wp_${SITE_ID}_postmeta 
    WHERE meta_key = '_has_description' AND meta_value = '1';")

echo "Total produits : $total_products"
echo "Produits avec ISBN : $products_with_isbn"
echo "Produits enrichis : $products_enriched"
echo "Produits avec description : $products_with_desc"
echo ""

# Efficacité par API
echo "📈 EFFICACITÉ PAR API"
echo "===================="

mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT 
    'Google Books' as 'API',
    COUNT(DISTINCT post_id) as 'Produits',
    COUNT(CASE WHEN meta_key = '_g_description' AND meta_value != '' THEN 1 END) as 'Descriptions',
    COUNT(CASE WHEN meta_key = '_g_title' AND meta_value != '' THEN 1 END) as 'Titres',
    COUNT(CASE WHEN meta_key = '_g_pageCount' AND meta_value != '0' THEN 1 END) as 'Pages'
FROM wp_${SITE_ID}_postmeta WHERE meta_key LIKE '_g_%'
UNION ALL
SELECT 
    'ISBNdb' as 'API',
    COUNT(DISTINCT post_id) as 'Produits',
    COUNT(CASE WHEN meta_key IN ('_i_synopsis', '_i_overview') AND meta_value != '' THEN 1 END) as 'Descriptions',
    COUNT(CASE WHEN meta_key = '_i_title' AND meta_value != '' THEN 1 END) as 'Titres',
    COUNT(CASE WHEN meta_key = '_i_pages' AND meta_value != '0' THEN 1 END) as 'Pages'
FROM wp_${SITE_ID}_postmeta WHERE meta_key LIKE '_i_%'
UNION ALL
SELECT 
    'Open Library' as 'API',
    COUNT(DISTINCT post_id) as 'Produits',
    COUNT(CASE WHEN meta_key = '_o_description' AND meta_value != '' THEN 1 END) as 'Descriptions',
    COUNT(CASE WHEN meta_key = '_o_title' AND meta_value != '' THEN 1 END) as 'Titres',
    COUNT(CASE WHEN meta_key = '_o_number_of_pages' AND meta_value != '0' THEN 1 END) as 'Pages'
FROM wp_${SITE_ID}_postmeta WHERE meta_key LIKE '_o_%'
UNION ALL
SELECT 
    'Groq IA' as 'API',
    COUNT(DISTINCT post_id) as 'Produits',
    COUNT(CASE WHEN meta_key = '_groq_description' AND meta_value != '' THEN 1 END) as 'Descriptions',
    0 as 'Titres',
    0 as 'Pages'
FROM wp_${SITE_ID}_postmeta WHERE meta_key LIKE '_groq_%';"

echo ""

# Sources des meilleures données
echo "🏆 SOURCES DES MEILLEURES DONNÉES"
echo "================================="

mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT 
    meta_key as 'Donnée',
    meta_value as 'Source',
    COUNT(*) as 'Nombre'
FROM wp_${SITE_ID}_postmeta
WHERE meta_key IN (
    '_best_title_source',
    '_best_description_source',
    '_best_authors_source',
    '_best_binding_source',
    '_best_pages_source'
)
GROUP BY meta_key, meta_value
ORDER BY meta_key, COUNT(*) DESC;"

echo ""

# Produits problématiques
echo "⚠️  PRODUITS PROBLÉMATIQUES"
echo "=========================="

echo ""
echo "Produits sans description :"
mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
SELECT 
    p.ID,
    p.post_title as 'Titre',
    isbn.meta_value as 'ISBN'
FROM wp_${SITE_ID}_posts p
INNER JOIN wp_${SITE_ID}_postmeta isbn ON p.ID = isbn.post_id AND isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta has_desc ON p.ID = has_desc.post_id AND has_desc.meta_key = '_has_description'
WHERE p.post_type = 'product' 
AND p.post_status = 'publish'
AND (has_desc.meta_value IS NULL OR has_desc.meta_value = '0')
LIMIT 10;"

echo ""
echo "Rapport généré dans : $LOG_DIR/report_$(date +%Y%m%d_%H%M%S).txt"

echo "[END: generate_report.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
