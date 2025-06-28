#!/bin/bash

echo "=== AJOUT D'UN NOUVEAU LIVRE PAR ISBN ==="
echo ""

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"

# Demander l'ISBN
read -p "Entrez l'ISBN du livre à ajouter : " isbn

# Nettoyer l'ISBN (enlever les tirets)
isbn=$(echo "$isbn" | tr -d '-')

# Vérifier le format
if [[ ! "$isbn" =~ ^[0-9]{10}$ ]] && [[ ! "$isbn" =~ ^[0-9]{13}$ ]]; then
    echo "Format d'ISBN invalide"
    exit 1
fi

echo ""
echo "ISBN : $isbn"
echo "Recherche des informations..."

# Appeler Google Books pour avoir un titre
source "$SCRIPT_DIR/apis/google_books.sh"
google_data=$(fetch_google_books "$isbn")

if [ ! -z "$google_data" ]; then
    title=$(echo "$google_data" | grep -oP 'title:[^|]+' | cut -d':' -f2)
    if [ -z "$title" ]; then
        title="Livre ISBN $isbn"
    fi
else
    title="Livre ISBN $isbn"
fi

echo "Titre trouvé : $title"

# Créer le produit dans WordPress
echo ""
echo "Création du produit dans WordPress..."

# Générer un slug unique
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
slug="${slug}-${isbn}"

# Date actuelle
current_date=$(date '+%Y-%m-%d %H:%M:%S')

# Insérer le produit
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
INSERT INTO wp_28_posts (
    post_author,
    post_date,
    post_date_gmt,
    post_content,
    post_title,
    post_excerpt,
    post_status,
    comment_status,
    ping_status,
    post_password,
    post_name,
    to_ping,
    pinged,
    post_modified,
    post_modified_gmt,
    post_content_filtered,
    post_parent,
    guid,
    menu_order,
    post_type,
    post_mime_type,
    comment_count
) VALUES (
    1,
    '$current_date',
    '$current_date',
    '',
    '$title',
    '',
    'publish',
    'open',
    'closed',
    '',
    '$slug',
    '',
    '',
    '$current_date',
    '$current_date',
    '',
    0,
    'https://votre-site.com/?post_type=product&p=',
    0,
    'product',
    '',
    0
);
EOF

# Récupérer l'ID du produit créé
product_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "SELECT LAST_INSERT_ID();")

if [ -z "$product_id" ] || [ "$product_id" = "0" ]; then
    echo "Erreur lors de la création du produit"
    exit 1
fi

echo "✓ Produit créé avec l'ID : $product_id"

# Ajouter les métadonnées de base
echo "Ajout des métadonnées..."

mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
-- ISBN
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_isbn', '$isbn');

-- Type de produit
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_product_type', 'simple');

-- Prix (à 0 par défaut)
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_price', '0');
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_regular_price', '0');

-- Stock
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_stock_status', 'instock');
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_manage_stock', 'no');

-- Visibilité
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_visibility', 'visible');
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_featured', 'no');

-- Virtual et downloadable
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_virtual', 'no');
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_downloadable', 'no');

-- SKU
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES ($product_id, '_sku', '$isbn');
EOF

echo "✓ Métadonnées ajoutées"

# Lancer la collecte de données
echo ""
echo "=== LANCEMENT DE LA COLLECTE DE DONNÉES ==="
echo ""

# Créer un script temporaire pour ce livre
cp "$SCRIPT_DIR/collect_api_data.sh" "$SCRIPT_DIR/collect_single_book_temp.sh"
sed -i "s/# query=\"\$query AND p.ID IN (16091, 16089, 16087)\"/query=\"\$query AND p.ID = $product_id\"/" "$SCRIPT_DIR/collect_single_book_temp.sh"

# Lancer la collecte
"$SCRIPT_DIR/collect_single_book_temp.sh"

# Nettoyer
rm -f "$SCRIPT_DIR/collect_single_book_temp.sh"

echo ""
echo "=== LIVRE AJOUTÉ AVEC SUCCÈS ==="
echo "  - ID : $product_id"
echo "  - ISBN : $isbn"
echo "  - Titre : $title"
echo ""
echo "Le livre est maintenant dans votre base de données avec toutes les informations collectées !"
