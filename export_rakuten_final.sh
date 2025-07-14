#!/bin/bash
source config/settings.sh

isbn="${1:-9782070360024}"
output="rakuten_final_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

echo "📤 EXPORT RAKUTEN FINAL - AVEC ACCENTS"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Fonction de nettoyage qui GARDE les accents
clean_rakuten_final() {
    local text="$1"
    # Enlever les logs mais GARDER les accents français
    echo "$text" | \
        sed 's/\[20[0-9][0-9]-[0-9-]* [0-9:]*\][^[]*//g' | \
        sed 's/\[[A-Z]*\][^[]*//g' | \
        sed 's/[→✓✗×]//g' | \
        tr '\n\r\t' ' ' | \
        sed "s/[''ʼ]/'/g" | \
        sed 's/[""]/"/g' | \
        sed 's/[«»]/"/g' | \
        sed 's/[—–]/-/g' | \
        sed 's/…/.../g' | \
        sed 's/œ/oe/g' | \
        sed 's/Œ/OE/g' | \
        sed 's/æ/ae/g' | \
        sed 's/Æ/AE/g' | \
        sed 's/[;]/,/g' | \
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
    IFNULL(DATE_FORMAT(pm_date.meta_value, '%Y'), '2020')
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
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null)

[ -z "$data" ] && { echo "❌ Aucune donnée pour ISBN $isbn"; exit 1; }

# Parser
IFS=$'\t' read -r isbn titre prix auteurs editeur description condition poids pages image date_pub <<< "$data"

# NETTOYER en gardant les accents
titre=$(clean_rakuten_final "$titre")
auteurs=$(clean_rakuten_final "$auteurs")
editeur=$(clean_rakuten_final "$editeur")
description=$(clean_rakuten_final "$description")

# Forcer l'UTF-8
titre=$(echo "$titre" | iconv -f UTF-8 -t UTF-8//TRANSLIT 2>/dev/null || echo "$titre")
auteurs=$(echo "$auteurs" | iconv -f UTF-8 -t UTF-8//TRANSLIT 2>/dev/null || echo "$auteurs")
editeur=$(echo "$editeur" | iconv -f UTF-8 -t UTF-8//TRANSLIT 2>/dev/null || echo "$editeur")
description=$(echo "$description" | iconv -f UTF-8 -t UTF-8//TRANSLIT 2>/dev/null || echo "$description")

# Mapper condition
case "$condition" in
    "neuf") qualite="N" ;;
    "comme neuf") qualite="CN" ;;
    "très bon"|"tres bon") qualite="TBE" ;;
    *) qualite="BE" ;;
esac

# Prix public
prix_public=$(printf "%.2f" $(echo "$prix * 1.3" | bc 2>/dev/null || echo "$prix"))

# Image HTTPS
[[ "$image" =~ ^http:// ]] && image="${image/http:/https:}"

# Vérifier la date
[[ "$date_pub" == "NULL" || -z "$date_pub" ]] && date_pub="2020"

# En-tête
echo -e "EAN / ISBN / Code produit\tRéférence unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualité * / Condition *\tQuantité * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire privé de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tRésumé du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thématique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode opération promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisée\tExpédition, Retrait / Shipping, Pick Up\tTéléphone / Phone number\tCode postale / Zip Code\tPays / Country" > "$output"

# Données avec accents
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$isbn" \
    "$isbn" \
    "$prix" \
    "$prix_public" \
    "$qualite" \
    "1" \
    "Envoi rapide et soigné" \
    "Stock A1" \
    "Livre" \
    "$titre" \
    "${description:0:100}" \
    "$description" \
    "Français" \
    "$auteurs" \
    "$editeur" \
    "$date_pub" \
    "Littérature française" \
    "$poids" \
    "Moyen" \
    "$pages" \
    "$image" \
    "" \
    "" \
    "" \
    "Livre en bon état" \
    "EXP / RET" \
    "0668563512" \
    "76000" \
    "France" >> "$output"

echo "✅ Export créé : $output"
echo ""
echo "📊 VÉRIFICATION :"
echo "────────────────"
echo "Format : $(file -bi "$output")"
echo "Lignes : $(wc -l < "$output")"
echo "Colonnes : $(tail -1 "$output" | awk -F'\t' '{print NF}')"
echo ""

echo "📚 APERÇU DES DONNÉES :"
echo "─────────────────────"
tail -1 "$output" | awk -F'\t' '{
    printf "ISBN : %s\n", $1
    printf "Titre : %s\n", $10
    printf "Prix : %s €\n", $3
    printf "Auteur : %s\n", $14
    printf "Éditeur : %s\n", $15
    printf "Langue : %s\n", $13
}'
echo ""
echo "🚀 Fichier prêt avec accents français !"
