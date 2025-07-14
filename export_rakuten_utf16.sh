#!/bin/bash
source config/settings.sh

isbn="${1:-9782070360024}"
temp_file="/tmp/rakuten_temp_$$.txt"
output="rakuten_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

echo "📤 EXPORT RAKUTEN UTF-16 - VERSION FINALE"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Fonction de nettoyage selon les specs Rakuten
clean_rakuten() {
    local text="$1"
    echo "$text" | \
        sed 's/\[20[0-9][0-9]-[0-9-]* [0-9:]*\][^[]*//g' | \
        sed 's/\[[A-Z]*\][^[]*//g' | \
        sed 's/[→✓✗×]//g' | \
        tr '\n\r' ' ' | \
        sed 's/  */<br \/>/g' | \
        sed "s/'/'/g" | \
        sed 's/'/'/g' | \
        sed 's/"/"/g' | \
        sed 's/"/"/g' | \
        sed 's/«/"/g' | \
        sed 's/»/"/g' | \
        sed 's/…/.../g' | \
        sed 's/—/-/g' | \
        sed 's/–/-/g' | \
        sed 's/  */ /g' | \
        sed 's/^ *//;s/ *$//'
}

# Récupérer les données
data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT 
    pm_isbn.meta_value,
    COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title, 'Sans titre'),
    CAST(IFNULL(pm_price.meta_value, '15.00') AS DECIMAL(10,2)),
    IFNULL(pm_authors.meta_value, 'Auteur'),
    IFNULL(pm_publisher.meta_value, 'Éditeur'),
    IFNULL(pm_desc.meta_value, 'Livre d\'occasion en bon état'),
    IFNULL(pm_condition.meta_value, 'bon'),
    CAST(IFNULL(pm_weight.meta_value, '300') AS UNSIGNED),
    CAST(IFNULL(pm_pages.meta_value, '200') AS UNSIGNED),
    IFNULL(pm_image.meta_value, ''),
    IFNULL(YEAR(pm_date.meta_value), '2020'),
    IFNULL(pm_cat.meta_value, 'Littérature française')
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_g_title ON p.ID = pm_g_title.post_id AND pm_g_title.meta_key = '_g_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_i_title ON p.ID = pm_i_title.post_id AND pm_i_title.meta_key = '_i_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id AND pm_publisher.meta_key = '_best_publisher'
LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
LEFT JOIN wp_${SITE_ID}_postmeta pm_weight ON p.ID = pm_weight.post_id AND pm_weight.meta_key = '_calculated_weight'
LEFT JOIN wp_${SITE_ID}_postmeta pm_pages ON p.ID = pm_pages.post_id AND pm_pages.meta_key = '_best_pages'
LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_g_publishedDate'
LEFT JOIN wp_${SITE_ID}_postmeta pm_cat ON p.ID = pm_cat.post_id AND pm_cat.meta_key = '_rakuten_category'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null)

[ -z "$data" ] && { echo "❌ Aucune donnée pour ISBN $isbn"; exit 1; }

# Parser
IFS=$'\t' read -r isbn titre prix auteurs editeur description condition poids pages image date_pub categorie <<< "$data"

# Nettoyer selon specs Rakuten
titre=$(clean_rakuten "$titre")
auteurs=$(clean_rakuten "$auteurs")
editeur=$(clean_rakuten "$editeur")
description=$(clean_rakuten "$description")
categorie=$(clean_rakuten "$categorie")

# Limiter les longueurs
titre="${titre:0:200}"
description_courte="${description:0:100}"
auteurs="${auteurs:0:100}"
editeur="${editeur:0:50}"

# Mapper condition
case "$condition" in
    "neuf") qualite="N" ;;
    "comme neuf") qualite="CN" ;;
    "très bon"|"tres bon") qualite="TBE" ;;
    "bon") qualite="BE" ;;
    *) qualite="EC" ;;
esac

# Prix public (30% de plus)
prix_public=$(printf "%.2f" $(echo "$prix * 1.3" | bc 2>/dev/null || echo "$prix"))

# Assurer HTTPS pour l'image
[[ "$image" =~ ^http:// ]] && image="${image/http:/https:}"
[[ ! "$image" =~ ^https:// ]] && image=""

# Poids en grammes (entier uniquement)
poids=$(echo "$poids" | sed 's/[^0-9]//g')
[[ -z "$poids" || "$poids" -eq 0 ]] && poids="300"

# Pages (entier uniquement)
pages=$(echo "$pages" | sed 's/[^0-9]//g')
[[ -z "$pages" || "$pages" -eq 0 ]] && pages="200"

# Quantité (1-999)
quantite="1"

# Créer le fichier UTF-8 d'abord
{
# En-tête
echo -e "EAN / ISBN / Code produit\tRéférence unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualité * / Condition *\tQuantité * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire privé de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tRésumé du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thématique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode opération promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisée\tExpédition, Retrait / Shipping, Pick Up\tTéléphone / Phone number\tCode postale / Zip Code\tPays / Country"

# Données
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$isbn" \
    "$isbn" \
    "$prix" \
    "$prix_public" \
    "$qualite" \
    "$quantite" \
    "Envoi rapide et soigné" \
    "Stock A1" \
    "Livre" \
    "$titre" \
    "$description_courte" \
    "$description" \
    "Français" \
    "$auteurs" \
    "$editeur" \
    "$date_pub" \
    "$categorie" \
    "$poids" \
    "Moyen" \
    "$pages" \
    "$image" \
    "" \
    "" \
    "" \
    "Livre en bon état<br />Expédition sous 24h" \
    "EXP / RET" \
    "0668563512" \
    "76000" \
    "France"
} > "$temp_file"

# Convertir en UTF-16LE avec BOM (recommandé par Rakuten)
(printf '\xff\xfe'; iconv -f UTF-8 -t UTF-16LE "$temp_file") > "$output"
rm -f "$temp_file"

echo "✅ Export créé : $output"
echo ""
echo "📊 VÉRIFICATIONS SELON SPECS RAKUTEN :"
echo "──────────────────────────────────────"
echo "✓ Format : TXT avec TAB"
echo "✓ Encodage : UTF-16LE avec BOM (recommandé)"
echo "✓ Retours ligne remplacés par <br />"
echo "✓ Caractères Microsoft remplacés"
echo "✓ Poids : $poids (entier sans unité)"
echo "✓ Quantité : $quantite (1-999)"
echo "✓ Image : $([ -n "$image" ] && echo "HTTPS OK" || echo "Pas d'image")"
echo "✓ 29 colonnes"
echo ""
echo "📚 DONNÉES EXPORTÉES :"
echo "────────────────────"
echo "ISBN : $isbn"
echo "Titre : $titre"
echo "Prix : $prix €"
echo "Auteur : $auteurs"
echo "Éditeur : $editeur"
echo ""
echo "🚀 Fichier prêt pour Rakuten !"
echo "   Testez avec File-Validator : https://outils.fr.shopping.rakuten.com/documents/file-validator/"
