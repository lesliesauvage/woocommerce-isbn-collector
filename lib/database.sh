#!/bin/bash
# Fonctions de base de données

# Source des utilitaires
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

# Fonction pour stocker une meta_value de manière sécurisée SANS DOUBLONS
store_meta() {
    local product_id=$1
    local meta_key=$2
    local meta_value=$3
    
    if [ -z "$meta_value" ]; then
        return
    fi
    
    local escaped_value=$(escape_sql "$meta_value")
    
    mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
        SET NAMES utf8mb4;
        INSERT INTO wp_${SITE_ID}_postmeta (post_id, meta_key, meta_value) 
        VALUES ($product_id, '$meta_key', '$escaped_value')
        ON DUPLICATE KEY UPDATE meta_value = VALUES(meta_value);" 2>/dev/null
}

# Test connexion MySQL
test_mysql_connection() {
    mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "SELECT 1" >/dev/null 2>&1
    return $?
}

# Récupérer les livres à traiter
get_books_to_process() {
    local where_clause="${1:-}"
    
    local query="
    SELECT 
        p.ID as product_id,
        isbn.meta_value as isbn,
        COALESCE(price.meta_value, 0) as price
    FROM wp_${SITE_ID}_posts p
    INNER JOIN wp_${SITE_ID}_postmeta isbn ON p.ID = isbn.post_id AND isbn.meta_key = '_isbn'
    LEFT JOIN wp_${SITE_ID}_postmeta price ON p.ID = price.post_id AND price.meta_key = '_price'
    WHERE p.post_type = 'product' 
    AND p.post_status = 'publish'"
    
    if [ -n "$where_clause" ]; then
        query="$query AND $where_clause"
    else
        # Par défaut, seulement les 3 livres de test
        query="$query AND p.ID IN (16091, 16089, 16087)"
    fi
    
    query="$query ORDER BY p.ID DESC"
    
    mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -N -e "$query"
}

# Récupérer une valeur meta
get_meta_value() {
    local product_id=$1
    local meta_key=$2
    
    mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $product_id AND meta_key = '$meta_key' LIMIT 1;"
}
