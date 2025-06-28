#!/bin/bash

isbn=$1
if [ -z "$isbn" ]; then
    read -p "ISBN : " isbn
fi

# Créer le produit
echo "Création du livre ISBN $isbn..."

# 1. Insérer dans wp_28_posts
mysql -h"localhost" -u"wordpress" -p"e96e30c154b7a661211a793bbac6416dcbaf9843ff19fb54" "savoir" << SQL
INSERT INTO wp_28_posts (
    post_author, post_date, post_date_gmt, post_title, 
    post_status, post_name, post_type, post_content
) VALUES (
    1, NOW(), NOW(), 'Livre $isbn',
    'publish', 'livre-$isbn', 'product', ''
);
SQL

# 2. Récupérer l'ID
id=$(mysql -h"localhost" -u"wordpress" -p"e96e30c154b7a661211a793bbac6416dcbaf9843ff19fb54" "savoir" -sN -e "SELECT LAST_INSERT_ID();")

# 3. Ajouter juste l'ISBN et les trucs de base
mysql -h"localhost" -u"wordpress" -p"e96e30c154b7a661211a793bbac6416dcbaf9843ff19fb54" "savoir" << SQL
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES 
($id, '_isbn', '$isbn'),
($id, '_sku', '$isbn'),
($id, '_price', '0'),
($id, '_regular_price', '0'),
($id, '_stock', '1');
SQL

echo "✓ Livre créé avec ID: $id"
echo ""
echo "Maintenant lancez la collecte pour enrichir les données !"
