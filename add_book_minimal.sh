#!/bin/bash

isbn=$1
if [ -z "$isbn" ]; then
    read -p "ISBN : " isbn
fi

# Créer le produit
echo "Création du livre ISBN $isbn..."

# Exécuter INSERT et récupérer l'ID dans la même session
# Utiliser un titre temporaire sans apostrophe pour éviter les erreurs SQL
id=$(mysql -h"localhost" -u"wordpress" -p"e96e30c154b7a661211a793bbac6416dcbaf9843ff19fb54" "savoir" << SQL
INSERT INTO wp_28_posts (
    post_author, post_date, post_date_gmt, post_title, 
    post_status, post_name, post_type, post_content
) VALUES (
    1, NOW(), NOW(), 'Livre $isbn',
    'publish', 'livre-$isbn', 'product', ''
);
SELECT LAST_INSERT_ID();
SQL
)

# Nettoyer l'output pour avoir juste l'ID
id=$(echo "$id" | tail -1)

if [ -z "$id" ] || [ "$id" = "0" ]; then
    echo "❌ Erreur : Impossible de créer le livre"
    exit 1
fi

echo "✓ Livre créé avec ID: $id"

# Ajouter les métadonnées
echo "Ajout des métadonnées..."
mysql -h"localhost" -u"wordpress" -p"e96e30c154b7a661211a793bbac6416dcbaf9843ff19fb54" "savoir" << SQL
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES 
($id, '_isbn', '$isbn'),
($id, '_sku', '$isbn'),
($id, '_price', '0'),
($id, '_regular_price', '0'),
($id, '_stock', '1'),
($id, '_stock_status', 'instock'),
($id, '_manage_stock', 'no'),
($id, '_virtual', 'no'),
($id, '_downloadable', 'no');
SQL

echo "✓ Métadonnées ajoutées"
echo ""
echo "Livre créé avec succès !"
echo "ID : $id"
echo "ISBN : $isbn"
echo ""
echo "Le titre sera mis à jour automatiquement lors de la collecte des données."
echo "Lancez maintenant : ./run.sh puis option 3 et entrez l'ISBN $isbn"