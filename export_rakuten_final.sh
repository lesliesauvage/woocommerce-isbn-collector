#!/bin/bash
source config/settings.sh

isbn="${1:-9782070360024}"
output="rakuten_final_${isbn}_$(date +%Y%m%d_%H%M%S).csv"

echo "📤 EXPORT RAKUTEN - ISBN: $isbn"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Créer le fichier DIRECTEMENT avec la requête SQL et POINT-VIRGULE
{
# En-tête avec POINT-VIRGULE
echo "EAN / ISBN / Code produit;Référence unique de l'annonce * / Unique Advert Refence (SKU) *;Prix de vente * / Selling Price *;Prix d'origine / RRP in euros;Qualité * / Condition *;Quantité * / Quantity *;Commentaire de l'annonce * / Advert comment *;Commentaire privé de l'annonce / Private Advert Comment;Type de Produit * / Type of Product *;Titre * / Title *;Description courte * / Short Description *;Résumé du Livre ou Revue;Langue;Auteurs;Editeur;Date de parution;Classification Thématique;Poids en grammes / Weight in grammes;Taille / Size;Nombre de Pages / Number of pages;URL Image principale * / Main picture *;URLs Images Secondaires / Secondary Picture;Code opération promo / Promotion code;Colonne vide / void column;Description Annonce Personnalisée;Expédition, Retrait / Shipping, Pick Up;Téléphone / Phone number;Code postale / Zip Code;Pays / Country"

# Données avec POINT-VIRGULE et nettoyage des apostrophes
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT CONCAT_WS(';',
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
    REPLACE(REPLACE(REPLACE(COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title, 'Sans titre'), CHAR(10), ' '), CHAR(13), ' '), '''', ' '),
    LEFT(REPLACE(REPLACE(IFNULL(pm_desc.meta_value, 'Roman classique'), CHAR(10), ' '), CHAR(13), ' '), 200),
    REPLACE(REPLACE(IFNULL(pm_desc.meta_value, 'Roman classique de la littérature française'), CHAR(10), ' '), CHAR(13), ' '),
    'Français',
    IFNULL(pm_authors.meta_value, ''),
    IFNULL(pm_publisher.meta_value, ''),
    IFNULL(pm_date.meta_value, ''),
    'Littérature française',
    IFNULL(pm_weight.meta_value, '200'),
    CASE
        WHEN pm_binding.meta_value LIKE '%poche%' THEN 'Petit'
        WHEN pm_binding.meta_value LIKE '%grand%' THEN 'Grand'
        ELSE 'Moyen'
    END,
    IFNULL(pm_pages.meta_value, ''),
    REPLACE(IFNULL(pm_image.meta_value, ''), 'http://', 'https://'),
    '',
    '',
    '',
    CONCAT('<div><h3>', REPLACE(REPLACE(COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title), CHAR(10), ' '), CHAR(13), ' '), '</h3><p>', LEFT(REPLACE(REPLACE(IFNULL(pm_desc.meta_value, ''), CHAR(10), ' '), CHAR(13), ' '), 500), '</p></div>'),
    'EXP / RET',
    '0668563512',
    '76000',
    'France'
)
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
LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id AND pm_publisher.meta_key = '_best_publisher'
LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_g_publishedDate'
LEFT JOIN wp_${SITE_ID}_postmeta pm_weight ON p.ID = pm_weight.post_id AND pm_weight.meta_key = '_calculated_weight'
LEFT JOIN wp_${SITE_ID}_postmeta pm_binding ON p.ID = pm_binding.post_id AND pm_binding.meta_key = '_best_binding'
LEFT JOIN wp_${SITE_ID}_postmeta pm_pages ON p.ID = pm_pages.post_id AND pm_pages.meta_key = '_best_pages'
LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null
} > "$output"

echo "✅ Export créé : $output"
echo ""
echo "📋 VÉRIFICATIONS :"
echo "──────────────────"
echo "Format : CSV avec point-virgule"
echo "Encodage : UTF-8"
echo "Colonnes : $(head -1 "$output" | awk -F';' '{print NF}')"
echo ""
echo "Aperçu du titre (colonne 10) :"
tail -1 "$output" | cut -d';' -f10
echo ""
echo "💾 Fichier prêt pour Rakuten !"
