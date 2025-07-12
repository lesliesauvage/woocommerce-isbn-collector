#!/bin/bash
echo "[START: leboncoin.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# lib/marketplace/leboncoin.sh - Requirements Leboncoin

show_leboncoin_requirements() {
   local product_id=$1
   local isbn=$2
   
   echo ""
   echo ""
   echo "🏠 LEBONCOIN REQUIREMENTS COMPLETS"
   echo "┌──────────────────────────┬──────────────────────────────────────┬──────────┬────────────────┐"
   echo "│ Champ Leboncoin          │ Valeur actuelle                      │ Status   │ Obligatoire    │"
   echo "├──────────────────────────┼──────────────────────────────────────┼──────────┼────────────────┤"
   
   # Title (max 50 car)
   value=$(get_best_value "title" "$product_id")
   if [ -n "$value" ]; then
       display="${value:0:36}"
       [ ${#value} -gt 50 ] && display="${value:0:33}..."
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "subject" "$display" "OUI (max 50)"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "subject" "-" "OUI - BLOQUANT"
   fi
   
   # Body/Description
   value=$(get_best_value "description" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "body" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "body" "-" "OUI - BLOQUANT"
   fi
   
   # Category
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "category_id" "27 (Livres/BD/Revues)" "OUI"
   
   # Price
   value=$(get_best_value "price" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "price" "$value €" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANUEL\033[0m │ %-14s │\n" "price" "À définir" "OUI - MANUEL"
   fi
   
   # Price Type
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "price_type" "fixed" "OUI"
   
   # Author dans body
   value=$(get_best_value "authors" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "author_in_body" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "author_in_body" "-" "Recommandé"
   fi
   
   # Publisher dans body
   value=$(get_best_value "publisher" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "publisher_in_body" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "publisher_in_body" "-" "Recommandé"
   fi
   
   # ISBN dans body
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "isbn_in_body" "ISBN: $isbn" "Recommandé"
   
   # Year
   value=$(get_best_value "date" "$product_id")
   if [ -n "$value" ]; then
       year=$(echo "$value" | grep -o '[0-9]\{4\}' | head -1)
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "year_in_body" "$year" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "year_in_body" "-" "Recommandé"
   fi
   
   # Pages dans body
   value=$(get_best_value "pages" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "pages_in_body" "$value pages" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "pages_in_body" "-" "Recommandé"
   fi
   
   # Format
   binding=$(get_best_value "binding" "$product_id")
   if [ -n "$binding" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "format_in_body" "${binding:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "format_in_body" "-" "Recommandé"
   fi
   
   # Language
   value=$(get_best_value "language" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "language_in_body" "$value" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "language_in_body" "fr (défaut)" "Recommandé"
   fi
   
   # Images (max 10)
   value=$(get_best_value "image" "$product_id")
   if [ -n "$value" ]; then
       if [ ${#value} -gt 36 ]; then
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "image_1" "${value:0:33}..." "OUI (1 min)"
           printf "│ %-24s │ %-36s │ %-10s │ %-14s │\n" "" "$value" "" ""
       else
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "image_1" "$value" "OUI (1 min)"
       fi
       
       # Compter les autres images disponibles
       img_count=1
       for var in _g_medium _g_large _i_image _o_cover_medium _o_cover_large; do
           img=$(safe_get_meta "$product_id" "$var")
           [ -n "$img" ] && ((img_count++))
       done
       printf "│ %-24s │ %-36s │ \033[33m⚠ CHECK\033[0m  │ %-14s │\n" "images_2-10" "$img_count images disponibles" "Optionnel"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "image_1" "-" "OUI - BLOQUANT"
   fi
   
   # Location
   printf "│ %-24s │ %-36s │ \033[33m⚠ MANUEL\033[0m │ %-14s │\n" "location" "À définir (code postal)" "OUI - MANUEL"
   
   # Phone hidden
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "phone_hidden" "true" "Recommandé"
   
   echo "└──────────────────────────┴──────────────────────────────────────┴──────────┴────────────────┘"
}

echo "[END: leboncoin.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
