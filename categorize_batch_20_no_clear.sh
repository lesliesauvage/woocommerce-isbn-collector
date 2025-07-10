#!/bin/bash
echo "[START: categorize_batch_20_no_clear.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

source config/settings.sh

echo "=== CATÉGORISATION BATCH DE 20 LIVRES (SANS CLEAR) ==="
echo "Date : $(date)"
echo "════════════════════════════════════════════════════════════════════════════"
echo ""

# Liste des 20 ISBN à traiter
isbn_list=(
   "2010120337"
   "201018128X"
   "2010195914"
   "2011668727"
   "2012356184"
   "2012363555"
   "2012367992"
   "2020007428"
   "2020015048"
   "2020086298"
   "2020097672"
   "2020115816"
   "202013554X"
   "2020211076"
   "2020326205"
   "2020413914"
   "2020509105"
   "2020550776"
   "2035054230"
   "2040039120"
   "2040166319"
)

# Statistiques
total=${#isbn_list[@]}
success=0
failed=0
not_found=0

echo "📚 $total livres à catégoriser"
echo ""

# Créer un fichier de log temporaire pour tout capturer
log_file="categorize_batch_$(date +%Y%m%d_%H%M%S).log"
echo "📝 Log complet : $log_file"
echo ""
echo "Démarrage..." | tee -a "$log_file"

# Traiter chaque ISBN
for i in "${!isbn_list[@]}"; do
   isbn="${isbn_list[$i]}"
   num=$((i + 1))
   
   {
       echo ""
       echo "════════════════════════════════════════════════════════════════════════════"
       echo "📖 LIVRE $num/$total - ISBN: $isbn"
       echo "════════════════════════════════════════════════════════════════════════════"
   } | tee -a "$log_file"
   
   # Vérifier si le livre existe
   exists=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
       SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
       WHERE meta_key = '_isbn' AND meta_value = '$isbn'
   " 2>/dev/null)
   
   if [ "$exists" = "0" ]; then
       echo "❌ ISBN non trouvé dans la base" | tee -a "$log_file"
       ((not_found++))
       continue
   fi
   
   # Modifier temporairement smart_categorize_dual_ai.sh pour désactiver le clear
   cp smart_categorize_dual_ai.sh smart_categorize_dual_ai.sh.bak_clear
   sed -i 's/^clear/#clear/' smart_categorize_dual_ai.sh
   
   # Lancer la catégorisation et capturer tout
   echo "" | tee -a "$log_file"
   ./smart_categorize_dual_ai.sh "$isbn" -noverbose 2>&1 | tee -a "$log_file"
   result=${PIPESTATUS[0]}
   
   # Restaurer le script original
   mv smart_categorize_dual_ai.sh.bak_clear smart_categorize_dual_ai.sh
   
   if [ $result -eq 0 ]; then
       ((success++))
       echo "✅ Succès" | tee -a "$log_file"
   else
       ((failed++))
       echo "❌ Échec de catégorisation" | tee -a "$log_file"
   fi
   
   # Pause entre chaque livre
   if [ $num -lt $total ]; then
       echo "⏳ Pause 3 secondes..." | tee -a "$log_file"
       sleep 3
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
   echo "   🔍 Non trouvés : $not_found"
   echo ""
   echo "📝 Log complet sauvegardé dans : $log_file"
   echo ""
   echo "📋 Résumé des catégorisations :"
   echo ""
} | tee -a "$log_file"

# Extraire un résumé des catégorisations du log
grep -E "(📚 LIVRE|📌 CATÉGORIE FINALE)" "$log_file" | sed 'N;s/\n/ → /' | tee -a "$log_file"

echo ""
echo "✅ Batch terminé : $(date)" | tee -a "$log_file"
echo ""
echo "💡 Pour voir tout le log : cat $log_file"

echo "[END: categorize_batch_20_no_clear.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
