#!/bin/bash
echo "[START: maintenance_tools.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# lib/maintenance_tools.sh - Outils de maintenance pour la base de données

# Nettoyer les doublons de métadonnées
clean_duplicate_metadata() {
    echo "🧹 NETTOYAGE DES DOUBLONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━"
    
    local duplicates=$(safe_mysql "
        SELECT COUNT(*) - COUNT(DISTINCT post_id, meta_key, meta_value)
        FROM wp_${SITE_ID}_postmeta
        WHERE meta_key LIKE '_g_%' 
           OR meta_key LIKE '_i_%' 
           OR meta_key LIKE '_o_%' 
           OR meta_key LIKE '_best_%' 
           OR meta_key LIKE '_calculated_%'
           OR meta_key LIKE '_claude_%'
           OR meta_key LIKE '_groq_%'")
    
    echo "Doublons trouvés : $duplicates"
    
    if [ "$duplicates" -gt 0 ]; then
        echo "Suppression en cours..."
        
        # Créer table temporaire avec données uniques
        safe_mysql "
            CREATE TEMPORARY TABLE temp_unique AS
            SELECT MIN(meta_id) as keep_id, post_id, meta_key, meta_value
            FROM wp_${SITE_ID}_postmeta
            WHERE meta_key LIKE '_g_%' 
               OR meta_key LIKE '_i_%' 
               OR meta_key LIKE '_o_%' 
               OR meta_key LIKE '_best_%' 
               OR meta_key LIKE '_calculated_%'
               OR meta_key LIKE '_claude_%'
               OR meta_key LIKE '_groq_%'
            GROUP BY post_id, meta_key, meta_value"
        
        # Supprimer les doublons
        local deleted=$(safe_mysql "
            DELETE pm FROM wp_${SITE_ID}_postmeta pm
            LEFT JOIN temp_unique tu ON pm.meta_id = tu.keep_id
            WHERE (pm.meta_key LIKE '_g_%' 
               OR pm.meta_key LIKE '_i_%' 
               OR pm.meta_key LIKE '_o_%' 
               OR pm.meta_key LIKE '_best_%' 
               OR pm.meta_key LIKE '_calculated_%'
               OR pm.meta_key LIKE '_claude_%'
               OR pm.meta_key LIKE '_groq_%')
            AND tu.keep_id IS NULL;
            SELECT ROW_COUNT()")
        
        echo "✅ $deleted doublons supprimés"
    else
        echo "✅ Aucun doublon trouvé"
    fi
}

# Effacer toutes les données API d'un livre
clear_book_api_data() {
    local product_id=$1
    
    echo "🗑️  Suppression des données API pour produit #$product_id..."
    
    local deleted=$(safe_mysql "
        DELETE FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $product_id 
        AND (meta_key LIKE '_g_%' 
          OR meta_key LIKE '_i_%' 
          OR meta_key LIKE '_o_%' 
          OR meta_key LIKE '_best_%' 
          OR meta_key LIKE '_calculated_%'
          OR meta_key LIKE '_claude_%'
          OR meta_key LIKE '_groq_%'
          OR meta_key LIKE '_api_%'
          OR meta_key = '_export_score'
          OR meta_key = '_missing_data'
          OR meta_key = '_last_analyze_date');
        SELECT ROW_COUNT()")
    
    echo "✅ $deleted métadonnées supprimées"
}

# Recalculer poids et dimensions pour tous les livres
recalculate_all_weights_dimensions() {
    echo "⚖️  RECALCUL DES POIDS ET DIMENSIONS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Récupérer tous les livres avec pages
    local books=$(safe_mysql "
        SELECT DISTINCT p.ID, pm_pages.meta_value as pages, pm_binding.meta_value as binding
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_pages ON p.ID = pm_pages.post_id 
            AND pm_pages.meta_key IN ('_best_pages', '_g_pageCount', '_i_pages', '_o_number_of_pages')
        LEFT JOIN wp_${SITE_ID}_postmeta pm_binding ON p.ID = pm_binding.post_id 
            AND pm_binding.meta_key IN ('_best_binding', '_i_binding', '_o_physical_format')
        WHERE p.post_type = 'product'
        AND p.post_status = 'publish'
        AND pm_pages.meta_value IS NOT NULL
        AND pm_pages.meta_value != '0'
        AND pm_pages.meta_value != 'null'
        ORDER BY p.ID")
    
    local count=0
    while IFS=$'\t' read -r product_id pages binding; do
        if [ -n "$pages" ] && [ "$pages" != "0" ]; then
            # Calculer le poids
            local weight=$(calculate_weight "$pages")
            safe_store_meta "$product_id" "_calculated_weight" "$weight"
            
            # Calculer les dimensions
            local dimensions=$(calculate_dimensions "${binding:-Broché}")
            safe_store_meta "$product_id" "_calculated_dimensions" "$dimensions"
            
            ((count++))
            echo -ne "\rTraité : $count livres"
        fi
    done <<< "$books"
    
    echo ""
    echo "✅ $count livres recalculés"
}

# Vérifier les images cassées
check_broken_images() {
    echo "🖼️  VÉRIFICATION DES IMAGES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Récupérer toutes les URLs d'images
    local images=$(safe_mysql "
        SELECT DISTINCT post_id, meta_key, meta_value
        FROM wp_${SITE_ID}_postmeta
        WHERE meta_key IN (
            '_g_thumbnail', '_g_smallThumbnail', '_g_small', '_g_medium', '_g_large', '_g_extraLarge',
            '_i_image', '_o_cover_small', '_o_cover_medium', '_o_cover_large',
            '_best_cover_image'
        )
        AND meta_value IS NOT NULL
        AND meta_value != ''
        AND meta_value != 'null'
        AND meta_value LIKE 'http%'
        LIMIT 100")
    
    local total=0
    local broken=0
    local checked=0
    
    echo "Vérification en cours..."
    while IFS=$'\t' read -r product_id meta_key url; do
        ((total++))
        echo -ne "\rVérifié : $checked/$total (Cassées: $broken)"
        
        # Vérifier si l'URL existe
        if command -v curl &>/dev/null; then
            local http_code=$(curl -s -o /dev/null -w "%{http_code}" -I "$url" --connect-timeout 5 --max-time 10 2>/dev/null)
            
            if [ "$http_code" != "200" ] && [ "$http_code" != "301" ] && [ "$http_code" != "302" ]; then
                ((broken++))
                # Marquer comme cassée
                safe_store_meta "$product_id" "_broken_image_${meta_key}" "$url"
                echo ""
                echo "❌ Image cassée : Produit #$product_id - $meta_key (HTTP $http_code)"
            fi
        fi
        
        ((checked++))
        
        # Pause pour ne pas surcharger
        [ $((checked % 10)) -eq 0 ] && sleep 1
    done <<< "$images"
    
    echo ""
    echo ""
    echo "📊 Résumé :"
    echo "   Total images : $total"
    echo "   Vérifiées : $checked"
    echo "   Cassées : $broken"
    
    if [ $broken -gt 0 ]; then
        echo ""
        echo "💡 Pour voir les images cassées :"
        echo "   SELECT * FROM wp_${SITE_ID}_postmeta WHERE meta_key LIKE '_broken_image_%'"
    fi
}

# Exporter la liste des ISBN
export_isbn_list() {
    local output_file="$SCRIPT_DIR/generer_isbn_inventory_$(date +%Y%m%d_%H%M%S).csv"
    
    echo "📤 EXPORT DE L'INVENTAIRE ISBN"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo "Génération du fichier CSV..."
    
    # En-tête CSV
    echo "ID,ISBN,Titre,Auteur,Éditeur,Prix,Stock,État,Score,Date_Collecte" > "$output_file"
    
    # Exporter les données
    safe_mysql "
        SELECT 
            p.ID,
            COALESCE(pm_isbn.meta_value, '') as isbn,
            COALESCE(p.post_title, '') as title,
            COALESCE(pm_authors.meta_value, '') as authors,
            COALESCE(pm_publisher.meta_value, '') as publisher,
            COALESCE(pm_price.meta_value, '0') as price,
            COALESCE(pm_stock.meta_value, '1') as stock,
            COALESCE(pm_condition.meta_value, '') as condition,
            COALESCE(pm_score.meta_value, '0') as score,
            COALESCE(pm_date.meta_value, '') as collect_date
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id 
            AND pm_authors.meta_key IN ('_best_authors', '_g_authors')
        LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id 
            AND pm_publisher.meta_key IN ('_best_publisher', '_g_publisher')
        LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_stock_quantity'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_score ON p.ID = pm_score.post_id AND pm_score.meta_key = '_export_score'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_api_collect_date'
        WHERE p.post_type = 'product'
        AND p.post_status = 'publish'
        ORDER BY p.ID" | tr '\t' ',' >> "$output_file"
    
    local count=$(wc -l < "$output_file")
    ((count--)) # Enlever l'en-tête
    
    echo "✅ Export terminé : $count livres"
    echo "📁 Fichier : $output_file"
}

# Statistiques globales
show_global_statistics() {
    echo "📊 STATISTIQUES GLOBALES"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    
    # Total livres
    local total_books=$(safe_mysql "
        SELECT COUNT(DISTINCT p.ID)
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm ON p.ID = pm.post_id AND pm.meta_key = '_isbn'
        WHERE p.post_type = 'product' AND p.post_status = 'publish'")
    
    echo "📚 Total livres : $total_books"
    echo ""
    
    # Par score d'exportabilité
    echo "📈 Répartition par score d'exportabilité :"
    safe_mysql "
        SELECT 
            COALESCE(pm_score.meta_value, '0') as score,
            COUNT(*) as nombre
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_score ON p.ID = pm_score.post_id AND pm_score.meta_key = '_export_score'
        WHERE p.post_type = 'product' AND p.post_status = 'publish'
        GROUP BY score
        ORDER BY score DESC"
    
    echo ""
    
    # Par état
    echo "📖 Répartition par état :"
    safe_mysql "
        SELECT 
            COALESCE(pm_condition.meta_value, 'Non défini') as etat,
            COUNT(*) as nombre
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
        WHERE p.post_type = 'product' AND p.post_status = 'publish'
        GROUP BY etat
        ORDER BY nombre DESC"
    
    echo ""
    
    # Par gamme de prix
    echo "💰 Répartition par prix :"
    safe_mysql "
        SELECT 
            CASE 
                WHEN CAST(pm_price.meta_value AS DECIMAL(10,2)) = 0 THEN 'Sans prix'
                WHEN CAST(pm_price.meta_value AS DECIMAL(10,2)) < 5 THEN '< 5€'
                WHEN CAST(pm_price.meta_value AS DECIMAL(10,2)) < 10 THEN '5-10€'
                WHEN CAST(pm_price.meta_value AS DECIMAL(10,2)) < 20 THEN '10-20€'
                ELSE '> 20€'
            END as gamme,
            COUNT(*) as nombre
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
        WHERE p.post_type = 'product' AND p.post_status = 'publish'
        GROUP BY gamme
        ORDER BY 
            CASE gamme
                WHEN 'Sans prix' THEN 1
                WHEN '< 5€' THEN 2
                WHEN '5-10€' THEN 3
                WHEN '10-20€' THEN 4
                ELSE 5
            END"
    
    echo ""
    
    # Sources des descriptions
    echo "📝 Sources des descriptions :"
    safe_mysql "
        SELECT 
            COALESCE(pm_source.meta_value, 'Aucune') as source,
            COUNT(*) as nombre
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
        LEFT JOIN wp_${SITE_ID}_postmeta pm_source ON p.ID = pm_source.post_id AND pm_source.meta_key = '_best_description_source'
        WHERE p.post_type = 'product' AND p.post_status = 'publish'
        GROUP BY source
        ORDER BY nombre DESC"
    
    echo ""
    
    # Livres sans images
    local no_image=$(safe_mysql "
        SELECT COUNT(DISTINCT p.ID)
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
        WHERE p.post_type = 'product' AND p.post_status = 'publish'
        AND p.ID NOT IN (
            SELECT DISTINCT post_id FROM wp_${SITE_ID}_postmeta 
            WHERE meta_key IN ('_g_thumbnail', '_g_small', '_g_medium', '_g_large', '_i_image', '_o_cover_medium', '_best_cover_image')
            AND meta_value IS NOT NULL AND meta_value != '' AND meta_value != 'null'
        )")
    
    echo "🖼️  Livres sans image : $no_image"
    
    # Livres complets (score max)
    local complete=$(safe_mysql "
        SELECT COUNT(*)
        FROM wp_${SITE_ID}_postmeta pm_score
        JOIN wp_${SITE_ID}_postmeta pm_max ON pm_score.post_id = pm_max.post_id AND pm_max.meta_key = '_export_max_score'
        WHERE pm_score.meta_key = '_export_score'
        AND pm_score.meta_value = pm_max.meta_value
        AND pm_score.meta_value > 0")
    
    echo "✅ Livres complets (score max) : $complete"
}

# Réparer les titres avec caractères spéciaux
fix_titles_special_chars() {
    echo "🔧 RÉPARATION DES TITRES"
    echo "━━━━━━━━━━━━━━━━━━━━━━"
    
    # Récupérer les titres avec caractères problématiques
    local titles=$(safe_mysql "
        SELECT ID, post_title
        FROM wp_${SITE_ID}_posts
        WHERE post_type = 'product'
        AND post_status = 'publish'
        AND (
            post_title LIKE '%&#039;%'
            OR post_title LIKE '%&quot;%'
            OR post_title LIKE '%&amp;%'
            OR post_title LIKE '%&lt;%'
            OR post_title LIKE '%&gt;%'
            OR post_title LIKE '%Ã©%'
            OR post_title LIKE '%Ã¨%'
            OR post_title LIKE '%Ã %'
            OR post_title LIKE '%Ã¢%'
        )")
    
    local count=0
    while IFS=$'\t' read -r product_id title; do
        # Nettoyer le titre
        local clean_title="$title"
        clean_title=$(echo "$clean_title" | sed "s/&#039;/'/g")
        clean_title=$(echo "$clean_title" | sed 's/&quot;/"/g')
        clean_title=$(echo "$clean_title" | sed 's/&amp;/\&/g')
        clean_title=$(echo "$clean_title" | sed 's/&lt;/</g')
        clean_title=$(echo "$clean_title" | sed 's/&gt;/>/g')
        clean_title=$(echo "$clean_title" | sed 's/Ã©/é/g')
        clean_title=$(echo "$clean_title" | sed 's/Ã¨/è/g')
        clean_title=$(echo "$clean_title" | sed 's/Ã /à/g')
        clean_title=$(echo "$clean_title" | sed 's/Ã¢/â/g')
        clean_title=$(echo "$clean_title" | sed 's/Ã´/ô/g')
        clean_title=$(echo "$clean_title" | sed 's/Ã®/î/g')
        clean_title=$(echo "$clean_title" | sed 's/Ã«/ë/g')
        clean_title=$(echo "$clean_title" | sed 's/Ã§/ç/g')
        
        if [ "$clean_title" != "$title" ]; then
            # Mettre à jour le titre
            local clean_title_escaped=$(safe_sql "$clean_title")
            safe_mysql "UPDATE wp_${SITE_ID}_posts SET post_title = '$clean_title_escaped' WHERE ID = $product_id"
            
            ((count++))
            echo "✓ #$product_id : $title → $clean_title"
        fi
    done <<< "$titles"
    
    echo ""
    echo "✅ $count titres corrigés"
}

# Menu de maintenance
show_maintenance_menu() {
    echo ""
    echo "🔧 MENU MAINTENANCE"
    echo "━━━━━━━━━━━━━━━━━━"
    echo "1) Nettoyer les doublons de métadonnées"
    echo "2) Effacer toutes les données API d'un livre"
    echo "3) Recalculer poids et dimensions"
    echo "4) Vérifier les images cassées"
    echo "5) Exporter liste ISBN (CSV)"
    echo "6) Statistiques globales"
    echo "7) Réparer les titres (caractères spéciaux)"
    echo "0) Retour au menu principal"
    echo ""
    read -p "Votre choix : " maintenance_choice
    
    case $maintenance_choice in
        1)
            clean_duplicate_metadata
            ;;
        2)
            read -p "ID ou ISBN du livre : " input
            local product_id=$(get_product_id_from_input "$input")
            if [ -n "$product_id" ]; then
                clear_book_api_data "$product_id"
            else
                echo "❌ Livre non trouvé"
            fi
            ;;
        3)
            recalculate_all_weights_dimensions
            ;;
        4)
            check_broken_images
            ;;
        5)
            export_isbn_list
            ;;
        6)
            show_global_statistics
            ;;
        7)
            fix_titles_special_chars
            ;;
        0)
            return 0
            ;;
        *)
            echo "❌ Choix invalide"
            ;;
    esac
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
    show_maintenance_menu
}

# Export des fonctions
export -f clean_duplicate_metadata
export -f clear_book_api_data
export -f recalculate_all_weights_dimensions
export -f check_broken_images
export -f export_isbn_list
export -f show_global_statistics
export -f fix_titles_special_chars
export -f show_maintenance_menu

echo "[END: maintenance_tools.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
