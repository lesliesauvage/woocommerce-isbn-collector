#!/bin/bash
echo "[START: reset_all_categories.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

source config/settings.sh

clear
echo "=== RÉINITIALISATION COMPLÈTE DES CATÉGORIES ==="
echo ""
echo "⚠️  ATTENTION : Cette action va :"
echo "   - Supprimer TOUTES les catégories de produits"
echo "   - Supprimer TOUTES les associations produits/catégories"
echo "   - Recréer les catégories depuis zéro"
echo ""
echo "Tapez 'RESET TOTAL' pour confirmer : "
read confirmation

if [ "$confirmation" != "RESET TOTAL" ]; then
    echo "❌ Annulé"
    exit 0
fi

echo ""
echo "🗑️  SUPPRESSION TOTALE EN COURS..."

# 1. Supprimer toutes les relations
echo "1. Suppression des relations produits/catégories..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    DELETE tr FROM wp_${SITE_ID}_term_relationships tr
    INNER JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
    WHERE tt.taxonomy = 'product_cat';"

# 2. Supprimer les métadonnées
echo "2. Suppression des métadonnées..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    DELETE tm FROM wp_${SITE_ID}_termmeta tm
    INNER JOIN wp_${SITE_ID}_term_taxonomy tt ON tm.term_id = tt.term_id
    WHERE tt.taxonomy = 'product_cat';"

# 3. Supprimer les taxonomies
echo "3. Suppression des taxonomies..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    DELETE FROM wp_${SITE_ID}_term_taxonomy WHERE taxonomy = 'product_cat';"

# 4. Supprimer les termes
echo "4. Suppression des termes orphelins..."
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    DELETE t FROM wp_${SITE_ID}_terms t
    LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
    WHERE tt.term_id IS NULL;"

echo ""
echo "✅ Base nettoyée complètement"

# Vérification
count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT COUNT(*) FROM wp_${SITE_ID}_term_taxonomy WHERE taxonomy = 'product_cat'")
echo "Catégories restantes : $count (devrait être 0)"

echo ""
echo "La base est maintenant prête pour recréer les catégories proprement."
echo ""
echo "Lancez ensuite le script de création des catégories ECOLIVRES."

echo "[END: reset_all_categories.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
