#!/bin/bash
echo "[START: categorize_batch_20.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

source config/settings.sh

clear
echo "=== CATÉGORISATION BATCH DE 20 LIVRES ==="
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
echo "Mode : -noverbose (affichage épuré)"
echo ""
echo "Appuyez sur ENTRÉE pour commencer..."
read

# Traiter chaque ISBN
for i in "${!isbn_list[@]}"; do
   isbn="${isbn_list[$i]}"
   num=$((i + 1))
   
   echo ""
   echo "════════════════════════════════════════════════════════════════════════════"
   echo "📖 LIVRE $num/$total - ISBN: $isbn"
   echo "════════════════════════════════════════════════════════════════════════════"
   
   # Vérifier si le livre existe
   exists=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
       SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
       WHERE meta_key = '_isbn' AND meta_value = '$isbn'
   " 2>/dev/null)
   
   if [ "$exists" = "0" ]; then
       echo "❌ ISBN non trouvé dans la base"
       ((not_found++))
       continue
   fi
   
   # Lancer la catégorisation en mode silencieux
   echo ""
   ./smart_categorize_dual_ai.sh "$isbn" -noverbose
   
   if [ $? -eq 0 ]; then
       ((success++))
       echo "✅ Succès"
   else
       ((failed++))
       echo "❌ Échec de catégorisation"
   fi
   
   # Pause entre chaque livre pour éviter de surcharger les API
   if [ $num -lt $total ]; then
       echo ""
       echo "⏳ Pause 3 secondes avant le prochain..."
       sleep 3
   fi
done

# Résumé final
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
echo "📝 Logs détaillés : logs/dual_ai_categorize.log"
echo ""

# Afficher les dernières catégorisations
echo "📋 Dernières catégorisations :"
echo ""
tail -20 logs/dual_ai_categorize.log | grep -E "ID:[0-9]+" | tail -10

echo ""
echo "✅ Batch terminé : $(date)"

echo "[END: categorize_batch_20.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
