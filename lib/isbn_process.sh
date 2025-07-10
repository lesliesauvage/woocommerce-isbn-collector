#!/bin/bash
# Bibliothèque de fonctions de traitement pour isbn_unified.sh
# Gère le traitement des livres, marquage vendu, batch processing

# Fonctions spécifiques aux modes
mark_as_sold() {
    local input="$1"
    
    # Déterminer si c'est un ID ou ISBN
    if [[ "$input" =~ ^[0-9]+$ ]] && [ ${#input} -lt 10 ]; then
        local id="$input"
    else
        local isbn="${input//[^0-9]/}"
        local id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT ID FROM wp_${SITE_ID}_posts 
            WHERE post_type='product' 
            AND post_status='publish' 
            AND ID IN (
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key='_sku' AND meta_value='$isbn'
            )
            LIMIT 1")
    fi
    
    if [ -z "$id" ]; then
        echo "❌ Livre non trouvé"
        return 1
    fi
    
    # Mettre à jour le stock
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        UPDATE wp_${SITE_ID}_postmeta 
        SET meta_value='0' 
        WHERE post_id=$id AND meta_key='_stock';"
    
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        UPDATE wp_${SITE_ID}_postmeta 
        SET meta_value='outofstock' 
        WHERE post_id=$id AND meta_key='_stock_status';"
    
    echo "✅ Livre #$id marqué comme VENDU"
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        display_martingale_complete "$id"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        display_martingale_complete "$id"
    fi
}

process_batch() {
    local limit="${1:-10}"
    
    echo "🔄 Recherche de $limit livres sans données..."
    
    local books=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT p.ID, pm.meta_value as isbn
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm ON p.ID = pm.post_id
        LEFT JOIN wp_${SITE_ID}_postmeta pm2 ON p.ID = pm2.post_id AND pm2.meta_key = '_collection_status'
        WHERE p.post_type = 'product'
        AND p.post_status = 'publish'
        AND pm.meta_key = '_sku'
        AND pm.meta_value != ''
        AND (pm2.meta_value IS NULL OR pm2.meta_value != 'completed')
        ORDER BY p.ID DESC
        LIMIT $limit")
    
    if [ -z "$books" ]; then
        echo "❌ Aucun livre à traiter"
        return 1
    fi
    
    local count=0
    while IFS=$'\t' read -r id isbn; do
        ((count++))
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "📚 Livre $count/$limit - ID: $id, ISBN: $isbn"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Traiter ce livre
        process_single_book "$id"
        
        echo ""
        echo "⏸  Pause de 2 secondes..."
        sleep 2
    done <<< "$books"
    
    echo ""
    echo "✅ Traitement terminé : $count livres traités"
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        display_martingale_complete "batch"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        display_martingale_complete "batch"
    fi
}

# Fonction pour traiter un livre unique avec MARTINGALE COMPLÈTE
process_single_book() {
    local input="$1"
    local price="$2"
    local condition="$3"
    local stock="${4:-1}"
    
    # Debug
    echo "[DEBUG] process_single_book: input=$input, price=$price, condition=$condition, stock=$stock"
    
    # Déterminer si c'est un ID ou ISBN
    if [[ "$input" =~ ^[0-9]+$ ]] && [ ${#input} -lt 10 ]; then
        local id="$input"
        local isbn=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT meta_value FROM wp_${SITE_ID}_postmeta 
            WHERE post_id=$id AND meta_key='_sku' LIMIT 1")
    else
        local isbn="${input//[^0-9]/}"
        local id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT ID FROM wp_${SITE_ID}_posts 
            WHERE post_type='product' 
            AND post_status='publish' 
            AND ID IN (
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key='_sku' AND meta_value='$isbn'
            )
            LIMIT 1")
    fi
    
    if [ -z "$id" ] || [ -z "$isbn" ]; then
        echo "❌ Livre non trouvé"
        return 1
    fi
    
    # === ÉTAPE 1 : APPLIQUER LES VALEURS MANUELLES ===
    if [ -n "$price" ]; then
        echo "[DEBUG] Mise à jour du prix : $price €"
        safe_store_meta "$id" "_price" "$price"
        safe_store_meta "$id" "_regular_price" "$price"
    fi
    
    if [ -n "$condition" ]; then
        echo "[DEBUG] Mise à jour de l'état : $condition"
        local book_condition=""
        local vinted_condition=""
        local vinted_text=""
        
        case "$condition" in
            1) 
                book_condition="Neuf avec étiquette"
                vinted_condition="1"
                vinted_text="1 - Neuf avec étiquette"
                ;;
            2) 
                book_condition="Neuf sans étiquette"
                vinted_condition="2"
                vinted_text="2 - Neuf sans étiquette"
                ;;
            3) 
                book_condition="Très bon état"
                vinted_condition="3"
                vinted_text="3 - Très bon état"
                ;;
            4) 
                book_condition="Bon état"
                vinted_condition="4"
                vinted_text="4 - Bon état"
                ;;
            5) 
                book_condition="État correct"
                vinted_condition="5"
                vinted_text="5 - Satisfaisant"
                ;;
            6) 
                book_condition="État passable"
                vinted_condition="5"
                vinted_text="5 - Satisfaisant"
                ;;
        esac
        
        if [ -n "$book_condition" ]; then
            safe_store_meta "$id" "_book_condition" "$book_condition"
            safe_store_meta "$id" "_vinted_condition" "$vinted_condition"
            safe_store_meta "$id" "_vinted_condition_text" "$vinted_text"
        fi
    fi
    
    if [ -n "$stock" ]; then
        echo "[DEBUG] Mise à jour du stock : $stock"
        safe_store_meta "$id" "_stock" "$stock"
        safe_store_meta "$id" "_manage_stock" "yes"
        
        if [ "$stock" -gt 0 ]; then
            safe_store_meta "$id" "_stock_status" "instock"
        else
            safe_store_meta "$id" "_stock_status" "outofstock"
        fi
    fi
    
    # === ÉTAPE 2 : STOCKER L'ISBN DANS _isbn ===
    safe_store_meta "$id" "_isbn" "$isbn"
    
    # === ÉTAPE 3 : CATÉGORISATION AUTOMATIQUE ===
    echo ""
    echo -e "${BOLD}${BLUE}🤖 CATÉGORISATION AUTOMATIQUE${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    local existing_categories=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) 
        FROM wp_${SITE_ID}_term_relationships tr
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        WHERE tr.object_id = $id 
        AND tt.taxonomy = 'product_cat'
        AND tt.term_id NOT IN (3088, 3089)")
    
    if [ "$existing_categories" -eq 0 ]; then
        echo -e "${YELLOW}📚 Aucune catégorie trouvée, lancement de la catégorisation...${NC}"
        
        if [ -f "$SCRIPT_DIR/smart_categorize_dual_ai.sh" ]; then
            "$SCRIPT_DIR/smart_categorize_dual_ai.sh" "$id"
            echo ""
            echo -e "${GREEN}✅ Catégorisation terminée${NC}"
        else
            echo -e "${RED}⚠️  Script de catégorisation non trouvé${NC}"
        fi
    else
        echo -e "${GREEN}✅ Le livre a déjà $existing_categories catégorie(s)${NC}"
    fi
    
    # === ÉTAPE 4 : AFFICHAGE AVANT ===
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${PURPLE}📚 ANALYSE COMPLÈTE AVEC COLLECTE - ISBN: $isbn${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Capturer l'état AVANT
    local before_data=$(capture_book_state "$id")
    local before_count=$(echo "$before_data" | grep -c "^_")
    
    # Afficher section AVANT
    if [ -f "$SCRIPT_DIR/lib/analyze_before.sh" ]; then
        source "$SCRIPT_DIR/lib/analyze_before.sh"
        show_before_state "$id" "$isbn"
    fi
    
    # === ÉTAPE 5 : COLLECTE DES DONNÉES ===
    local collection_status=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key='_collection_status' LIMIT 1")
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${CYAN}🔄 LANCEMENT DE LA COLLECTE${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    if [ "$collection_status" = "completed" ] && [ "$FORCE_MODE" != "force" ]; then
        echo -e "${BLUE}ℹ️  CE LIVRE A DÉJÀ ÉTÉ ANALYSÉ${NC}"
        echo -e "${YELLOW}💡 Utilisez -force pour forcer une nouvelle collecte${NC}"
    else
        # Lancer la collecte COMPLÈTE
        echo "[DEBUG] Début collecte MARTINGALE pour produit #$id - ISBN: $isbn"
        
        # Marquer les timestamps de début
        safe_store_meta "$id" "_google_last_attempt" "$(date '+%Y-%m-%d %H:%M:%S')"
        safe_store_meta "$id" "_isbndb_last_attempt" "$(date '+%Y-%m-%d %H:%M:%S')"
        safe_store_meta "$id" "_openlibrary_last_attempt" "$(date '+%Y-%m-%d %H:%M:%S')"
        
        # Appeler les APIs
        if [ -f "$SCRIPT_DIR/apis/google_books.sh" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]   → Google Books API..." | tee -a "$LOG_FILE"
            source "$SCRIPT_DIR/apis/google_books.sh"
            fetch_google_books "$isbn" "$id" 2>&1 | tee -a "$LOG_FILE"
        fi

        if [ -f "$SCRIPT_DIR/apis/isbndb.sh" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]   → ISBNdb API..." | tee -a "$LOG_FILE"
            source "$SCRIPT_DIR/apis/isbndb.sh"
            fetch_isbndb "$isbn" "$id" 2>&1 | tee -a "$LOG_FILE"
        fi

        if [ -f "$SCRIPT_DIR/apis/open_library.sh" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]   → Open Library API..." | tee -a "$LOG_FILE"
            source "$SCRIPT_DIR/apis/open_library.sh"
            fetch_open_library "$isbn" "$id" 2>&1 | tee -a "$LOG_FILE"
        fi

        # === ÉTAPE 6 : SÉLECTION DES MEILLEURES DONNÉES ===
        echo "[DEBUG] Sélection des meilleures données..."
        select_best_data "$id"

        # === ÉTAPE 7 : CALCULS AUTOMATIQUES ===
        echo "[DEBUG] Calcul du poids et dimensions..."
        calculate_weight_dimensions "$id"

        # === ÉTAPE 8 : GÉNÉRATION DES BULLET POINTS ===
        echo "[DEBUG] Génération des bullet points..."
        generate_bullet_points "$id"
        
        # === ÉTAPE 9 : GÉNÉRATION DESCRIPTION IA SI NÉCESSAIRE ===
        local has_description=$(get_meta_value "$id" "_has_description")
        local best_desc=$(get_meta_value "$id" "_best_description")
        
        if [ "$has_description" != "1" ] || [ -z "$best_desc" ] || [ ${#best_desc} -lt 20 ]; then
            echo "[DEBUG] Génération description IA nécessaire..."
            
            # Récupérer les données pour l'IA
            local final_title=$(get_meta_value "$id" "_best_title")
            local final_authors=$(get_meta_value "$id" "_best_authors")
            local final_publisher=$(get_meta_value "$id" "_best_publisher")
            local final_pages=$(get_meta_value "$id" "_best_pages")
            local final_binding=$(get_meta_value "$id" "_best_binding")
            local categories=$(get_meta_value "$id" "_g_categories")
            
            if [ -f "$SCRIPT_DIR/apis/claude_ai.sh" ]; then
                echo "[DEBUG] Appel Claude AI pour génération description..."
                source "$SCRIPT_DIR/apis/claude_ai.sh"
                if claude_desc=$(generate_description_claude "$isbn" "$id" "$final_title" "$final_authors" "$final_publisher" "$final_pages" "$final_binding" "$categories" 2>&1); then
                    safe_store_meta "$id" "_best_description" "$claude_desc"
                    safe_store_meta "$id" "_best_description_source" "claude_ai"
                    safe_store_meta "$id" "_has_description" "1"
                    echo "[DEBUG] ✓ Claude : description générée"
                else
                    echo "[DEBUG] ✗ Claude : échec génération"
                    # Essayer Groq en fallback
                    if [ -f "$SCRIPT_DIR/apis/groq_ai.sh" ]; then
                        echo "[DEBUG] Appel Groq AI en fallback..."
                        source "$SCRIPT_DIR/apis/groq_ai.sh"
                        if groq_desc=$(generate_description_groq "$isbn" "$id" "$final_title" "$final_authors" "$final_publisher" "$final_pages" "$final_binding" "$categories" 2>&1); then
                            safe_store_meta "$id" "_best_description" "$groq_desc"
                            safe_store_meta "$id" "_best_description_source" "groq_ai"
                            safe_store_meta "$id" "_has_description" "1"
                            echo "[DEBUG] ✓ Groq : description générée"
                        fi
                    fi
                fi
            fi
        fi
        
        # === ÉTAPE 10 : CALCUL DU SCORE D'EXPORT ===
        echo "[DEBUG] Calcul du score d'export..."
        calculate_export_score "$id"
    fi
    
    # === ÉTAPE 11 : APPLICATION COMPLÈTE DES MÉTADONNÉES MARTINGALE ===
    # IMPORTANT : Cette étape est maintenant TOUJOURS exécutée, même si collection_status = completed
    echo "[DEBUG] Application COMPLÈTE des métadonnées martingale..."
    enrich_metadata_complete "$id" "$isbn"
    
    # === ÉTAPE 12 : AFFICHAGE DES RÉSULTATS ===
    
    # Capturer l'état APRÈS
    local after_data=$(capture_book_state "$id")
    local after_count=$(echo "$after_data" | grep -c "^_")
    
    # Afficher section COLLECTE
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${BLUE}🔄 SECTION 2 : COLLECTE DES DONNÉES VIA APIs${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    show_api_results "$id"
    
    # Afficher section APRÈS avec requirements
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${GREEN}📊 SECTION 3 : RÉSULTAT APRÈS COLLECTE ET EXPORTABILITÉ${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    if [ -f "$SCRIPT_DIR/lib/analyze_after.sh" ]; then
        source "$SCRIPT_DIR/lib/analyze_after.sh"
        show_after_state "$id" "$isbn"
    fi
    
    # Afficher le résumé des gains
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${PURPLE}📈 RÉSUMÉ DES GAINS DE LA COLLECTE${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Calculer et afficher les gains
    local total_gain=$((after_count - before_count))
    
    if [ $total_gain -gt 0 ]; then
        echo -e "${GREEN}✅ Collecte réussie : +$total_gain nouvelles données${NC}"
    else
        echo -e "${BLUE}ℹ️  Aucune nouvelle donnée collectée${NC}"
    fi
    
    # === ÉTAPE 13 : VÉRIFICATION FINALE DES DONNÉES MARTINGALE ===
    echo ""
    echo -e "${BOLD}${YELLOW}🔍 VÉRIFICATION MARTINGALE COMPLÈTE${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    local complete_fields=0
    local total_fields=0
    local missing_critical=""
    
    # Liste de TOUS les champs de la martingale V4
    local martingale_fields=(
        # DONNÉES PRINCIPALES
        "_best_title:CRITIQUE"
        "_best_authors:IMPORTANT"
        "_best_publisher:IMPORTANT"
        "_best_description:CRITIQUE"
        "_best_pages:NORMAL"
        "_best_binding:NORMAL"
        "_best_cover_image:CRITIQUE"
        # PRIX ET STOCK
        "_price:CRITIQUE"
        "_regular_price:CRITIQUE"
        "_sale_price:NORMAL"
        "_sale_price_dates_from:NORMAL"
        "_sale_price_dates_to:NORMAL"
        "_stock:IMPORTANT"
        "_stock_status:IMPORTANT"
        "_manage_stock:NORMAL"
        "_backorders:NORMAL"
        "_sold_individually:NORMAL"
        # ÉTATS ET CONDITIONS
        "_book_condition:IMPORTANT"
        "_vinted_condition:IMPORTANT"
        "_vinted_condition_text:NORMAL"
        # CATÉGORIES
        "_cat_vinted:IMPORTANT"
        "_vinted_category_id:IMPORTANT"
        "_vinted_category_name:NORMAL"
        "_amazon_category:NORMAL"
        "_rakuten_category:NORMAL"
        "_fnac_category:NORMAL"
        "_cdiscount_category:NORMAL"
        "_ebay_category:NORMAL"
        "_allegro_category:NORMAL"
        "_bol_category:NORMAL"
        "_etsy_category:NORMAL"
        "_leboncoin_category:NORMAL"
        # CALCULS
        "_calculated_weight:IMPORTANT"
        "_calculated_dimensions:IMPORTANT"
        "_calculated_length:NORMAL"
        "_calculated_width:NORMAL"
        "_calculated_height:NORMAL"
        "_calculated_bullet1:NORMAL"
        "_calculated_bullet2:NORMAL"
        "_calculated_bullet3:NORMAL"
        "_calculated_bullet4:NORMAL"
        "_calculated_bullet5:NORMAL"
        # DIMENSIONS PHYSIQUES
        "_weight:NORMAL"
        "_length:NORMAL"
        "_width:NORMAL"
        "_height:NORMAL"
        # LOCALISATION
        "_location_zip:IMPORTANT"
        "_location_city:NORMAL"
        "_location_country:NORMAL"
        # IDENTIFIANTS
        "_isbn:CRITIQUE"
        "_sku:CRITIQUE"
        "_isbn10:NORMAL"
        "_isbn13:NORMAL"
        "_ean:NORMAL"
        # MÉTADONNÉES PRODUIT
        "_product_type:NORMAL"
        "_visibility:NORMAL"
        "_featured:NORMAL"
        "_virtual:NORMAL"
        "_downloadable:NORMAL"
        "_tax_status:NORMAL"
        "_tax_class:NORMAL"
        "_shipping_class:NORMAL"
        # MÉTADONNÉES SYSTÈME
        "_collection_status:CRITIQUE"
        "_last_collect_date:NORMAL"
        "_api_collect_date:NORMAL"
        "_export_score:IMPORTANT"
        "_export_max_score:IMPORTANT"
        "_missing_data:NORMAL"
        "_has_description:NORMAL"
        # IMAGES TOUTES TAILLES
        "_g_smallThumbnail:NORMAL"
        "_g_thumbnail:NORMAL"
        "_g_small:NORMAL"
        "_g_medium:NORMAL"
        "_g_large:NORMAL"
        "_g_extraLarge:NORMAL"
        "_i_image:NORMAL"
        "_o_cover_small:NORMAL"
        "_o_cover_medium:NORMAL"
        "_o_cover_large:NORMAL"
        "_thumbnail_id:NORMAL"
        "_product_image_gallery:NORMAL"
        "_image_alt:NORMAL"
        "_image_title:NORMAL"
        # DONNÉES GOOGLE BOOKS
        "_g_title:NORMAL"
        "_g_authors:NORMAL"
        "_g_publisher:NORMAL"
        "_g_publishedDate:NORMAL"
        "_g_description:NORMAL"
        "_g_pageCount:NORMAL"
        "_g_categories:NORMAL"
        "_g_categorie_reference:NORMAL"
        "_g_language:NORMAL"
        # DONNÉES ISBNDB
        "_i_title:NORMAL"
        "_i_authors:NORMAL"
        "_i_publisher:NORMAL"
        "_i_synopsis:NORMAL"
        "_i_binding:NORMAL"
        "_i_pages:NORMAL"
        "_i_subjects:NORMAL"
        "_i_language:NORMAL"
        "_i_msrp:NORMAL"
        # DONNÉES OPEN LIBRARY
        "_o_title:NORMAL"
        "_o_authors:NORMAL"
        "_o_publishers:NORMAL"
        "_o_number_of_pages:NORMAL"
        "_o_physical_format:NORMAL"
        "_o_subjects:NORMAL"
        "_o_description:NORMAL"
        # SOURCES DES MEILLEURES DONNÉES
        "_best_title_source:NORMAL"
        "_best_authors_source:NORMAL"
        "_best_publisher_source:NORMAL"
        "_best_description_source:NORMAL"
        "_best_pages_source:NORMAL"
        "_best_binding_source:NORMAL"
        "_best_cover_source:NORMAL"
        # TIMESTAMPS DE COLLECTE
        "_google_last_attempt:NORMAL"
        "_isbndb_last_attempt:NORMAL"
        "_openlibrary_last_attempt:NORMAL"
        "_last_analyze_date:NORMAL"
        # DONNÉES MARKETPLACE SPÉCIFIQUES
        "_amazon_keywords:NORMAL"
        "_amazon_search_terms:NORMAL"
        "_amazon_asin:NORMAL"
        "_amazon_export_status:NORMAL"
        "_amazon_last_export:NORMAL"
        "_rakuten_state:NORMAL"
        "_rakuten_product_id:NORMAL"
        "_rakuten_export_status:NORMAL"
        "_rakuten_last_export:NORMAL"
        "_fnac_tva_rate:NORMAL"
        "_fnac_product_id:NORMAL"
        "_fnac_export_status:NORMAL"
        "_fnac_last_export:NORMAL"
        "_cdiscount_brand:NORMAL"
        "_cdiscount_product_id:NORMAL"
        "_cdiscount_export_status:NORMAL"
        "_cdiscount_last_export:NORMAL"
        "_leboncoin_phone_hidden:NORMAL"
        "_leboncoin_ad_id:NORMAL"
        "_leboncoin_export_status:NORMAL"
        "_leboncoin_last_export:NORMAL"
        "_vinted_item_id:NORMAL"
        "_vinted_export_status:NORMAL"
        "_vinted_last_export:NORMAL"
        "_ebay_condition_id:NORMAL"
        # TAGS ET ATTRIBUTS
        "_product_tag:NORMAL"
        "_product_attributes:NORMAL"
        "_default_attributes:NORMAL"
        # DONNÉES ENRICHIES
        "_reading_age:NORMAL"
        "_lexile_measure:NORMAL"
        "_bisac_codes:NORMAL"
        "_dewey_decimal:NORMAL"
        "_lcc_number:NORMAL"
        # SEO
        "_yoast_title:NORMAL"
        "_yoast_metadesc:NORMAL"
        "_rank_math_title:NORMAL"
        "_rank_math_description:NORMAL"
    )
    
    for field_info in "${martingale_fields[@]}"; do
        IFS=':' read -r field importance <<< "$field_info"
        ((total_fields++))
        
        local value=$(get_meta_value "$id" "$field")
        if [ ! -z "$value" ] && [ "$value" != "0" ] && [ "$value" != "null" ]; then
            ((complete_fields++))
        else
            if [ "$importance" = "CRITIQUE" ]; then
                missing_critical="${missing_critical}$field, "
            fi
        fi
    done
    
    local completion_rate=$((complete_fields * 100 / total_fields))
    
    echo "Champs remplis : $complete_fields / $total_fields ($completion_rate%)"
    
    if [ -n "$missing_critical" ]; then
        echo -e "${RED}❌ CHAMPS CRITIQUES MANQUANTS : ${missing_critical%, }${NC}"
    fi
    
    if [ $completion_rate -eq 100 ]; then
        echo -e "${GREEN}✅ MARTINGALE COMPLÈTE : 100% des données collectées !${NC}"
    elif [ $completion_rate -gt 90 ]; then
        echo -e "${YELLOW}⚠️  MARTINGALE PRESQUE COMPLÈTE : $completion_rate%${NC}"
    else
        echo -e "${RED}❌ MARTINGALE INCOMPLÈTE : $completion_rate%${NC}"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        display_martingale_complete "$id"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        display_martingale_complete "$id"
    fi
}