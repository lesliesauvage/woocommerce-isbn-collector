#!/bin/bash
# lib/marketplace/amazon.sh - Requirements Amazon

show_amazon_requirements() {
   local product_id=$1
   local isbn=$2
   
   echo ""
   echo "📦 AMAZON REQUIREMENTS COMPLETS"
   echo "┌──────────────────────────┬──────────────────────────────────────┬──────────┬────────────────┐"
   echo "│ Champ Amazon             │ Valeur actuelle                      │ Status   │ Obligatoire    │"
   echo "├──────────────────────────┼──────────────────────────────────────┼──────────┼────────────────┤"
   
   # SKU
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "SKU" "${isbn:0:36}" "OUI"
   
   # Product Name
   value=$(get_best_value "title" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "product-name" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "product-name" "-" "OUI - BLOQUANT"
   fi
   
   # Brand
   value=$(get_best_value "publisher" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "brand" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "brand" "-" "OUI - BLOQUANT"
   fi
   
   # Manufacturer
   value=$(get_best_value "publisher" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "manufacturer" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "manufacturer" "-" "OUI - BLOQUANT"
   fi
   
   # Product Type
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "product-type" "Book" "OUI"
   
   # Standard Price
   value=$(get_best_value "price" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "standard-price" "$value EUR" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANUEL\033[0m │ %-14s │\n" "standard-price" "À définir" "OUI - MANUEL"
   fi
   
   # Quantity
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "quantity" "1" "OUI"
   
   # External Product ID
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "external-product-id" "$isbn" "OUI"
   
   # External Product ID Type
   printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "external-product-id-type" "ISBN" "OUI"
   
   # Product Description
   value=$(get_best_value "description" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "product-description" "${value:0:36}" "OUI"
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "product-description" "-" "OUI - BLOQUANT"
   fi
   
   # Main Image URL
   value=$(get_best_value "image" "$product_id")
   if [ -n "$value" ]; then
       if [ ${#value} -gt 36 ]; then
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "main-image-url" "${value:0:33}..." "OUI"
           printf "│ %-24s │ %-36s │ %-10s │ %-14s │\n" "" "$value" "" ""
       else
           printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "main-image-url" "$value" "OUI"
       fi
   else
       printf "│ %-24s │ %-36s │ \033[31m✗ MANQUE\033[0m │ %-14s │\n" "main-image-url" "-" "OUI - BLOQUANT"
   fi
   
   # Author
   value=$(get_best_value "authors" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "author" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "author" "-" "Recommandé"
   fi
   
   # Publication Date
   value=$(get_best_value "date" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "publication-date" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "publication-date" "-" "Recommandé"
   fi
   
   # Number of Pages
   value=$(get_best_value "pages" "$product_id")
   if [ -n "$value" ] && [ "$value" != "0" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "number-of-pages" "$value" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "number-of-pages" "-" "Recommandé"
   fi
   
   # Language
   value=$(get_best_value "language" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "language" "$value" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "language" "fr (par défaut)" "Recommandé"
   fi
   
   # Binding
   binding=$(get_best_value "binding" "$product_id")
   if [ -n "$binding" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "binding" "${binding:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ MANQUE\033[0m │ %-14s │\n" "binding" "Broché (défaut)" "Recommandé"
   fi
   
   # Item Weight
   value=$(get_best_value "weight" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "item-weight" "$value g" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ CALC\033[0m  │ %-14s │\n" "item-weight" "À calculer" "Recommandé"
   fi
   
   # Item Dimensions
   value=$(get_best_value "dimensions" "$product_id")
   if [ -n "$value" ]; then
       printf "│ %-24s │ %-36s │ \033[32m✓ OK\033[0m     │ %-14s │\n" "item-dimensions" "${value:0:36}" "Recommandé"
   else
       printf "│ %-24s │ %-36s │ \033[33m⚠ CALC\033[0m  │ %-14s │\n" "item-dimensions" "À calculer" "Recommandé"
   fi
   
   # Category
   printf "│ %-24s │ %-36s │ \033[33m⚠ MAPPER\033[0m │ %-14s │\n" "item-type-keyword" "À mapper" "Recommandé"
   
   # Keywords
   printf "│ %-24s │ %-36s │ \033[33m⚠ GÉNÉRER\033[0m│ %-14s │\n" "generic-keywords" "À générer" "Recommandé"
   
   echo "└──────────────────────────┴──────────────────────────────────────┴──────────┴────────────────┘"
}
