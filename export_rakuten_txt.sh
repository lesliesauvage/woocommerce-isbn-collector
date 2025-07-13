#!/bin/bash
source config/settings.sh

# Reprendre toutes nos fonctions
clean_rakuten_text() {
    echo "$1" | \
    sed "s/'/ /g" | \
    sed "s/'/ /g" | \
    sed 's/"/ /g' | \
    sed 's/"/ /g' | \
    sed 's/«/ /g' | \
    sed 's/»/ /g' | \
    sed 's/…/.../g' | \
    sed 's/—/-/g' | \
    sed 's/–/-/g' | \
    sed 's/\r\n/<br \/>/g' | \
    sed 's/\n/<br \/>/g' | \
    sed 's/\r/<br \/>/g' | \
    sed 's/\t/ /g' | \
    sed 's/  */ /g' | \
    sed 's/^ *//;s/ *$//'
}

map_to_rakuten_category() {
    local category_path="$1"
    local mapping_file="config/rakuten_category_mapping.csv"
    
    if [ -f "$mapping_file" ]; then
        local mapped=$(grep -F "\"$category_path\"," "$mapping_file" | head -1 | cut -d',' -f2 | tr -d '"')
        if [ -n "$mapped" ]; then
            echo "$mapped"
            return
        fi
    fi
    
    echo "Littérature française"
}

isbn="${1:-9782070360024}"
output="rakuten_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

echo "📤 EXPORT RAKUTEN FORMAT TXT/TAB - ISBN: $isbn"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Récupérer les données (même requête qu'avant)
all_data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
WITH RECURSIVE CategoryPath AS (
    SELECT 
        tt.term_id,
        t.name,
        tt.parent,
        CAST(t.name AS CHAR(1000)) AS path,
        0 as level
    FROM wp_${SITE_ID}_posts p
    JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
    JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id AND tt.taxonomy = 'product_cat'
    JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
    WHERE pm_isbn.meta_value = '$isbn'
    
    UNION ALL
    
    SELECT 
        tt.term_id,
        t.name,
        tt.parent,
        CONCAT(t.name, ' > ', cp.path) AS path,
        cp.level + 1
    FROM CategoryPath cp
    JOIN wp_${SITE_ID}_term_taxonomy tt ON cp.parent = tt.term_id AND tt.taxonomy = 'product_cat'
    JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
    WHERE cp.parent > 0
)
SELECT 
    pm_isbn.meta_value as isbn,
    COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title) as titre,
    CAST(IFNULL(pm_price.meta_value, '0') AS DECIMAL(10,2)) as prix,
    CAST(IFNULL(pm_regular.meta_value, pm_price.meta_value) AS DECIMAL(10,2)) as prix_public,
    IFNULL(pm_condition.meta_value, 'bon') as condition_livre,
    CAST(IFNULL(pm_stock.meta_value, '1') AS UNSIGNED) as stock,
    IFNULL(pm_desc.meta_value, '') as description,
    IFNULL(pm_authors.meta_value, '') as auteurs,
    IFNULL(pm_publisher.meta_value, '') as editeur,
    IFNULL(pm_date.meta_value, '') as date_parution,
    CAST(IFNULL(pm_weight.meta_value, '200') AS UNSIGNED) as poids,
    IFNULL(pm_binding.meta_value, '') as binding,
    CAST(IFNULL(pm_pages.meta_value, '0') AS UNSIGNED) as pages,
    IFNULL(pm_image.meta_value, '') as image,
    (SELECT path FROM CategoryPath ORDER BY level DESC LIMIT 1) as wp_category
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_g_title ON p.ID = pm_g_title.post_id AND pm_g_title.meta_key = '_g_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_i_title ON p.ID = pm_i_title.post_id AND pm_i_title.meta_key = '_i_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_regular ON p.ID = pm_regular.post_id AND pm_regular.meta_key = '_regular_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
LEFT JOIN wp_${SITE_ID}_postmeta pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_stock'
LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id AND pm_publisher.meta_key = '_best_publisher'
LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_g_publishedDate'
LEFT JOIN wp_${SITE_ID}_postmeta pm_weight ON p.ID = pm_weight.post_id AND pm_weight.meta_key = '_calculated_weight'
LEFT JOIN wp_${SITE_ID}_postmeta pm_binding ON p.ID = pm_binding.post_id AND pm_binding.meta_key = '_best_binding'
LEFT JOIN wp_${SITE_ID}_postmeta pm_pages ON p.ID = pm_pages.post_id AND pm_pages.meta_key = '_best_pages'
LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null)

# Parser et nettoyer
IFS=$'\t' read -r isbn titre prix prix_public condition stock description auteurs editeur date_parution poids binding pages image wp_category <<< "$all_data"

# Vérifier les données obligatoires
if [ -z "$titre" ] || [ -z "$prix" ] || [ -z "$auteurs" ] || [ -z "$editeur" ]; then
    echo "❌ Données obligatoires manquantes"
    exit 1
fi

# Nettoyer tout
titre=$(clean_rakuten_text "$titre")
description=$(clean_rakuten_text "$description")
auteurs=$(clean_rakuten_text "$auteurs")
editeur=$(clean_rakuten_text "$editeur")
commentaire=$(clean_rakuten_text "Envoi rapide et soigné. Livre en $condition état.")
rakuten_category=$(map_to_rakuten_category "$wp_category")

# Mapper condition et taille
case "$condition" in
    "neuf") qualite="N" ;;
    "comme neuf") qualite="CN" ;;
    "très bon") qualite="TBE" ;;
    "bon") qualite="BE" ;;
    *) qualite="BE" ;;
esac

case "$binding" in
    *"poche"*) taille="Petit" ;;
    *"grand"*) taille="Grand" ;;
    *) taille="Moyen" ;;
esac

# Corriger URL image
[[ "$image" =~ ^http:// ]] && image="${image/http:/https:}"

# GÉNÉRER LE FICHIER TXT AVEC TAB
{
# En-tête avec TAB
echo -e "EAN / ISBN / Code produit\tRéférence unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualité * / Condition *\tQuantité * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire privé de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tRésumé du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thématique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode opération promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisée\tExpédition, Retrait / Shipping, Pick Up\tTéléphone / Phone number\tCode postale / Zip Code\tPays / Country"

# Données avec TAB
echo -e "$isbn\t$isbn\t$prix\t$prix_public\t$qualite\t$stock\t$commentaire\t\tLivre\t$titre\t${description:0:200}\t$description\tFrançais\t$auteurs\t$editeur\t$date_parution\t$rakuten_category\t$poids\t$taille\t$pages\t$image\t\t\t\t\tEXP / RET\t0668563512\t76000\tFrance"
} > "$output"

echo ""
echo "✅ Export créé : $output"
echo ""
echo "📋 FORMAT :"
echo "─────────"
echo "Type : TXT avec tabulation (TAB)"
echo "Encodage : UTF-8"
echo "Extension : .txt"
echo "Colonnes : 29"
echo ""
echo "🚀 PROCHAINES ÉTAPES :"
echo "1. Testez avec : https://outils.fr.shopping.rakuten.com/documents/file-validator/"
echo "2. Si OK à 80%+, uploadez sur Rakuten"
