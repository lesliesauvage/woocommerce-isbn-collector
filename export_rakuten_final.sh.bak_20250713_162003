#!/bin/bash
source config/settings.sh

isbn="${1:-9782070360024}"
output="rakuten_final_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

echo "📤 EXPORT RAKUTEN COMPLET - ISBN: $isbn"
echo "════════════════════════════════════════════════════════════════"

# D'abord vérifier les données
echo ""
echo "📊 Vérification des données..."
title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT IFNULL(pm_title.meta_value, IFNULL(pm_g_title.meta_value, p.post_title))
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_g_title ON p.ID = pm_g_title.post_id AND pm_g_title.meta_key = '_g_title'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null)

echo "✓ Titre trouvé : $title"

# Créer le fichier avec TOUS les champs
{
# En-tête
echo -e "EAN / ISBN / Code produit\tRéférence unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualité * / Condition *\tQuantité * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire privé de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tRésumé du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thématique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode opération promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisée\tExpédition, Retrait / Shipping, Pick Up\tTéléphone / Phone number\tCode postale / Zip Code\tPays / Country"

# Données
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT 
    pm_isbn.meta_value,
    pm_isbn.meta_value,
    IFNULL(pm_price.meta_value, '0'),
    IFNULL(pm_regular.meta_value, pm_price.meta_value),
    CASE 
        WHEN pm_condition.meta_value = 'neuf' THEN 'N'
        WHEN pm_condition.meta_value = 'comme neuf' THEN 'CN'
        WHEN pm_condition.meta_value = 'très bon' THEN 'TBE'
        WHEN pm_condition.meta_value = 'bon' THEN 'BE'
        ELSE 'BE'
    END,
    IFNULL(pm_stock.meta_value, '1'),
    CONCAT('Envoi rapide et soigné. Livre en ', IFNULL(pm_condition.meta_value, 'bon'), ' état.'),
    '',
    'Livre',
    IFNULL(pm_title.meta_value, IFNULL(pm_g_title.meta_value, IFNULL(pm_i_title.meta_value, p.post_title))),
    LEFT(IFNULL(pm_desc.meta_value, 'Roman classique'), 200),
    IFNULL(pm_desc.meta_value, 'Roman classique de la littérature française'),
    CASE 
        WHEN pm_lang.meta_value = 'fr' THEN 'Français'
        WHEN pm_lang.meta_value = 'en' THEN 'Anglais'
        ELSE 'Français'
    END,
    IFNULL(pm_authors.meta_value, ''),
    IFNULL(pm_publisher.meta_value, ''),
    IFNULL(pm_date.meta_value, ''),
    IFNULL(pm_cat.meta_value, 'Littérature française'),
    IFNULL(pm_weight.meta_value, '200'),
    CASE
        WHEN pm_binding.meta_value LIKE '%poche%' THEN 'Petit'
        WHEN pm_binding.meta_value LIKE '%grand%' THEN 'Grand'
        ELSE 'Moyen'
    END,
    IFNULL(pm_pages.meta_value, ''),
    IFNULL(pm_image.meta_value, ''),
    '',
    '',
    '',
    CONCAT('<div><h3>', IFNULL(pm_title.meta_value, p.post_title), '</h3><p>', LEFT(IFNULL(pm_desc.meta_value, ''), 500), '</p></div>'),
    'EXP / RET',
    '0668563512',
    '76000',
    'France'
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_regular ON p.ID = pm_regular.post_id AND pm_regular.meta_key = '_regular_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
LEFT JOIN wp_${SITE_ID}_postmeta pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_stock'
LEFT JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_g_title ON p.ID = pm_g_title.post_id AND pm_g_title.meta_key = '_g_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_i_title ON p.ID = pm_i_title.post_id AND pm_i_title.meta_key = '_i_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
LEFT JOIN wp_${SITE_ID}_postmeta pm_lang ON p.ID = pm_lang.post_id AND pm_lang.meta_key = '_g_language'
LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id AND pm_publisher.meta_key = '_best_publisher'
LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_g_publishedDate'
LEFT JOIN wp_${SITE_ID}_postmeta pm_cat ON p.ID = pm_cat.post_id AND pm_cat.meta_key = '_g_categories'
LEFT JOIN wp_${SITE_ID}_postmeta pm_weight ON p.ID = pm_weight.post_id AND pm_weight.meta_key = '_calculated_weight'
LEFT JOIN wp_${SITE_ID}_postmeta pm_binding ON p.ID = pm_binding.post_id AND pm_binding.meta_key = '_best_binding'
LEFT JOIN wp_${SITE_ID}_postmeta pm_pages ON p.ID = pm_pages.post_id AND pm_pages.meta_key = '_best_pages'
LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null
} > "$output"

echo ""
echo "✅ Export créé : $output"
echo ""
echo "📋 VÉRIFICATIONS :"
echo "─────────────────"
echo "Colonnes en-tête : $(head -1 "$output" | awk -F'\t' '{print NF}')"
echo "Colonnes données : $(tail -1 "$output" | awk -F'\t' '{print NF}')"
echo ""
echo "🔍 Titre (colonne 10) : $(tail -1 "$output" | cut -f10)"
echo "💰 Prix (colonne 3) : $(tail -1 "$output" | cut -f3)"
echo "📦 Qualité (colonne 5) : $(tail -1 "$output" | cut -f5)"
echo "✍️ Auteur (colonne 14) : $(tail -1 "$output" | cut -f14)"
echo ""
echo "💾 Fichier prêt pour upload sur Rakuten !"
