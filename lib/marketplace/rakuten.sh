#!/bin/bash
# lib/marketplace/rakuten.sh - Requirements Rakuten/PriceMinister

show_rakuten_requirements() {
   local product_id=$1
   local isbn=$2
   
   echo ""
   echo ""
   echo "🛍️ RAKUTEN/PRICEMINISTER REQUIREMENTS COMPLETS"
   echo "┌──────────────────────────┬──────────────────────────────────────┬──────────┬────────────────┐"
   echo "│ Champ Rakuten            │ Valeur actuelle                      │ Status   │ Obligatoire    │"
   echo "├──────────────────────────┼──────────────────────────────────────┼──────────┼────────────────┤"
   
   # EAN
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "ean" "$isbn" "OUI"
   
   # Title (70 car max)
   value=$(get_best_value "title" "$product_id")
   if [ -n "$value" ]; then
       display="${value:0:36}"
       [ ${#value} -gt 70 ] && display="${value:0:33}..."
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "title" "$display" "OUI (max 70)"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "title" "-" "OUI - BLOQUANT"
   fi
   
   # Description
   value=$(get_best_value "description" "$product_id")
   if [ -n "$value" ] && [ ${#value} -ge 20 ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "description" "${value:0:36}" "OUI (min 20)"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "description" "Trop courte/absente" "OUI - BLOQUANT"
   fi
   
   # Price
   value=$(get_best_value "price" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "price" "$value €" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANUEL\033[0m │ %-14s │\n" "price" "À définir" "OUI - MANUEL"
   fi
   
   # Ecotax
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "ecotax" "0" "OUI"
   
   # Quantity
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "quantity" "1" "OUI"
   
   # Product Type
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "product_type" "10 (Livres)" "OUI"
   
   # Product State
   printf "│ %-24s │ %-36s │ \033[33m⚠ MANUEL\033[0m │ %-14s │\n" "product_state" "10 (Neuf) - À vérifier" "OUI - MANUEL"
   
   # Author
   value=$(get_best_value "authors" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "author" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "author" "-" "Recommandé"
   fi
   
   # Publisher
   value=$(get_best_value "publisher" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "publisher" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "publisher" "-" "Recommandé"
   fi
   
   # Collection
   printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "collection" "-" "Optionnel"
   
   # Year
   value=$(get_best_value "date" "$product_id")
   if [ -n "$value" ]; then
       year=$(echo "$value" | grep -o '[0-9]\{4\}' | head -1)
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "year" "$year" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "year" "-" "Recommandé"
   fi
   
   # Pages
   value=$(get_best_value "pages" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "pages" "$value" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "pages" "-" "Recommandé"
   fi
   
   # Language
   value=$(get_best_value "language" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "language" "$value" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "language" "fr (défaut)" "Recommandé"
   fi
   
   # Format
   binding=$(get_best_value "binding" "$product_id")
   if [ -n "$binding" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "format" "${binding:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "format" "Poche/Grand format" "Recommandé"
   fi
   
   # Weight
   value=$(get_best_value "weight" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "weight" "$value g" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ CALC\033[0m  │ %-14s │\n" "weight" "À calculer" "Recommandé"
   fi
   
   # Image 1
   value=$(get_best_value "image" "$product_id")
   if [ -n "$value" ]; then
       if [ ${#value} -gt 36 ]; then
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "image_1" "${value:0:33}..." "OUI"
           printf "│ %-24s │ %-36s │ %-10s │ %-14s │\n" "" "$value" "" ""
       else
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "image_1" "$value" "OUI"
       fi
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "image_1" "-" "OUI - BLOQUANT"
   fi
   
   # Images 2-5
   printf "│ %-24s │ %-36s │ \033[33m⚠ CHECK\033[0m  │ %-14s │\n" "image_2-5" "Vérifier disponibilité" "Optionnel"
   
   echo "└──────────────────────────┴──────────────────────────────────────┴──────────┴────────────────┘"
}
