#!/bin/bash
source config/settings.sh

isbn="${1:-9782070360024}"
output="rakuten_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

echo "📤 EXPORT RAKUTEN - SANS é MAIS AVEC TOUS LES AUTRES ACCENTS"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Fonction qui enlève SEULEMENT é et É
clean_only_e_aigu() {
    local text="$1"
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
        sed 's/é/e/g' | \
        sed 's/É/E/g' | \
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
    IFNULL(YEAR(pm_date.meta_value), '2020')
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

# Nettoyer en enlevant SEULEMENT é
titre=$(clean_only_e_aigu "$titre")
auteurs=$(clean_only_e_aigu "$auteurs")
editeur=$(clean_only_e_aigu "$editeur")
description=$(clean_only_e_aigu "$description")

# Mapper condition
case "$condition" in
    "neuf") qualite="N" ;;
    "comme neuf") qualite="CN" ;;
    *"bon"*) qualite="TBE" ;;
    *) qualite="BE" ;;
esac

# Prix public
prix_public=$(printf "%.2f" $(echo "$prix * 1.3" | bc 2>/dev/null || echo "$prix"))

# Image HTTPS
[[ "$image" =~ ^http:// ]] && image="${image/http:/https:}"

# En-tête (enlever é dans l'en-tête aussi)
echo -e "EAN / ISBN / Code produit\tReference unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualite * / Condition *\tQuantite * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire prive de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tResume du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thematique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode operation promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisee\tExpedition, Retrait / Shipping, Pick Up\tTelephone / Phone number\tCode postale / Zip Code\tPays / Country" > "$output"

# Données avec tous les accents SAUF é
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$isbn" \
    "$isbn" \
    "$prix" \
    "$prix_public" \
    "$qualite" \
    "1" \
    "Envoi rapide et soigne" \
    "Stock A1" \
    "Livre" \
    "$titre" \
    "${description:0:100}" \
    "$description" \
    "Français" \
    "$auteurs" \
    "$editeur" \
    "$date_pub" \
    "Litterature française" \
    "$poids" \
    "Moyen" \
    "$pages" \
    "$image" \
    "" \
    "" \
    "" \
    "Livre en bon etat" \
    "EXP / RET" \
    "0668563512" \
    "76000" \
    "France" >> "$output"

echo "✅ Export créé : $output"
echo ""
echo "📊 VÉRIFICATION :"
echo "────────────────"
echo "Lignes : $(wc -l < "$output")"
echo "Colonnes : $(tail -1 "$output" | awk -F'\t' '{print NF}')"
echo ""

echo "📚 APERÇU (sans é mais avec è, à, ç, etc.) :"
echo "───────────────────────────────────────────"
tail -1 "$output" | awk -F'\t' '{
    printf "Titre : %s\n", $10
    printf "Auteur : %s\n", $14
    printf "Editeur : %s\n", $15  
    printf "Langue : %s (avec ç)\n", $13
}'
echo ""
echo "🚀 Ce fichier garde tous les accents SAUF é !"
echo "   Si ça passe, on aura confirmé que c'est bien é le problème"
