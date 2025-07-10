#!/bin/bash
echo "[START: export_cdiscount.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# Export cdiscount - Template de base

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

MARKETPLACE="cdiscount"
OUTPUT_FILE="exports/output/generer_${MARKETPLACE}_$(date +%Y%m%d_%H%M%S).csv"

echo "=== EXPORT $MARKETPLACE ==="
echo "Date : $(date)"
echo ""

# Récupérer les livres à exporter
books=$(safe_mysql "
    SELECT DISTINCT p.ID
    FROM wp_${SITE_ID}_posts p
    JOIN wp_${SITE_ID}_postmeta pm1 ON p.ID = pm1.post_id AND pm1.meta_key = '_isbn'
    JOIN wp_${SITE_ID}_postmeta pm2 ON p.ID = pm2.post_id AND pm2.meta_key = '_api_collect_status'
    WHERE pm2.meta_value = 'completed'
    AND p.post_type = 'product'
    AND p.post_status = 'publish'
    LIMIT 100")

count=$(echo "$books" | wc -l)
echo "📊 Livres à exporter : $count"

# En-tête CSV selon marketplace
case "$MARKETPLACE" in
    "amazon")
        echo "sku,title,description,price,quantity,isbn" > "$OUTPUT_FILE"
        ;;
    "vinted")
        echo "title,description,price,category,isbn,weight" > "$OUTPUT_FILE"
        ;;
    *)
        echo "isbn,title,author,price,weight" > "$OUTPUT_FILE"
        ;;
esac

# Export des données
exported=0
while read -r product_id; do
    [ -z "$product_id" ] && continue
    
    # Récupérer les données
    isbn=$(safe_get_meta "$product_id" "_isbn")
    title=$(safe_get_meta "$product_id" "_best_title")
    authors=$(safe_get_meta "$product_id" "_best_authors")
    description=$(safe_get_meta "$product_id" "_best_description")
    weight=$(safe_get_meta "$product_id" "_calculated_weight")
    price=$(safe_get_meta "$product_id" "_price")
    
    # Nettoyer pour CSV
    title=$(echo "$title" | sed 's/"/""/g')
    description=$(echo "$description" | sed 's/"/""/g' | tr '\n' ' ')
    
    # Écrire selon le format
    case "$MARKETPLACE" in
        "amazon")
            echo "\"$isbn\",\"$title\",\"$description\",\"$price\",\"1\",\"$isbn\"" >> "$OUTPUT_FILE"
            ;;
        "vinted")
            echo "\"$title\",\"$description\",\"$price\",\"Livres\",\"$isbn\",\"$weight\"" >> "$OUTPUT_FILE"
            ;;
        *)
            echo "\"$isbn\",\"$title\",\"$authors\",\"$price\",\"$weight\"" >> "$OUTPUT_FILE"
            ;;
    esac
    
    ((exported++))
    echo -ne "\r🔄 Export : $exported/$count"
done <<< "$books"

echo ""
echo ""
echo "✅ Export terminé : $OUTPUT_FILE"
echo "📊 Livres exportés : $exported"

echo "[END: export_cdiscount.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
