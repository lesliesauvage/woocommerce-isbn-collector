#!/bin/bash
# Bibliothèque de fonctions de traitement pour isbn_unified.sh
# Gère le traitement des livres, marquage vendu, batch processing

# Fonction get_meta_value (depuis safe_functions.sh)
get_meta_value() {
    local post_id="$1"
    local meta_key="$2"
    [ -z "$post_id" ] || [ -z "$meta_key" ] && return 1
    
    local value=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value 
        FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id 
        AND meta_key='$meta_key' 
        LIMIT 1" 2>/dev/null)
    
    # Si vide ou null, retourner vide
    if [ -z "$value" ] || [ "$value" = "null" ] || [ "$value" = "NULL" ]; then
        echo ""
    else
        echo "$value"
    fi
}

# Fonction safe_store_meta (depuis safe_functions.sh)
safe_store_meta() {
    local post_id="$1"
    local meta_key="$2"
    local meta_value="$3"
    
    [ -z "$post_id" ] || [ -z "$meta_key" ] && return 1
    
    # Échapper les apostrophes
    meta_value=$(echo "$meta_value" | sed "s/'/\\\\'/g")
    
    # Vérifier si la meta existe
    local exists=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$post_id AND meta_key='$meta_key'" 2>/dev/null)
    
    if [ "$exists" -gt 0 ]; then
        # Update
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            UPDATE wp_${SITE_ID}_postmeta 
            SET meta_value='$meta_value' 
            WHERE post_id=$post_id AND meta_key='$meta_key'" 2>/dev/null
    else
        # Insert
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            INSERT INTO wp_${SITE_ID}_postmeta (post_id, meta_key, meta_value) 
            VALUES ($post_id, '$meta_key', '$meta_value')" 2>/dev/null
    fi
}

# Fonction safe_sql (depuis safe_functions.sh)
safe_sql() {
    echo "$1" | sed "s/'/\\\\'/g"
}

# Fonction pour capturer l'état initial
capture_book_state() {
    local id=$1
    
    # Compter les métadonnées par type
    local google_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key LIKE '_g_%'")
    
    local isbndb_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key LIKE '_i_%'")
    
    local ol_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key LIKE '_o_%'")
    
    local best_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key LIKE '_best_%'")
    
    local calc_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id AND meta_key LIKE '_calculated_%'")
    
    local total_count=$((google_count + isbndb_count + ol_count + best_count + calc_count))
    
    echo "$google_count|$isbndb_count|$ol_count|$best_count|$calc_count|$total_count"
}

