#!/bin/bash
# Fonctions de base de données - VERSION CORRIGÉE

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
    
    # IMPORTANT : Ne pas tronquer les URLs !
    local escaped_value=$(printf '%s' "$meta_value" | sed "s/'/\\\\'/g")
    
    # D'abord vérifier si existe déjà
    local existing=$(mysql --default-character-set=utf8mb4 -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_id FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $product_id AND meta_key = '$meta_key' 
        LIMIT 1;" 2>/dev/null)
    
    if [ -n "$existing" ]; then
        # Mise à jour - SANS LIMITE DE LONGUEUR
        mysql --default-character-set=utf8mb4 -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            SET NAMES utf8mb4;
            UPDATE wp_${SITE_ID}_postmeta 
            SET meta_value = '$escaped_value'
            WHERE meta_id = $existing;" 2>/dev/null
    else
        # Insertion - SANS LIMITE DE LONGUEUR
        mysql --default-character-set=utf8mb4 -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            SET NAMES utf8mb4;
            INSERT INTO wp_${SITE_ID}_postmeta (post_id, meta_key, meta_value) 
            VALUES ($product_id, '$meta_key', '$escaped_value');" 2>/dev/null
    fi
}

# Test connexion MySQL
test_mysql_connection() {
    mysql --default-character-set=utf8mb4 -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" >/dev/null 2>&1
    return $?
}

# Récupérer les livres à traiter - CORRIGÉ pour gérer le paramètre WHERE
get_books_to_process() {
    local where_clause="${1:-}"
    
    # CORRECTION : Vérifier les doublons d'ISBN et prendre seulement le plus récent
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
    
    # CORRECTION : Ajouter la clause WHERE supplémentaire si fournie
    if [ -n "$where_clause" ]; then
        query="$query AND $where_clause"
    fi
    
    # IMPORTANT : Grouper par ISBN pour éviter les doublons
    query="$query GROUP BY isbn.meta_value ORDER BY p.ID DESC"
    
    # DEBUG : Afficher la requête si mode DEBUG activé
    [ "$DEBUG" = "1" ] && echo "[DEBUG] Query: $query" >&2
    
    mysql --default-character-set=utf8mb4 -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -N -e "$query"
}

# Récupérer une valeur meta
get_meta_value() {
    local product_id=$1
    local meta_key=$2
    
    mysql --default-character-set=utf8mb4 -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $product_id AND meta_key = '$meta_key' LIMIT 1;"
}