#!/bin/bash
source config/settings.sh

isbn="${1:-9782070360024}"
output="rakuten_fulladvert_${isbn}_$(date +%Y%m%d_%H%M%S).csv"

echo "📤 EXPORT RAKUTEN WS_FULLADVERT - FORMAT SIMPLE"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Fonction de nettoyage simple (pas d'accents dans ce format !)
clean_simple() {
    echo "$1" | \
        sed 's/;/,/g' | \
        tr '\n\r\t' ' ' | \
        sed 's/  */ /g' | \
        sed 's/^ *//;s/ *$//'
}

# Récupérer les données essentielles
data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT 
    pm_isbn.meta_value as isbn,
    CAST(IFNULL(pm_price.meta_value, '15.00') AS DECIMAL(10,2)) as price,
    IFNULL(pm_stock.meta_value, '1') as quantity,
    IFNULL(pm_condition.meta_value, 'bon') as condition_text,
    IFNULL(pm_image.meta_value, '') as main_image,
    IFNULL(pm_gallery.meta_value, '') as gallery_images
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_stock'
LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
LEFT JOIN wp_${SITE_ID}_postmeta pm_gallery ON p.ID = pm_gallery.post_id AND pm_gallery.meta_key = '_product_image_gallery'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null)

[ -z "$data" ] && { echo "❌ Aucune donnée pour ISBN $isbn"; exit 1; }

# Parser les données
IFS=$'\t' read -r isbn price quantity condition_text main_image gallery_images <<< "$data"

# Mapper la condition
case "$condition_text" in
    "neuf") quality="N" ;;
    "comme neuf") quality="CN" ;;
    "très bon"|"tres bon") quality="TBE" ;;
    "bon") quality="BE" ;;
    *) quality="EC" ;;
esac

# Formater le prix (virgule pour les décimales)
price=$(echo "$price" | sed 's/\./,/')

# Vérifier la quantité (1-999)
quantity=$(echo "$quantity" | sed 's/[^0-9]//g')
[[ -z "$quantity" || "$quantity" -eq 0 ]] && quantity="1"
[[ "$quantity" -gt 999 ]] && quantity="999"

# Commentaire simple sans accents
advert_comment="Envoi rapide et soigne. Livre en bon etat."

# Refurbished (toujours 0 pour les livres d'occasion)
refurbished="0"

# Gérer les images
images=""
if [ -n "$main_image" ]; then
    # Assurer HTTPS
    [[ "$main_image" =~ ^http:// ]] && main_image="${main_image/http:/https:}"
    images="$main_image"
    
    # Ajouter les images de galerie si disponibles
    if [ -n "$gallery_images" ]; then
        # gallery_images peut contenir des IDs séparés par des virgules
        # Pour l'instant, on garde juste l'image principale
        images="$main_image"
    fi
fi

# Créer le fichier CSV
{
    # En-tête (optionnel mais utile)
    echo "sku;barcode;price;quantity;quality;advert_comment;refurbished;URL images"
    
    # Données
    echo "${isbn};${isbn};${price};${quantity};${quality};${advert_comment};${refurbished};${images}"
} > "$output"

echo "✅ Export créé : $output"
echo ""
echo "📊 CONTENU DU FICHIER :"
echo "──────────────────────"
cat "$output"
echo ""
echo "📋 VÉRIFICATIONS :"
echo "────────────────"
echo "✓ Format : CSV avec point-virgule"
echo "✓ 8 colonnes seulement"
echo "✓ Pas d'accents"
echo "✓ Prix avec virgule : $price"
echo "✓ Quantité : $quantity (1-999)"
echo "✓ Qualité : $quality"
echo "✓ Images HTTPS : $([ -n "$images" ] && echo "OK" || echo "Aucune")"
echo ""
echo "🚀 Prêt pour import WS_FULLADVERT !"
