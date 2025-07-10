#!/bin/bash
# generate_all_isbn_list.sh - Génère la liste complète des ISBN

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

clear
echo "=== GÉNÉRATION LISTE COMPLÈTE DES ISBN ==="
echo "Date : $(date)"
echo "════════════════════════════════════════════════════════════════════════════"

# Nom du fichier de sortie
output_file="$SCRIPT_DIR/generer_liste_isbn_$(date +%Y%m%d_%H%M%S).txt"
output_csv="$SCRIPT_DIR/generer_liste_isbn_$(date +%Y%m%d_%H%M%S).csv"

echo ""
echo "📊 Analyse de la base de données..."

# Compter le total
total_books=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
   SELECT COUNT(DISTINCT p.ID) 
   FROM wp_${SITE_ID}_posts p 
   WHERE p.post_type = 'product' 
   AND p.post_status = 'publish'
" 2>/dev/null)

total_with_isbn=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
   SELECT COUNT(DISTINCT pm.post_id) 
   FROM wp_${SITE_ID}_postmeta pm 
   JOIN wp_${SITE_ID}_posts p ON p.ID = pm.post_id
   WHERE pm.meta_key = '_isbn' 
   AND pm.meta_value != '' 
   AND pm.meta_value IS NOT NULL
   AND p.post_type = 'product' 
   AND p.post_status = 'publish'
" 2>/dev/null)

echo "   📚 Total livres : $total_books"
echo "   📖 Avec ISBN : $total_with_isbn"
echo "   ❌ Sans ISBN : $((total_books - total_with_isbn))"
echo ""

# Menu
echo "Que voulez-vous générer ?"
echo ""
echo "1) Liste simple des ISBN (un par ligne)"
echo "2) Liste avec ID + ISBN"
echo "3) Liste complète CSV (ID, ISBN, Titre, Auteurs, Prix)"
echo "4) Statistiques détaillées des ISBN"
echo "5) ISBN invalides ou problématiques"
echo "6) Tous les formats ci-dessus"
echo ""
echo -n "Votre choix (1-6) : "
read choice

