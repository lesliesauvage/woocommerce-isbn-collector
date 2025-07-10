#!/bin/bash
# lib/marketplace/fnac.sh - Requirements Fnac

show_fnac_requirements() {
   local product_id=$1
   local isbn=$2
   
   echo ""
   echo ""
   echo "📚 FNAC REQUIREMENTS COMPLETS"
   echo "┌──────────────────────────┬──────────────────────────────────────┬──────────┬────────────────┐"
   echo "│ Champ Fnac               │ Valeur actuelle                      │ Status   │ Obligatoire    │"
   echo "├──────────────────────────┼──────────────────────────────────────┼──────────┼────────────────┤"
   
   # EAN/ISBN
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "ean" "$isbn" "OUI"
   
   # Title
   value=$(get_best_value "title" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "title" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "title" "-" "OUI - BLOQUANT"
   fi
   
   # Author
   value=$(get_best_value "authors" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "author" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "author" "-" "OUI - BLOQUANT"
   fi
   
   # Publisher
   value=$(get_best_value "publisher" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "publisher" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "publisher" "-" "OUI - BLOQUANT"
   fi
   
   # Collection
   printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "collection" "-" "Optionnel"
   
   # Publication Date
   value=$(get_best_value "date" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "publication_date" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "publication_date" "-" "Recommandé"
   fi
   
   # Price
   value=$(get_best_value "price" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "price" "$value €" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANUEL\033[0m │ %-14s │\n" "price" "À définir" "OUI - MANUEL"
   fi
   
   # TVA Rate
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "tva_rate" "5.5%" "OUI"
   
   # Stock
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "stock" "1" "OUI"
   
   # Description
   value=$(get_best_value "description" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "description" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "description" "-" "Recommandé"
   fi
   
   # Pages
   value=$(get_best_value "pages" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "pages" "$value" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "pages" "-" "Recommandé"
   fi
   
   # Dimensions
   value=$(get_best_value "dimensions" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "dimensions" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ CALC\033[0m  │ %-14s │\n" "dimensions" "À calculer" "Recommandé"
   fi
   
   # Weight
   value=$(get_best_value "weight" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "weight" "$value g" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ CALC\033[0m  │ %-14s │\n" "weight" "À calculer" "Recommandé"
   fi
   
   # Language
   value=$(get_best_value "language" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "language" "$value" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "language" "fr (défaut)" "Recommandé"
   fi
   
   # ISBN
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "isbn" "$isbn" "OUI"
   
   # Format
   binding=$(get_best_value "binding" "$product_id")
   if [ -n "$binding" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "format" "${binding:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "format" "-" "Recommandé"
   fi
   
   # Image URL
   value=$(get_best_value "image" "$product_id")
   if [ -n "$value" ]; then
       if [ ${#value} -gt 36 ]; then
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "image_url" "${value:0:33}..." "Recommandé"
           printf "│ %-24s │ %-36s │ %-10s │ %-14s │\n" "" "$value" "" ""
       else
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "image_url" "$value" "Recommandé"
       fi
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "image_url" "-" "Recommandé"
   fi
   
   echo "└──────────────────────────┴──────────────────────────────────────┴──────────┴────────────────┘"
}
