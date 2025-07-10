#!/bin/bash
echo "[START: fixed_store_meta.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# Fonction corrigée pour stocker les métadonnées

fixed_store_meta() {
    local post_id="$1"
    local meta_key="$2"
    local meta_value="$3"
    
    # Validations
    [ -z "$post_id" ] && { echo "❌ post_id manquant" >&2; return 1; }
    [ -z "$meta_key" ] && { echo "❌ meta_key manquante" >&2; return 1; }
    
    # Échapper la valeur pour MySQL
    local escaped_value=$(echo "$meta_value" | sed "s/'/\\\\'/g")
    
    # Méthode simple et fiable : DELETE puis INSERT
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << SQL 2>/dev/null
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id = $post_id AND meta_key = '$meta_key';
INSERT INTO wp_${SITE_ID}_postmeta (post_id, meta_key, meta_value) 
VALUES ($post_id, '$meta_key', '$escaped_value');
SQL
    
    local result=$?
    [ "$DEBUG" = "1" ] && echo "[DEBUG] Stocké: $meta_key = ${meta_value:0:50}..." >&2
    return $result
}

echo "[END: fixed_store_meta.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
