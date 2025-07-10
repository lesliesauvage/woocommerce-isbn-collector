#!/bin/bash
echo "[START: category_functions.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# lib/category_functions.sh - Fonctions pour gérer les catégories WordPress

# Obtenir toutes les catégories avec leur hiérarchie
get_all_categories_with_hierarchy() {
    debug_echo "[DEBUG] Récupération des catégories AVEC hiérarchie..."
    
    # Récupérer TOUTES les catégories (pas seulement les finales)
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    WITH RECURSIVE category_path AS (
        -- Cas de base : catégories sans parent
        SELECT 
            t.term_id,
            t.name,
            tt.parent,
            CAST(t.name AS CHAR(1000)) AS path,
            t.term_id AS final_id,
            t.name AS final_name
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE tt.taxonomy = 'product_cat' 
        AND tt.parent = 0
        AND t.term_id NOT IN (15, 16)
        
        UNION ALL
        
        -- Cas récursif : ajouter les enfants
        SELECT 
            t.term_id,
            t.name,
            tt.parent,
            CONCAT(cp.path, ' > ', t.name) AS path,
            t.term_id AS final_id,
            t.name AS final_name
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        JOIN category_path cp ON tt.parent = cp.term_id
        WHERE tt.taxonomy = 'product_cat'
    )
    SELECT CONCAT(path, ' (ID:', final_id, ')') AS category_line
    FROM category_path
    WHERE final_id NOT IN (
        SELECT DISTINCT parent 
        FROM wp_${SITE_ID}_term_taxonomy 
        WHERE taxonomy = 'product_cat' AND parent != 0
    )
    ORDER BY path
    " 2>/dev/null
}

# Obtenir la hiérarchie complète d'une catégorie
get_category_with_parent() {
    local cat_id=$1
    debug_echo "[DEBUG] Recherche hiérarchie pour cat_id='$cat_id'"
    [ -z "$cat_id" ] && { debug_echo "[DEBUG] ERREUR : cat_id vide !"; return; }
    
    # Fonction récursive pour remonter toute la hiérarchie
    get_full_path() {
        local id=$1
        local result=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT t.name, tt.parent
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE t.term_id = $id" 2>/dev/null)
        
        if [ -n "$result" ]; then
            local name=$(echo "$result" | cut -f1)
            local parent=$(echo "$result" | cut -f2)
            
            if [ "$parent" != "0" ] && [ -n "$parent" ]; then
                local parent_path=$(get_full_path $parent)
                echo "$parent_path > $name"
            else
                echo "$name"
            fi
        fi
    }
    
    local full_path=$(get_full_path $cat_id)
    debug_echo "[DEBUG] Hiérarchie trouvée : '$full_path'"
    echo "$full_path"
}

# Appliquer une catégorie à un produit
apply_category_to_product() {
    local post_id=$1
    local category_id=$2
    local category_name=$3
    
    echo -n "💾 Application... "
    
    # Obtenir le term_taxonomy_id
    debug_echo "[DEBUG] Recherche term_taxonomy_id pour term_id=$category_id..."
    local term_taxonomy_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
    WHERE term_id = $category_id AND taxonomy = 'product_cat'
    " 2>/dev/null)
    
    debug_echo "[DEBUG] term_taxonomy_id trouvé : '$term_taxonomy_id'"
    
    if [ -z "$term_taxonomy_id" ]; then
        debug_echo "[DEBUG] ERREUR : term_taxonomy_id non trouvé pour term_id=$category_id"
        echo -e "${RED}❌ Catégorie introuvable !${NC}"
        return 1
    fi
    
    # Supprimer anciennes catégories
    debug_echo "[DEBUG] Suppression des anciennes catégories..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    DELETE FROM wp_${SITE_ID}_term_relationships 
    WHERE object_id = $post_id 
    AND term_taxonomy_id IN (
        SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
        WHERE taxonomy = 'product_cat'
    )
    " 2>/dev/null
    
    # Ajouter nouvelle catégorie
    debug_echo "[DEBUG] Ajout de la nouvelle catégorie term_taxonomy_id=$term_taxonomy_id..."
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    INSERT IGNORE INTO wp_${SITE_ID}_term_relationships (object_id, term_taxonomy_id)
    VALUES ($post_id, $term_taxonomy_id)
    " 2>/dev/null
    
    echo -e "${GREEN}✅ Fait!${NC}"
    
    # Stocker la catégorie de référence Google Books (si elle existe)
    local g_category=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT meta_value FROM wp_${SITE_ID}_postmeta 
    WHERE post_id = $post_id AND meta_key = '_g_categories' LIMIT 1" 2>/dev/null)
    
    if [ -n "$g_category" ] && [ "$g_category" != "NULL" ]; then
        safe_store_meta "$post_id" "_g_categorie_reference" "$g_category"
        debug_echo "[DEBUG] Catégorie Google Books stockée pour référence : $g_category"
    fi
    
    return 0
}

echo "[END: category_functions.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
