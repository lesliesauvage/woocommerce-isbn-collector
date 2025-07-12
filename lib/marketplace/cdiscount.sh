#!/bin/bash
echo "[START: cdiscount.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# lib/marketplace/cdiscount.sh - Requirements Cdiscount

show_cdiscount_requirements() {
   local product_id=$1
   local isbn=$2
   
   echo ""
   echo ""
   echo "💿 CDISCOUNT REQUIREMENTS COMPLETS"
   echo "┌──────────────────────────┬──────────────────────────────────────┬──────────┬────────────────┐"
   echo "│ Champ Cdiscount          │ Valeur actuelle                      │ Status   │ Obligatoire    │"
   echo "├──────────────────────────┼──────────────────────────────────────┼──────────┼────────────────┤"
   
   # SKU
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "sku" "${isbn:0:36}" "OUI"
   
   # EAN
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "ean" "$isbn" "OUI"
   
   # Brand
   value=$(get_best_value "publisher" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "brand" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "brand" "-" "OUI - BLOQUANT"
   fi
   
   # Title
   value=$(get_best_value "title" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "title" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "title" "-" "OUI - BLOQUANT"
   fi
   
   # Description
   value=$(get_best_value "description" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "description" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "description" "-" "OUI - BLOQUANT"
   fi
   
   # Long Description
   value=$(get_best_value "description" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "long_description" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "long_description" "-" "Recommandé"
   fi
   
   # Price
   value=$(get_best_value "price" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "price" "$value €" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANUEL\033[0m │ %-14s │\n" "price" "À définir" "OUI - MANUEL"
   fi
   
   # Category Code
   printf "│ %-24s │ %-36s │ \033[33m⚠ MAPPER\033[0m │ %-14s │\n" "category_code" "À mapper Cdiscount" "OUI"
   
   # Weight
   value=$(get_best_value "weight" "$product_id")
   if [ -n "$value" ]; then
       # Convertir en kg pour Cdiscount
       weight_kg=$(echo "scale=3; $value / 1000" | bc 2>/dev/null || echo "0")
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "weight" "$weight_kg kg" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ CALC\033[0m  │ %-14s │\n" "weight" "À calculer" "OUI"
   fi
   
   # Dimensions
   dims=$(get_best_value "dimensions" "$product_id")
   if [ -n "$dims" ]; then
       # Parser les dimensions
       height=$(echo "$dims" | grep -o '[0-9]*\.[0-9]*' | sed -n '1p')
       length=$(echo "$dims" | grep -o '[0-9]*\.[0-9]*' | sed -n '2p')
       width=$(echo "$dims" | grep -o '[0-9]*\.[0-9]*' | sed -n '3p')
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "height" "${height:-?} cm" "Recommandé"
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "length" "${length:-?} cm" "Recommandé"
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "width" "${width:-?} cm" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ CALC\033[0m  │ %-14s │\n" "height/length/width" "À calculer" "Recommandé"
   fi
   
   # Main Image
   value=$(get_best_value "image" "$product_id")
   if [ -n "$value" ]; then
       if [ ${#value} -gt 36 ]; then
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "main_image" "${value:0:33}..." "OUI"
           printf "│ %-24s │ %-36s │ %-10s │ %-14s │\n" "" "$value" "" ""
       else
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "main_image" "$value" "OUI"
       fi
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "main_image" "-" "OUI - BLOQUANT"
   fi
   
   # Additional Images
   printf "│ %-24s │ %-36s │ \033[33m⚠ CHECK\033[0m  │ %-14s │\n" "image_2-4" "Vérifier disponibilité" "Optionnel"
   
   # Stock
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "stock" "1" "OUI"
   
   echo "└──────────────────────────┴──────────────────────────────────────┴──────────┴────────────────┘"
}

echo "[END: cdiscount.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
