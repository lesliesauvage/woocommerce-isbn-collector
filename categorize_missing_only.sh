#!/bin/bash
source config/settings.sh

clear
echo "=== CATÉGORISATION DES LIVRES MANQUÉS ==="
echo "Date : $(date)"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

# Liste des ISBN non catégorisés (sans doublons)
missing_isbn=(
    "2020086298"  # Une vie bouleversée
    "202013554X"  # Escher
    "2020326205"  # Et c'est comme ça
    "2020015048"  # L'Herbe et le Ciel
    "2035054230"  # Lire la peinture
    "2020115816"  # Pour comprendre les musiques
    "2020211076"  # Questions de vie
    "2020413914"  # La Mort
    "2040166319"  # Manifeste
    "2040039120"  # Des rythmes biologiques
)

# Compter
total=${#missing_isbn[@]}
success=0
failed=0

echo "📚 $total livres à catégoriser"
echo ""
echo "Appuyez sur ENTRÉE pour commencer..."
read

# Créer un log spécifique
log_file="categorize_missing_$(date +%Y%m%d_%H%M%S).log"

# Traiter chaque ISBN
for i in "${!missing_isbn[@]}"; do
    isbn="${missing_isbn[$i]}"
    num=$((i + 1))
    
    {
        echo ""
        echo "════════════════════════════════════════════════════════════════════════════"
        echo "📖 LIVRE $num/$total - ISBN: $isbn"
        echo "════════════════════════════════════════════════════════════════════════════"
    } | tee -a "$log_file"
    
    # Vérifier d'abord si pas déjà catégorisé entre temps
    already_done=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) 
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm ON p.ID = pm.post_id
        JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        WHERE pm.meta_key = '_isbn' 
        AND pm.meta_value = '$isbn'
        AND tt.taxonomy = 'product_cat'
    " 2>/dev/null)
    
    if [ "$already_done" -gt 0 ]; then
        echo "✅ Déjà catégorisé (fait entre temps)" | tee -a "$log_file"
        ((success++))
        continue
    fi
    
    # Lancer la catégorisation
    echo "" | tee -a "$log_file"
    
    # Désactiver temporairement le clear pour capturer tout
    cp smart_categorize_dual_ai.sh smart_categorize_dual_ai.sh.bak_clear
    sed -i 's/^clear/#clear/' smart_categorize_dual_ai.sh
    
    ./smart_categorize_dual_ai.sh "$isbn" -noverbose 2>&1 | tee -a "$log_file"
    result=${PIPESTATUS[0]}
    
    # Restaurer
    mv smart_categorize_dual_ai.sh.bak_clear smart_categorize_dual_ai.sh
    
    if [ $result -eq 0 ]; then
        ((success++))
        echo "✅ Succès" | tee -a "$log_file"
    else
        ((failed++))
        echo "❌ Échec" | tee -a "$log_file"
    fi
    
    # Pause de 5 secondes entre chaque pour éviter rate limit
    if [ $num -lt $total ]; then
        echo "⏳ Pause 5 secondes..." | tee -a "$log_file"
        sleep 5
    fi
done

# Résumé final
{
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════"
    echo "📊 RÉSUMÉ FINAL"
    echo "════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "   Total traités : $total"
    echo "   ✅ Succès : $success"
    echo "   ❌ Échecs : $failed"
    echo ""
    echo "📝 Log complet : $log_file"
} | tee -a "$log_file"

# Afficher les catégories finales
echo ""
echo "📋 Résultat des catégorisations :"
for isbn in "${missing_isbn[@]}"; do
    result=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT 
        CONCAT('ISBN ', pm.meta_value, ' : ', LEFT(p.post_title, 30), '... → ', IFNULL(t.name, 'NON CATÉGORISÉ'))
    FROM wp_${SITE_ID}_posts p
    JOIN wp_${SITE_ID}_postmeta pm ON p.ID = pm.post_id
    LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
    LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
    LEFT JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id AND tt.taxonomy = 'product_cat'
    WHERE pm.meta_key = '_isbn' AND pm.meta_value = '$isbn'
    LIMIT 1
    " 2>/dev/null)
    echo "$result"
done

echo ""
echo "✅ Terminé : $(date)"
