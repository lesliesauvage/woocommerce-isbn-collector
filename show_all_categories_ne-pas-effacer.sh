#!/bin/bash
echo "[START: show_all_categories_ne-pas-effacer.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

source config/settings.sh

clear
echo "=== ARBORESCENCE COMPLÈTE DE TOUTES LES CATÉGORIES ==="
echo "Total : $(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "SELECT COUNT(*) FROM wp_${SITE_ID}_term_taxonomy WHERE taxonomy = 'product_cat'") catégories"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Fonction récursive pour afficher l'arbre
show_tree() {
    local parent_id=$1
    local indent="$2"
    
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT t.term_id, t.name
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE tt.taxonomy = 'product_cat' AND tt.parent = $parent_id
        ORDER BY t.name" | while IFS=$'\t' read -r id name; do
        
        echo "${indent}├─ $name"
        
        # Appel récursif pour les enfants
        show_tree "$id" "${indent}│  "
    done
}

# Afficher toutes les catégories principales
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT t.term_id, t.name
    FROM wp_${SITE_ID}_terms t
    JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
    WHERE tt.taxonomy = 'product_cat' AND tt.parent = 0
    ORDER BY t.name" | while IFS=$'\t' read -r id name; do
    
    echo "📁 $name"
    show_tree "$id" ""
    echo ""
done

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "EXPORT DANS UN FICHIER :"
echo ""

# Export dans un fichier pour analyse complète
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    WITH RECURSIVE cat_path AS (
        SELECT 
            t.term_id,
            t.name,
            tt.parent,
            CAST(t.name AS CHAR(500)) as path,
            0 as level
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        WHERE tt.taxonomy = 'product_cat' AND tt.parent = 0
        
        UNION ALL
        
        SELECT 
            t.term_id,
            t.name,
            tt.parent,
            CONCAT(cp.path, ' > ', t.name),
            cp.level + 1
        FROM wp_${SITE_ID}_terms t
        JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
        JOIN cat_path cp ON tt.parent = cp.term_id
        WHERE tt.taxonomy = 'product_cat'
    )
    SELECT 
        level as 'Niveau',
        path as 'Chemin complet'
    FROM cat_path
    ORDER BY path;" > arbre_complet.txt

echo "✅ Arbre complet exporté dans : arbre_complet.txt"
echo "   Taille du fichier : $(wc -l < arbre_complet.txt) lignes"
echo ""
echo "Pour voir tout : cat arbre_complet.txt"
echo "Pour voir page par page : less arbre_complet.txt"
echo "Pour chercher : grep 'terme' arbre_complet.txt"

echo "[END: show_all_categories_ne-pas-effacer.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
