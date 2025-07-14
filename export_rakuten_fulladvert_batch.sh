#!/bin/bash
source config/settings.sh

output="rakuten_fulladvert_batch_$(date +%Y%m%d_%H%M%S).csv"

echo "📤 EXPORT RAKUTEN WS_FULLADVERT - BATCH"
echo "════════════════════════════════════════════════════════════════"
echo ""

# En-tête
echo "sku;barcode;price;quantity;quality;advert_comment;refurbished;URL images" > "$output"

# Récupérer tous les livres avec ISBN
isbns=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT DISTINCT pm.meta_value 
FROM wp_${SITE_ID}_postmeta pm
JOIN wp_${SITE_ID}_posts p ON pm.post_id = p.ID
WHERE pm.meta_key = '_isbn' 
AND pm.meta_value != ''
AND p.post_status = 'publish'
LIMIT 100" 2>/dev/null)

count=0
while read -r isbn; do
    [ -z "$isbn" ] && continue
    
    # Récupérer les données
    data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT 
        CAST(IFNULL(pm_price.meta_value, '15.00') AS DECIMAL(10,2)),
        IFNULL(pm_stock.meta_value, '1'),
        IFNULL(pm_condition.meta_value, 'bon'),
        IFNULL(pm_image.meta_value, '')
    FROM wp_${SITE_ID}_posts p
    JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_stock'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
    WHERE pm_isbn.meta_value = '$isbn'
    LIMIT 1" 2>/dev/null)
    
    [ -z "$data" ] && continue
    
    # Parser
    IFS=$'\t' read -r price quantity condition_text image <<< "$data"
    
    # Mapper condition
    case "$condition_text" in
        "neuf") quality="N" ;;
        "comme neuf") quality="CN" ;;
        "très bon"|"tres bon") quality="TBE" ;;
        "bon") quality="BE" ;;
        *) quality="EC" ;;
    esac
    
    # Formater
    price=$(echo "$price" | sed 's/\./,/')
    quantity=$(echo "$quantity" | sed 's/[^0-9]//g')
    [[ -z "$quantity" || "$quantity" -eq 0 ]] && quantity="1"
    [[ "$quantity" -gt 999 ]] && quantity="999"
    
    # Image HTTPS
    [[ "$image" =~ ^http:// ]] && image="${image/http:/https:}"
    
    # Ajouter la ligne
    echo "${isbn};${isbn};${price};${quantity};${quality};Envoi rapide et soigne;0;${image}" >> "$output"
    
    ((count++))
    echo -ne "\r✓ Traités : $count livres"
done <<< "$isbns"

echo ""
echo ""
echo "✅ Export terminé : $output"
echo "📊 Total : $count livres exportés"
echo ""
echo "🚀 Prêt pour import batch WS_FULLADVERT !"