# Fonction pour marquer un livre comme vendu
mark_as_sold() {
    local identifier="$1"
    local id=""
    
    # Déterminer si c'est un ID ou un ISBN
    if [[ "$identifier" =~ ^[0-9]+$ ]] && [ ${#identifier} -lt 10 ]; then
        id="$identifier"
    else
        # C'est un ISBN, chercher l'ID
        local clean_isbn="${identifier//[^0-9]/}"
        id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT ID FROM wp_${SITE_ID}_posts 
            WHERE post_type='product' 
            AND ID IN (
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key='_sku' AND meta_value='$clean_isbn'
            )
            LIMIT 1")
    fi
    
    if [ -z "$id" ]; then
        echo -e "${RED}❌ Livre non trouvé${NC}"
        return 1
    fi
    
    # Mettre à jour le statut
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        UPDATE wp_${SITE_ID}_postmeta 
        SET meta_value='outofstock' 
        WHERE post_id=$id AND meta_key='_stock_status'"
    
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
        UPDATE wp_${SITE_ID}_postmeta 
        SET meta_value='0' 
        WHERE post_id=$id AND meta_key='_stock'"
    
    # Ajouter la date de vente
    local sale_date=$(date '+%Y-%m-%d %H:%M:%S')
    safe_store_meta "$id" "_sale_date" "$sale_date"
    
    echo -e "${GREEN}✅ Livre ID $id marqué comme VENDU${NC}"
    echo "Date de vente : $sale_date"
}

# Fonction pour traiter un lot de livres
process_batch() {
    local limit="${1:-5}"
    local count=0
    
    echo "Recherche de $limit livres sans données collectées..."
    echo ""
    
    # Chercher les livres sans données
    local books=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT p.ID, pm.meta_value as isbn
        FROM wp_${SITE_ID}_posts p
        JOIN wp_${SITE_ID}_postmeta pm ON p.ID = pm.post_id
        WHERE p.post_type = 'product'
        AND p.post_status = 'publish'
        AND pm.meta_key = '_sku'
        AND pm.meta_value REGEXP '^[0-9]{9,13}$'
        AND NOT EXISTS (
            SELECT 1 FROM wp_${SITE_ID}_postmeta pm2 
            WHERE pm2.post_id = p.ID 
            AND pm2.meta_key = '_collection_status'
        )
        ORDER BY p.ID DESC
        LIMIT $limit")
    
    if [ -z "$books" ]; then
        echo -e "${YELLOW}⚠️  Aucun livre sans données trouvé${NC}"
        return
    fi
    
    # Traiter chaque livre
    while IFS=$'\t' read -r id isbn; do
        ((count++))
        echo ""
        echo "════════════════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}📚 Livre $count/$limit - ID: $id - ISBN: $isbn${NC}"
        echo "════════════════════════════════════════════════════════════════════════════════"
        
        # Traiter le livre
        process_single_book "$isbn"
        
        echo ""
        echo "Attente de 2 secondes avant le suivant..."
        sleep 2
    done <<< "$books"
    
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo -e "${GREEN}✅ Traitement terminé : $count livres traités${NC}"
    echo "════════════════════════════════════════════════════════════════════════════════"
}

# Fonction pour traiter un livre unique avec MARTINGALE COMPLÈTE
process_single_book() {
    local isbn_or_id="$1"
    local price="${2:-}"
    local condition="${3:-}"
    local stock="${4:-1}"
    
    local id=""
    local isbn=""
    
    echo "[DEBUG] process_single_book appelé avec: $isbn_or_id, prix=$price, condition=$condition" >&2
    
    # Déterminer si c'est un ID ou un ISBN
    if [[ "$isbn_or_id" =~ ^[0-9]+$ ]] && [ ${#isbn_or_id} -lt 10 ]; then
        # C'est probablement un ID
        id="$isbn_or_id"
        isbn=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT meta_value FROM wp_${SITE_ID}_postmeta 
            WHERE post_id=$id AND meta_key='_sku' LIMIT 1")
    else
        # C'est un ISBN
        isbn="${isbn_or_id//[^0-9]/}"
        
        # Chercher si le livre existe
        id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT ID FROM wp_${SITE_ID}_posts 
            WHERE post_type='product' 
            AND post_status='publish' 
            AND ID IN (
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key='_sku' AND meta_value='$isbn'
            )
            LIMIT 1")
    fi
    
    # Si le livre n'existe pas et qu'on a un ISBN, le créer
    if [ -z "$id" ] && [ -n "$isbn" ]; then
        echo "📝 Création du livre avec ISBN $isbn..."
        
        # Titre temporaire
        local temp_title="Livre ISBN $isbn"
        
        # Créer le post
        id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            INSERT INTO wp_${SITE_ID}_posts (
                post_author, post_date, post_date_gmt, post_content, 
                post_title, post_status, post_name, post_type,
                post_modified, post_modified_gmt
            ) VALUES (
                1, NOW(), NOW(), '',
                '$(safe_sql "$temp_title")', 'publish', 'livre-isbn-$isbn', 'product',
                NOW(), NOW()
            );
            SELECT LAST_INSERT_ID();")
        
        if [ -n "$id" ]; then
            echo "✅ Livre créé avec ID: $id"
            
            # Ajouter les métadonnées de base
            safe_store_meta "$id" "_sku" "$isbn"
            safe_store_meta "$id" "_isbn" "$isbn"
            safe_store_meta "$id" "_manage_stock" "yes"
            safe_store_meta "$id" "_stock" "${stock:-1}"
            safe_store_meta "$id" "_stock_status" "instock"
            safe_store_meta "$id" "_virtual" "no"
            safe_store_meta "$id" "_downloadable" "no"
            safe_store_meta "$id" "_product_type" "simple"
            safe_store_meta "$id" "_visibility" "visible"
            safe_store_meta "$id" "_featured" "no"
            safe_store_meta "$id" "_sold_individually" "yes"
            safe_store_meta "$id" "_backorders" "no"
            safe_store_meta "$id" "_tax_status" "taxable"
            safe_store_meta "$id" "_tax_class" "reduced-rate"
            
            # Prix
            if [ -n "$price" ]; then
                safe_store_meta "$id" "_price" "$price"
                safe_store_meta "$id" "_regular_price" "$price"
            fi
            
            # État
            if [ -n "$condition" ]; then
                safe_store_meta "$id" "_book_condition" "$condition"
                
                # Mapper vers Vinted
                local vinted_cond=""
                case "$condition" in
                    "neuf") vinted_cond="1" ;;
                    "comme neuf") vinted_cond="2" ;;
                    "très bon") vinted_cond="3" ;;
                    "bon") vinted_cond="4" ;;
                    "correct"|"acceptable") vinted_cond="5" ;;
                    *) vinted_cond="3" ;;
                esac
                safe_store_meta "$id" "_vinted_condition" "$vinted_cond"
            fi
        else
            echo "❌ Erreur lors de la création du livre"
            return 1
        fi
    elif [ -z "$id" ]; then
        echo "❌ Livre non trouvé"
        return 1
    fi
    
    # Capturer l'état initial
    local initial_state=$(capture_book_state "$id")
    
    # === SECTION 1 : AVANT ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        if command -v analyze_before &> /dev/null; then
            analyze_before "$id" "$isbn"
        elif command -v show_before_state &> /dev/null; then
            show_before_state "$id" "$isbn"
        fi
    fi
    
    # === SECTION 2 : COLLECTE ===
    echo ""
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${BLUE}🔄 COLLECTE DES DONNÉES VIA APIs${NC}"
    echo "════════════════════════════════════════════════════════════════════════════════"
    
    # Mise à jour du prix et condition si fournis
    if [ -n "$price" ]; then
        echo "💰 Mise à jour du prix : $price €"
        safe_store_meta "$id" "_price" "$price"
        safe_store_meta "$id" "_regular_price" "$price"
    fi
    
    if [ -n "$condition" ]; then
        echo "📋 Mise à jour de l'état : $condition"
        safe_store_meta "$id" "_book_condition" "$condition"
        
        # Mapper vers Vinted
        local vinted_cond=""
        case "$condition" in
            "neuf") vinted_cond="1" ;;
            "comme neuf") vinted_cond="2" ;;
            "très bon") vinted_cond="3" ;;
            "bon") vinted_cond="4" ;;
            "correct"|"acceptable") vinted_cond="5" ;;
            *) vinted_cond="3" ;;
        esac
        safe_store_meta "$id" "_vinted_condition" "$vinted_cond"
    fi
    
    # Vérifier si on doit forcer la collecte
    local should_collect=1
    if [ "$FORCE_MODE" != "force" ]; then
        local last_collect=$(get_meta_value "$id" "_last_collect_date")
        if [ -n "$last_collect" ]; then
            local last_timestamp=$(date -d "$last_collect" +%s 2>/dev/null || echo "0")
            local now_timestamp=$(date +%s)
            local diff=$((now_timestamp - last_timestamp))
            
            # Si collecté dans les dernières 24h
            if [ $diff -lt 86400 ]; then
                echo "⏭️  Données déjà collectées récemment. Utiliser -force pour forcer."
                should_collect=0
            fi
        fi
    fi
    
    if [ $should_collect -eq 1 ]; then
        # Collecter via toutes les APIs
        if command -v collect_all_apis &> /dev/null; then
            collect_all_apis "$isbn" "$id"
        else
            echo "⚠️  Fonction collect_all_apis non disponible"
        fi
        
        # Marquer la collecte
        safe_store_meta "$id" "_last_collect_date" "$(date '+%Y-%m-%d %H:%M:%S')"
        safe_store_meta "$id" "_collection_status" "completed"
    fi
    
    # === MARTINGALE COMPLÈTE : ENRICHISSEMENT ===
    echo ""
    echo -e "${BOLD}${PURPLE}🎯 ENRICHISSEMENT VIA MARTINGALE COMPLÈTE${NC}"
    echo "────────────────────────────────────────────────────────────────────────────────"
    
    # Appeler l'enrichissement complet
    if command -v enrich_metadata_complete &> /dev/null; then
        enrich_metadata_complete "$id" "$isbn"
    else
        echo "⚠️  Fonction enrich_metadata_complete non disponible"
    fi
    
    # Sélection des meilleures données
    if command -v select_best_data &> /dev/null; then
        select_best_data "$id"
    fi
    
    # Calculs automatiques
    if command -v calculate_all_values &> /dev/null; then
        calculate_all_values "$id"
    fi
    
    # Génération du contenu
    if command -v generate_all_content &> /dev/null; then
        generate_all_content "$id"
    fi
    
    # Mise à jour du titre WordPress avec le meilleur titre
    local best_title=$(get_meta_value "$id" "_best_title")
    if [ -n "$best_title" ] && [ "$best_title" != "Livre ISBN $isbn" ]; then
        echo "📝 Mise à jour du titre WordPress : $best_title"
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            UPDATE wp_${SITE_ID}_posts 
            SET post_title='$(safe_sql "$best_title")',
                post_name='$(safe_sql "${best_title,,}" | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')'
            WHERE ID=$id"
    fi
    
    # === SECTION 3 : APRÈS ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        if command -v analyze_after &> /dev/null; then
            analyze_after "$id" "$isbn" "$initial_state"
        elif command -v show_after_state &> /dev/null; then
            show_after_state "$id" "$isbn"
        fi
    fi
    
    # === VÉRIFICATION MARTINGALE ===
    echo ""
    echo ""
    echo -e "${BOLD}${YELLOW}🔍 VÉRIFICATION MARTINGALE COMPLÈTE${NC}"
    echo "════════════════════════════════════════════════════════════════════════════════"
    
    # Compter les champs remplis
    local filled_count=0
    local total_fields=156
    local critical_missing=""
    
    # Vérifier les champs critiques
    local critical_fields=(
        "_best_title"
        "_best_authors"
        "_best_publisher"
        "_best_description"
        "_best_pages"
        "_best_binding"
        "_best_cover_image"
        "_price"
        "_stock"
        "_isbn"
    )
    
    for field in "${critical_fields[@]}"; do
        local value=$(get_meta_value "$id" "$field")
        if [ -n "$value" ] && [ "$value" != "-" ] && [ "$value" != "0" ]; then
            ((filled_count++))
        else
            critical_missing="${critical_missing}${field} "
        fi
    done
    
    # Compter tous les champs
    local all_meta_count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id=$id 
        AND meta_key LIKE '_%'
        AND meta_value IS NOT NULL 
        AND meta_value != ''
        AND meta_value != '-'
        AND meta_value != '0'")
    
    local percent=$((all_meta_count * 100 / total_fields))
    
    echo "Champs remplis : $all_meta_count / $total_fields ($percent%)"
    
    if [ -n "$critical_missing" ]; then
        echo -e "${RED}❌ CHAMPS CRITIQUES MANQUANTS : $critical_missing${NC}"
    fi
    
    if [ $percent -eq 100 ]; then
        echo -e "${GREEN}✅ MARTINGALE COMPLÈTE : 100% des données collectées !${NC}"
    else
        echo -e "${YELLOW}❌ MARTINGALE INCOMPLÈTE : $percent%${NC}"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE (UNE SEULE FOIS À LA FIN) ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        if command -v display_martingale_complete &> /dev/null; then
            display_martingale_complete "$id"
        fi
    fi
}