case $choice in
   1) # Liste simple
       echo ""
       echo "📝 Génération liste simple..."
       mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
           SELECT DISTINCT pm.meta_value
           FROM wp_${SITE_ID}_postmeta pm
           JOIN wp_${SITE_ID}_posts p ON p.ID = pm.post_id
           WHERE pm.meta_key = '_isbn' 
           AND pm.meta_value != '' 
           AND pm.meta_value IS NOT NULL
           AND p.post_type = 'product' 
           AND p.post_status = 'publish'
           ORDER BY pm.meta_value
       " 2>/dev/null > "$output_file"
       
       count=$(wc -l < "$output_file")
       echo "✅ Généré : $output_file"
       echo "   $count ISBN exportés"
       echo ""
       echo "Aperçu :"
       head -10 "$output_file"
       ;;
       
   2) # Liste avec ID
       echo ""
       echo "📝 Génération liste ID + ISBN..."
       mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
           SELECT DISTINCT 
               p.ID,
               pm.meta_value as isbn
           FROM wp_${SITE_ID}_postmeta pm
           JOIN wp_${SITE_ID}_posts p ON p.ID = pm.post_id
           WHERE pm.meta_key = '_isbn' 
           AND pm.meta_value != '' 
           AND pm.meta_value IS NOT NULL
           AND p.post_type = 'product' 
           AND p.post_status = 'publish'
           ORDER BY p.ID
       " 2>/dev/null > "$output_file"
       
       count=$(wc -l < "$output_file")
       echo "✅ Généré : $output_file"
       echo "   $count entrées exportées"
       echo ""
       echo "Aperçu :"
       head -10 "$output_file"
       ;;
       
   3) # CSV complet
       echo ""
       echo "📝 Génération CSV complet..."
       
       # En-tête CSV
       echo "ID,ISBN,Titre,Auteurs,Prix,Stock,Catégorie" > "$output_csv"
       
       # Données
       mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
           SELECT 
               p.ID,
               pm_isbn.meta_value as isbn,
               REPLACE(REPLACE(p.post_title, ',', ';'), '\"', '\'') as title,
               IFNULL(REPLACE(REPLACE(pm_authors.meta_value, ',', ';'), '\"', '\''), '') as authors,
               IFNULL(pm_price.meta_value, '0') as price,
               IFNULL(pm_stock.meta_value, '0') as stock,
               IFNULL(GROUP_CONCAT(t.name SEPARATOR ' > '), 'Non catégorisé') as category
           FROM wp_${SITE_ID}_posts p
           JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
           LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
           LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
           LEFT JOIN wp_${SITE_ID}_postmeta pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_stock'
           LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
           LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id AND tt.taxonomy = 'product_cat'
           LEFT JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
           WHERE p.post_type = 'product' 
           AND p.post_status = 'publish'
           AND pm_isbn.meta_value != ''
           GROUP BY p.ID
           ORDER BY p.ID
       " 2>/dev/null | while IFS=$'\t' read -r id isbn title authors price stock category; do
           echo "\"$id\",\"$isbn\",\"$title\",\"$authors\",\"$price\",\"$stock\",\"$category\"" >> "$output_csv"
       done
       
       count=$(($(wc -l < "$output_csv") - 1))
       echo "✅ Généré : $output_csv"
       echo "   $count livres exportés"
       echo ""
       echo "Aperçu :"
       head -5 "$output_csv" | column -t -s','
       ;;
       
   4) # Statistiques
       echo ""
       echo "📊 STATISTIQUES DES ISBN"
       echo "════════════════════════════════════════════════════════════════════════════"
       
       # Types d'ISBN
       echo ""
       echo "📈 Répartition par type :"
       mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
           SELECT 
               CASE 
                   WHEN LENGTH(REPLACE(meta_value, '-', '')) = 10 THEN 'ISBN-10'
                   WHEN LENGTH(REPLACE(meta_value, '-', '')) = 13 THEN 'ISBN-13'
                   ELSE 'Format invalide'
               END as type_isbn,
               COUNT(*) as nombre,
               CONCAT(ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta WHERE meta_key = '_isbn' AND meta_value != ''), 1), '%') as pourcentage
           FROM wp_${SITE_ID}_postmeta
           WHERE meta_key = '_isbn' AND meta_value != ''
           GROUP BY type_isbn
           ORDER BY nombre DESC
       " 2>/dev/null
       
       # ISBN dupliqués
       echo ""
       echo "🔄 ISBN dupliqués :"
       duplicates=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
           SELECT COUNT(*) FROM (
               SELECT meta_value, COUNT(*) as cnt
               FROM wp_${SITE_ID}_postmeta
               WHERE meta_key = '_isbn' AND meta_value != ''
               GROUP BY meta_value
               HAVING cnt > 1
           ) as dup
       " 2>/dev/null)
       echo "   $duplicates ISBN apparaissent plusieurs fois"
       
       if [ "$duplicates" -gt 0 ]; then
           echo ""
           echo "   Top 5 des ISBN dupliqués :"
           mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
               SELECT 
                   meta_value as ISBN,
                   COUNT(*) as 'Nombre de fois',
                   GROUP_CONCAT(post_id ORDER BY post_id SEPARATOR ', ') as 'IDs des produits'
               FROM wp_${SITE_ID}_postmeta
               WHERE meta_key = '_isbn' AND meta_value != ''
               GROUP BY meta_value
               HAVING COUNT(*) > 1
               ORDER BY COUNT(*) DESC
               LIMIT 5
           " 2>/dev/null
       fi
       
       # ISBN avec/sans tirets
       echo ""
       echo "📏 Format des ISBN :"
       mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
           SELECT 
               CASE 
                   WHEN meta_value LIKE '%-%' THEN 'Avec tirets'
                   ELSE 'Sans tirets'
               END as format,
               COUNT(*) as nombre
           FROM wp_${SITE_ID}_postmeta
           WHERE meta_key = '_isbn' AND meta_value != ''
           GROUP BY format
       " 2>/dev/null
       ;;
       
   5) # ISBN problématiques
       echo ""
       echo "🚨 Recherche des ISBN problématiques..."
       
       output_problems="$SCRIPT_DIR/generer_isbn_problemes_$(date +%Y%m%d_%H%M%S).txt"
       
       # ISBN trop courts ou trop longs
       echo "=== ISBN LONGUEUR INVALIDE ===" > "$output_problems"
       mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
           SELECT 
               post_id,
               meta_value as isbn,
               LENGTH(REPLACE(meta_value, '-', '')) as longueur
           FROM wp_${SITE_ID}_postmeta
           WHERE meta_key = '_isbn' 
           AND meta_value != ''
           AND LENGTH(REPLACE(meta_value, '-', '')) NOT IN (10, 13)
       " 2>/dev/null >> "$output_problems"
       
       # ISBN avec caractères non numériques (sauf tirets et X final)
       echo -e "\n=== ISBN AVEC CARACTÈRES INVALIDES ===" >> "$output_problems"
       mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
           SELECT 
               post_id,
               meta_value as isbn
           FROM wp_${SITE_ID}_postmeta
           WHERE meta_key = '_isbn' 
           AND meta_value != ''
           AND meta_value REGEXP '[^0-9X-]|X[^$]'
       " 2>/dev/null >> "$output_problems"
       
       # ISBN dupliqués
       echo -e "\n=== ISBN DUPLIQUÉS ===" >> "$output_problems"
       mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
           SELECT 
               meta_value as isbn,
               COUNT(*) as occurrences,
               GROUP_CONCAT(post_id ORDER BY post_id SEPARATOR ', ') as post_ids
           FROM wp_${SITE_ID}_postmeta
           WHERE meta_key = '_isbn' AND meta_value != ''
           GROUP BY meta_value
           HAVING COUNT(*) > 1
           ORDER BY COUNT(*) DESC
       " 2>/dev/null >> "$output_problems"
       
       echo "✅ Généré : $output_problems"
       echo ""
       echo "Résumé des problèmes :"
       grep -c "INVALIDE" "$output_problems" | xargs echo "   ISBN longueur invalide :"
       grep -E "^[0-9]+.*[^0-9X-]" "$output_problems" | wc -l | xargs echo "   ISBN caractères invalides :"
       grep -c "occurrences" "$output_problems" | xargs echo "   ISBN dupliqués :"
       ;;
       
   6) # Tout générer
       echo ""
       echo "🚀 Génération de TOUS les formats..."
       
       # Réexécuter le script pour chaque option
       for opt in 1 2 3 4 5; do
           echo ""
           echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
           echo "$opt" | "$SCRIPT_DIR/generate_all_isbn_list.sh"
       done
       ;;
       
   *)
       echo "❌ Choix invalide"
       exit 1
       ;;
esac

echo ""
echo "════════════════════════════════════════════════════════════════════════════"
echo "✅ Génération terminée : $(date)"
echo ""
echo "📁 Fichiers générés dans : $SCRIPT_DIR"
ls -la "$SCRIPT_DIR"/generer_*isbn* 2>/dev/null | tail -5
