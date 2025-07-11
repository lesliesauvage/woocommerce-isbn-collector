#!/bin/bash
source config/settings.sh

echo "🖼️ VÉRIFICATION COMPLÈTE DES IMAGES"
echo "════════════════════════════════════════════"

# Demander l'ID ou ISBN
echo -n "Entrez l'ID du livre ou ISBN : "
read input

# Déterminer si c'est un ID ou ISBN
if [[ "$input" =~ ^[0-9]+$ ]] && [ ${#input} -lt 10 ]; then
    post_id="$input"
else
    post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key='_sku' AND meta_value='$input' LIMIT 1")
fi

echo ""
echo "📚 Livre ID: $post_id"
echo ""

# TOUTES les variables d'images possibles
image_fields=(
    # Google Books
    "_g_smallThumbnail"
    "_g_thumbnail"
    "_g_small"
    "_g_medium"
    "_g_large"
    "_g_extraLarge"
    
    # ISBNdb
    "_i_image"
    
    # Open Library
    "_o_cover_small"
    "_o_cover_medium"
    "_o_cover_large"
    
    # WordPress
    "_thumbnail_id"
    "_product_image_gallery"
    "_wp_attached_file"
    "_wp_attachment_metadata"
    
    # Autres
    "_image_alt"
    "_image_title"
    "_best_cover_image"
    
    # Images supplémentaires possibles
    "_image_1"
    "_image_2"
    "_image_3"
    "_image_4"
    "_image_5"
    "_image_6"
)

echo "📋 IMAGES TROUVÉES :"
echo "────────────────────────────────────────────"

count=0
for field in "${image_fields[@]}"; do
    value=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id AND meta_key='$field' LIMIT 1")
    
    if [ -n "$value" ] && [ "$value" != "-" ]; then
        ((count++))
        echo "$count. $field ="
        echo "   $value"
        echo ""
    fi
done

echo ""
echo "📊 TOTAL : $count images trouvées"

# Vérifier aussi la galerie d'images
gallery=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT meta_value FROM wp_${SITE_ID}_postmeta 
    WHERE post_id=$post_id AND meta_key='_product_image_gallery' LIMIT 1")

if [ -n "$gallery" ] && [ "$gallery" != "-" ]; then
    echo ""
    echo "🖼️ GALERIE D'IMAGES : $gallery"
fi
