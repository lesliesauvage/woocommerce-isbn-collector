#!/bin/bash
source config/settings.sh

isbn="${1:-9782070360024}"

echo "🔧 EXPORT RAKUTEN - SOLUTION COMPLÈTE"
echo "════════════════════════════════════════════════════════════════"
echo ""

# 1. NETTOYAGE EXTRÊME - Enlever TOUS les caractères non-ASCII
clean_ascii_only() {
    local text="$1"
    # Remplacer les accents par leurs équivalents ASCII
    echo "$text" | \
        iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | \
        tr -cd '[:print:]\t' | \
        sed 's/[`'"'"'´]//g' | \
        sed 's/[""«»]//g' | \
        sed 's/[—–]/-/g' | \
        sed 's/…/.../g' | \
        sed 's/  */ /g'
}

# 2. Créer le fichier en ASCII pur
temp_file="/tmp/rakuten_temp.txt"
output="rakuten_ascii_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

# En-tête sans AUCUN accent
cat > "$temp_file" << 'HEADER_EOF'
EAN / ISBN / Code produit	Reference unique de l annonce * / Unique Advert Refence (SKU) *	Prix de vente * / Selling Price *	Prix d origine / RRP in euros	Qualite * / Condition *	Quantite * / Quantity *	Commentaire de l annonce * / Advert comment *	Commentaire prive de l annonce / Private Advert Comment	Type de Produit * / Type of Product *	Titre * / Title *	Description courte * / Short Description *	Resume du Livre ou Revue	Langue	Auteurs	Editeur	Date de parution	Classification Thematique	Poids en grammes / Weight in grammes	Taille / Size	Nombre de Pages / Number of pages	URL Image principale * / Main picture *	URLs Images Secondaires / Secondary Picture	Code operation promo / Promotion code	Colonne vide / void column	Description Annonce Personnalisee	Expedition, Retrait / Shipping, Pick Up	Telephone / Phone number	Code postale / Zip Code	Pays / Country
HEADER_EOF

# Récupérer les données
data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT 
    pm_isbn.meta_value,
    COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title, 'Sans titre'),
    CAST(IFNULL(pm_price.meta_value, '15.00') AS DECIMAL(10,2)),
    IFNULL(pm_authors.meta_value, 'Auteur'),
    IFNULL(pm_publisher.meta_value, 'Editeur'),
    IFNULL(pm_desc.meta_value, 'Livre occasion'),
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

# Parser
IFS=$'\t' read -r isbn titre prix auteurs editeur description condition poids pages image date_pub <<< "$data"

# Nettoyer en ASCII pur
titre=$(clean_ascii_only "$titre")
auteurs=$(clean_ascii_only "$auteurs")
editeur=$(clean_ascii_only "$editeur")
description=$(clean_ascii_only "$description")

# Mapper condition
case "$condition" in
    "neuf") qualite="N" ;;
    "comme neuf") qualite="CN" ;;
    *) qualite="BE" ;;
esac

# Prix
prix_public=$(printf "%.2f" $(echo "$prix * 1.3" | bc 2>/dev/null || echo "$prix"))

# Image HTTPS
[[ "$image" =~ ^http:// ]] && image="${image/http:/https:}"

# Ajouter les données
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
    "Francais" \
    "$auteurs" \
    "$editeur" \
    "$date_pub" \
    "Litterature francaise" \
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
    "France" >> "$temp_file"

# 3. Convertir en différents formats avec fins de ligne Windows
echo "📝 Création des versions :"
echo "─────────────────────────"

# Version 1 : ASCII avec CRLF (Windows)
unix2dos -n "$temp_file" "${output%.txt}_crlf.txt" 2>/dev/null || {
    sed 's/$/\r/' "$temp_file" > "${output%.txt}_crlf.txt"
}
echo "✅ ASCII + CRLF : ${output%.txt}_crlf.txt"

# Version 2 : Latin-1 avec CRLF
iconv -f UTF-8 -t ISO-8859-1//TRANSLIT "$temp_file" | sed 's/$/\r/' > "${output%.txt}_latin1_crlf.txt"
echo "✅ Latin-1 + CRLF : ${output%.txt}_latin1_crlf.txt"

# Version 3 : Windows-1252 avec CRLF
iconv -f UTF-8 -t WINDOWS-1252//TRANSLIT "$temp_file" | sed 's/$/\r/' > "${output%.txt}_win1252_crlf.txt"
echo "✅ Windows-1252 + CRLF : ${output%.txt}_win1252_crlf.txt"

# Version 4 : UTF-8 sans BOM avec CRLF (au cas où)
sed 's/$/\r/' "$temp_file" > "${output%.txt}_utf8_nobom_crlf.txt"
echo "✅ UTF-8 no BOM + CRLF : ${output%.txt}_utf8_nobom_crlf.txt"

rm -f "$temp_file"

echo ""
echo "📊 VÉRIFICATION :"
echo "───────────────"
for f in rakuten_ascii_*_crlf.txt rakuten_ascii_*_latin1_crlf.txt rakuten_ascii_*_win1252_crlf.txt; do
    [ -f "$f" ] && echo "$f : $(file -bi "$f") ($(wc -l < "$f") lignes)"
done

echo ""
echo "🚀 SOLUTIONS APPLIQUÉES :"
echo "────────────────────────"
echo "✓ Tous les accents remplacés par ASCII (é→e, è→e, à→a)"
echo "✓ Fins de ligne Windows (CRLF)"
echo "✓ Pas de caractères Unicode"
echo "✓ 4 encodages différents à tester"
echo ""
echo "💡 Si ça ne marche toujours pas :"
echo "   1. Demander un fichier exemple à Rakuten"
echo "   2. Utiliser leur API au lieu du CSV"
echo "   3. Exporter via Excel puis sauvegarder en CSV"
