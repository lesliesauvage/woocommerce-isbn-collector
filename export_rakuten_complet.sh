#!/bin/bash
source config/settings.sh
source lib/safe_functions.sh

echo "📤 EXPORT RAKUTEN COMPLET - Format officiel"
echo "════════════════════════════════════════════════════════════════"
echo ""

# ISBN spécifique ou tous
isbn_filter="$1"

# Nom du fichier de sortie
output_file="exports/output/rakuten_complet_$(date +%Y%m%d_%H%M%S).csv"
mkdir -p exports/output

# Créer l'en-tête avec TOUS les champs du modèle Rakuten
cat > "$output_file" << 'HEADER_EOF'
EAN / ISBN / Code produit	Référence unique de l'annonce * / Unique Advert Refence (SKU) *	Prix de vente * / Selling Price *	Prix d'origine / RRP in euros	Qualité * / Condition *	Quantité * / Quantity *	Commentaire de l'annonce * / Advert comment *	Commentaire privé de l'annonce / Private Advert Comment	Type de Produit * / Type of Product *	Titre * / Title *	Description courte * / Short Description *	Résumé du Livre ou Revue	Langue	Auteurs	Editeur	Date de parution	Classification Thématique	Poids en grammes / Weight in grammes	Taille / Size	Nombre de Pages / Number of pages	URL Image principale * / Main picture *	URLs Images Secondaires / Secondary Picture	Code opération promo / Promotion code	Colonne vide / void column	Description Annonce Personnalisée	Expédition, Retrait / Shipping, Pick Up	Téléphone / Phone number	Code postale / Zip Code	Pays / Country
HEADER_EOF

# Requête SQL pour récupérer TOUTES les données
if [ -n "$isbn_filter" ]; then
    where_clause="AND pm_isbn.meta_value = '$isbn_filter'"
else
    where_clause=""
fi

mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT 
    -- EAN / ISBN
    IFNULL(pm_isbn.meta_value, ''),
    -- SKU (même que ISBN)
    IFNULL(pm_isbn.meta_value, ''),
    -- Prix de vente
    IFNULL(pm_price.meta_value, ''),
    -- Prix d'origine (regular price)
    IFNULL(pm_regular.meta_value, pm_price.meta_value),
    -- Qualité (mapping de _book_condition)
    CASE 
        WHEN pm_condition.meta_value = 'neuf' THEN 'N'
        WHEN pm_condition.meta_value = 'comme neuf' THEN 'CN'
        WHEN pm_condition.meta_value = 'très bon' THEN 'TBE'
        WHEN pm_condition.meta_value = 'bon' THEN 'BE'
        WHEN pm_condition.meta_value = 'correct' THEN 'EC'
        ELSE 'BE'
    END,
    -- Quantité
    IFNULL(pm_stock.meta_value, '1'),
    -- Commentaire annonce
    'Envoi rapide et soigné.',
    -- Commentaire privé
    '',
    -- Type de produit
    'Livre',
    -- Titre
    REPLACE(IFNULL(pm_title.meta_value, p.post_title), '\t', ' '),
    -- Description courte
    REPLACE(LEFT(IFNULL(pm_desc.meta_value, ''), 200), '\t', ' '),
    -- Résumé du livre
    REPLACE(IFNULL(pm_desc.meta_value, ''), '\t', ' '),
    -- Langue
    UPPER(IFNULL(pm_lang.meta_value, 'Français')),
    -- Auteurs
    REPLACE(IFNULL(pm_authors.meta_value, ''), '\t', ' '),
    -- Éditeur
    REPLACE(IFNULL(pm_publisher.meta_value, ''), '\t', ' '),
    -- Date de parution
    IFNULL(pm_date.meta_value, ''),
    -- Classification thématique
    IFNULL(pm_cat_ref.meta_value, 'Littérature française'),
    -- Poids en grammes
    IFNULL(pm_weight.meta_value, '200'),
    -- Taille
    CASE
        WHEN pm_binding.meta_value LIKE '%poche%' THEN 'Petit'
        WHEN pm_binding.meta_value LIKE '%grand%' THEN 'Grand'
        ELSE 'Moyen'
    END,
    -- Nombre de pages
    IFNULL(pm_pages.meta_value, ''),
    -- URL image principale
    IFNULL(pm_image.meta_value, ''),
    -- URLs images secondaires
    '',
    -- Code promo
    '',
    -- Colonne vide
    '',
    -- Description personnalisée (HTML)
    CONCAT('<div style=\"color:#000\"><h3>', 
           REPLACE(IFNULL(pm_title.meta_value, p.post_title), '\t', ' '),
           '</h3><p>', 
           REPLACE(IFNULL(pm_desc.meta_value, ''), '\t', ' '),
           '</p><ul>',
           IF(pm_authors.meta_value IS NOT NULL, CONCAT('<li>Auteur : ', pm_authors.meta_value, '</li>'), ''),
           IF(pm_publisher.meta_value IS NOT NULL, CONCAT('<li>Éditeur : ', pm_publisher.meta_value, '</li>'), ''),
           IF(pm_pages.meta_value IS NOT NULL, CONCAT('<li>Pages : ', pm_pages.meta_value, '</li>'), ''),
           '</ul></div>'),
    -- Expédition/Retrait
    'EXP / RET',
    -- Téléphone
    '0668563512',
    -- Code postal
    IFNULL(pm_zip.meta_value, '76000'),
    -- Pays
    'France'
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_regular ON p.ID = pm_regular.post_id AND pm_regular.meta_key = '_regular_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
LEFT JOIN wp_${SITE_ID}_postmeta pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_stock'
LEFT JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
LEFT JOIN wp_${SITE_ID}_postmeta pm_lang ON p.ID = pm_lang.post_id AND pm_lang.meta_key = '_g_language'
LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id AND pm_publisher.meta_key = '_best_publisher'
LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_g_publishedDate'
LEFT JOIN wp_${SITE_ID}_postmeta pm_cat_ref ON p.ID = pm_cat_ref.post_id AND pm_cat_ref.meta_key = '_g_categorie_reference'
LEFT JOIN wp_${SITE_ID}_postmeta pm_weight ON p.ID = pm_weight.post_id AND pm_weight.meta_key = '_calculated_weight'
LEFT JOIN wp_${SITE_ID}_postmeta pm_binding ON p.ID = pm_binding.post_id AND pm_binding.meta_key = '_best_binding'
LEFT JOIN wp_${SITE_ID}_postmeta pm_pages ON p.ID = pm_pages.post_id AND pm_pages.meta_key = '_best_pages'
LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
LEFT JOIN wp_${SITE_ID}_postmeta pm_zip ON p.ID = pm_zip.post_id AND pm_zip.meta_key = '_location_zip'
LEFT JOIN wp_${SITE_ID}_postmeta pm_export ON p.ID = pm_export.post_id AND pm_export.meta_key = '_export_score'
WHERE p.post_type = 'product'
AND p.post_status = 'publish'
AND pm_export.meta_value = '100'
$where_clause
LIMIT 100" | sed 's/\t/\t/g' >> "$output_file"

# Compter les résultats
count=$(tail -n +2 "$output_file" | wc -l)

echo "✅ Export terminé : $output_file"
echo "📊 Livres exportés : $count"
echo ""
echo "📋 Aperçu du fichier (première ligne + 2 livres) :"
head -3 "$output_file" | cut -c1-200

echo ""
echo "💡 Ce fichier contient TOUS les champs requis par Rakuten !"
echo ""
echo "📤 Pour uploader sur Rakuten :"
echo "   1. Téléchargez le fichier"
echo "   2. Connectez-vous à votre compte vendeur Rakuten"
echo "   3. Allez dans 'Mon inventaire' > 'Importer mes produits'"
echo "   4. Uploadez le fichier CSV"
