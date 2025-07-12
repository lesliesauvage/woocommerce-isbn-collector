#!/bin/bash
echo "[START: vinted.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# lib/marketplace/vinted.sh - Requirements Vinted

show_vinted_requirements() {
   local product_id=$1
   local isbn=$2
   
   echo ""
   echo ""
   echo "👗 VINTED REQUIREMENTS COMPLETS"
   echo "┌──────────────────────────┬──────────────────────────────────────┬──────────┬────────────────┐"
   echo "│ Champ Vinted             │ Valeur actuelle                      │ Status   │ Obligatoire    │"
   echo "├──────────────────────────┼──────────────────────────────────────┼──────────┼────────────────┤"
   
   # Title (max 70 car avec état)
   value=$(get_best_value "title" "$product_id")
   if [ -n "$value" ]; then
       # Tronquer pour laisser place à l'état
       title_vinted="${value:0:50} - Bon état"
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "title" "${title_vinted:0:36}" "OUI (max 70)"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "title" "-" "OUI - BLOQUANT"
   fi
   
   # Description (avec ISBN dedans)
   value=$(get_best_value "description" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "description" "Inclut ISBN: $isbn" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "description" "-" "OUI - BLOQUANT"
   fi
   
   # Price
   value=$(get_best_value "price" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "price" "$value €" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANUEL\033[0m │ %-14s │\n" "price" "À définir" "OUI - MANUEL"
   fi
   
   # Category ID
   vinted_cat=$(safe_get_meta "$product_id" "_vinted_category_id")
   if [ -n "$vinted_cat" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "category_id" "$vinted_cat" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "category_id" "1601 (Livres défaut)" "OUI"
   fi
   
   # Brand (éditeur)
   value=$(get_best_value "publisher" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "brand" "${value:0:36}" "Optionnel"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "brand" "-" "Optionnel"
   fi
   
   # Size (format du livre)
   binding=$(get_best_value "binding" "$product_id")
   if [ -n "$binding" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "size" "${binding:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "size" "Format standard" "Recommandé"
   fi
   
   # Condition (1-5)
   printf "│ %-24s │ %-36s │ \033[33m⚠ MANUEL\033[0m │ %-14s │\n" "condition" "À définir (1-5)" "OUI - MANUEL"
   
   # Color
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "color" "N/A pour livres" "Optionnel"
   
   # ISBN dans description
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "isbn_in_desc" "ISBN: $isbn" "Recommandé"
   
   # Author dans description
   value=$(get_best_value "authors" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "author_in_desc" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "author_in_desc" "-" "Recommandé"
   fi
   
   # Year
   value=$(get_best_value "date" "$product_id")
   if [ -n "$value" ]; then
       year=$(echo "$value" | grep -o '[0-9]\{4\}' | head -1)
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "year_in_desc" "$year" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "year_in_desc" "-" "Recommandé"
   fi
   
   # Language
   value=$(get_best_value "language" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "language" "$value" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "language" "fr (défaut)" "Recommandé"
   fi
   
   # Photos (max 20)
   value=$(get_best_value "image" "$product_id")
   if [ -n "$value" ]; then
       if [ ${#value} -gt 36 ]; then
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "photo_1" "${value:0:33}..." "OUI (1 min)"
           printf "│ %-24s │ %-36s │ %-10s │ %-14s │\n" "" "$value" "" ""
       else
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "photo_1" "$value" "OUI (1 min)"
       fi
       
       # Compter les autres images disponibles
       img_count=1
       for var in _g_medium _g_large _i_image _o_cover_medium _o_cover_large; do
           img=$(safe_get_meta "$product_id" "$var")
           [ -n "$img" ] && ((img_count++))
       done
       printf "│ %-24s │ %-36s │ \033[33m⚠ CHECK\033[0m  │ %-14s │\n" "photos_2-20" "$img_count images disponibles" "Optionnel"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "photo_1" "-" "OUI - BLOQUANT"
   fi
   
   # Package size
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "package_size" "1 (petit colis)" "OUI"
   
   echo "└──────────────────────────┴──────────────────────────────────────┴──────────┴────────────────┘"
}

echo "[END: vinted.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
