#!/bin/bash
# ================================================
# ISBN UNIFIED - Système de gestion complet ISBN
# ================================================
# Fusion de : run.sh, add_book_minimal.sh, add_and_collect.sh,
# collect_api_data.sh, analyze_with_collect.sh, martingale.sh
# ================================================

# Configuration et sources
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

# Charger toutes les librairies
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/database.sh"
source "$SCRIPT_DIR/lib/enrichment.sh"
source "$SCRIPT_DIR/lib/best_data.sh"
source "$SCRIPT_DIR/lib/analyze_functions.sh"
source "$SCRIPT_DIR/lib/analyze_display.sh"
source "$SCRIPT_DIR/lib/analyze_after.sh"
source "$SCRIPT_DIR/lib/analyze_stats.sh"
source "$SCRIPT_DIR/lib/export_checks.sh"
source "$SCRIPT_DIR/lib/maintenance_tools.sh"

# Charger toutes les APIs
for api_file in "$SCRIPT_DIR"/apis/*.sh; do
    [ -f "$api_file" ] && source "$api_file"
done

# Charger tous les modules marketplace
for marketplace_file in "$SCRIPT_DIR"/lib/marketplace/*.sh; do
    [ -f "$marketplace_file" ] && source "$marketplace_file"
done

# Variables globales
VERSION="1.0"
VERBOSE=1  # Mode debug par défaut
USE_GROQ=0  # Claude par défaut
FORCE_MODE=0
NOTABLEAU=0
COLLECT_DELAY="${COLLECT_DELAY:-1}"

# Vérifier les outils disponibles
HAVE_IMAGEMAGICK=$(command -v identify &>/dev/null && echo 1 || echo 0)
HAVE_WGET=$(command -v wget &>/dev/null && echo 1 || echo 0)
HAVE_CURL=$(command -v curl &>/dev/null && echo 1 || echo 0)

# ===== FONCTIONS UTILITAIRES =====

show_usage() {
    echo ""
    echo "📚 ISBN UNIFIED v$VERSION - Gestionnaire complet"
    echo "Usage: $0 [OPTIONS] [ISBN] [PRIX] [ÉTAT] [STOCK]"
    echo ""
    echo "Options principales:"
    echo "  -p[X]          Traiter X livres incomplets"
    echo "  -force         Force la réanalyse (ignore score)"
    echo "  -notableau     Sans tableaux détaillés AVANT/APRÈS"
    echo "  -vendu ISBN    Décrémenter stock d'un livre"
    echo "  -export MARKET Exporter vers marketplace"
    echo "  -n[X]          Limiter export à X livres"
    echo "  -s[X]          Pause X secondes entre livres"
    echo "  -groq          Utiliser Groq au lieu de Claude"
    echo "  -noverbose     Moins de détails (niveau 1)"
    echo "  -noverbose2    Minimum de détails (niveau 2)"
    echo ""
    echo "États: 1=Neuf étiq. 2=Neuf 3=Très bon 4=Bon 5=Correct 6=Passable"
    echo "Marketplaces: amazon, rakuten, vinted, fnac, cdiscount, leboncoin, all"
    echo ""
    echo "Exemples:"
    echo "  $0                           # Menu interactif"
    echo "  $0 9782070368228             # Analyser un ISBN"
    echo "  $0 9782070368228 7.50 3 1    # Avec prix, état, stock"
    echo "  $0 -p10                      # Traiter 10 livres incomplets"
    echo "  $0 -force -p10               # Forcer 10 premiers livres"
    echo "  $0 -vendu 9782070368228      # Marquer comme vendu"
    echo "  $0 -export amazon -n50       # Exporter 50 livres vers Amazon"
}

# Parser les arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p*)
                BATCH_MODE=1
                BATCH_SIZE="${1#-p}"
                [ -z "$BATCH_SIZE" ] && BATCH_SIZE=10
                shift
                ;;
            -force)
                FORCE_MODE=1
                shift
                ;;
            -notableau)
                NOTABLEAU=1
                shift
                ;;
            -vendu)
                VENDU_MODE=1
                VENDU_ISBN="$2"
                shift 2
                ;;
            -export)
                EXPORT_MODE=1
                EXPORT_MARKET="$2"
                shift 2
                ;;
            -n*)
                EXPORT_LIMIT="${1#-n}"
                shift
                ;;
            -s*)
                COLLECT_DELAY="${1#-s}"
                shift
                ;;
            -groq)
                USE_GROQ=1
                shift
                ;;
            -noverbose)
                VERBOSE=1
                shift
                ;;
            -noverbose2)
                VERBOSE=0
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                # Arguments positionnels
                if [ -z "$INPUT_ISBN" ]; then
                    INPUT_ISBN="$1"
                elif [ -z "$INPUT_PRICE" ]; then
                    INPUT_PRICE="$1"
                elif [ -z "$INPUT_STATE" ]; then
                    INPUT_STATE="$1"
                elif [ -z "$INPUT_STOCK" ]; then
                    INPUT_STOCK="$1"
                fi
                shift
                ;;
        esac
    done
}

# ===== FONCTIONS HELPER =====

# Fonction pour compter les données d'un livre
count_book_data() {
    local product_id=$1
    local prefix=$2
    
    local count=$(safe_mysql "
        SELECT COUNT(*) FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $product_id 
        AND meta_key LIKE '${prefix}_%' 
        AND meta_value IS NOT NULL 
        AND meta_value != '' 
        AND meta_value != 'null' 
        AND meta_value != '0'")
    
    echo "${count:-0}"
}

# Afficher le résumé du traitement par lot
show_batch_summary() {
    local processed=$1
    local successful=$2
    local errors=$3
    local incomplete_before=$4
    local incomplete_after=$5
    local duration=$6
    
    echo ""
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "📊 RÉSUMÉ DU TRAITEMENT PAR LOT"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "📚 Livres traités      : $processed"
    echo "✅ Réussis            : $successful"
    echo "❌ Erreurs            : $errors"
    echo ""
    echo "📈 Progression        : $incomplete_before → $incomplete_after incomplets"
    echo "⏱️  Durée totale      : ${duration}s"
    echo ""
    
    if [ $incomplete_after -gt 0 ]; then
        echo "💡 Relancez avec -p$processed pour continuer"
    else
        echo "🎉 Tous les livres sont maintenant complets !"
    fi
}

# Affichage avant analyse pour vérifier l'état
show_pre_analysis_check() {
    local product_id=$1
    local isbn=$2
    
    # Récupérer les données actuelles
    local score=$(safe_get_meta "$product_id" "_export_score")
    local max_score=$(safe_get_meta "$product_id" "_export_max_score")
    local last_date=$(safe_get_meta "$product_id" "_last_analyze_date")
    local missing=$(safe_get_meta "$product_id" "_missing_data")
    
    if [ -n "$score" ] && [ -n "$max_score" ]; then
        echo ""
        echo "📊 État actuel du livre :"
        echo "─────────────────────────"
        echo "Score : $score/$max_score points"
        
        if [ -n "$last_date" ]; then
            echo "Dernière analyse : $last_date"
        fi
        
        if [ "$score" -eq "$max_score" ]; then
            echo "✅ Ce livre a déjà toutes les données nécessaires"
            echo ""
            read -p "Réanalyser quand même ? (o/N) " choice
            [ "$choice" != "o" ] && [ "$choice" != "O" ] && return 1
        else
            echo "❌ Données incomplètes : $missing"
            echo ""
            read -p "Lancer l'analyse ? (O/n) " choice
            [ "$choice" = "n" ] || [ "$choice" = "N" ] && return 1
        fi
    fi
    
    return 0
}

# ===== FONCTIONS PRINCIPALES =====

# Analyser un livre (mode AVANT/APRÈS ou compact)
analyze_book() {
    local input=$1
    local price=$2
    local condition=$3
    local stock=$4
    local product_id=""
    local isbn=""
    
    [ "$VERBOSE" -ge 1 ] && echo "[DEBUG] Paramètres: input=$input, price=$price, condition=$condition, stock=$stock" >&2
    
    # Déterminer si c'est un ID ou ISBN
    input=$(echo "$input" | tr -d '-')
    
    if [[ "$input" =~ ^[0-9]{1,6}$ ]]; then
        product_id="$input"
        isbn=$(safe_get_meta "$product_id" "_isbn")
        if [ -z "$isbn" ]; then
            echo "❌ Aucun livre trouvé avec l'ID $product_id"
            return 1
        fi
    elif [[ "$input" =~ ^[0-9]{10}$ ]] || [[ "$input" =~ ^[0-9]{13}$ ]]; then
        isbn="$input"
        product_id=$(safe_mysql "
            SELECT post_id FROM wp_${SITE_ID}_postmeta 
            WHERE meta_key = '_isbn' AND meta_value = '$isbn' LIMIT 1")
        if [ -z "$product_id" ]; then
            echo "❌ Aucun livre trouvé avec l'ISBN $isbn"
            echo ""
            read -p "Voulez-vous créer ce livre ? (o/N) " create_choice
            if [ "$create_choice" = "o" ] || [ "$create_choice" = "O" ]; then
                add_new_book "$isbn"
                return $?
            fi
            return 1
        fi
    else
        echo "❌ Format invalide. Utilisez un ID produit ou un ISBN."
        return 1
    fi
    
    # Vérifier l'état actuel (sauf si force ou mode batch)
    if [ "$FORCE_MODE" -eq 0 ] && [ "$NOTABLEAU" -eq 0 ] && [ -z "$BATCH_MODE" ]; then
        if ! show_pre_analysis_check "$product_id" "$isbn"; then
            return 0
        fi
    fi
    
    # Stocker prix si fourni
    if [ -n "$price" ] && [ "$price" != "" ] && [ "$price" != "0" ] && [ "$price" != "0.00" ]; then
        [ "$VERBOSE" -ge 1 ] && echo "[DEBUG] Stockage du prix : $price €" >&2
        safe_store_meta "$product_id" "_price" "$price"
        safe_store_meta "$product_id" "_regular_price" "$price"
    fi
    
    # Stocker état si fourni
    if [ -n "$condition" ] && [ "$condition" != "" ]; then
        # Mapper numéro vers texte
        case "$condition" in
            1) condition_text="Neuf avec étiquettes" ;;
            2) condition_text="Neuf sans étiquettes" ;;
            3) condition_text="Très bon état" ;;
            4) condition_text="Bon état" ;;
            5) condition_text="État correct" ;;
            6) condition_text="État passable" ;;
            *) condition_text="$condition" ;;
        esac
        
        [ "$VERBOSE" -ge 1 ] && echo "[DEBUG] Stockage de l'état : $condition_text" >&2
        safe_store_meta "$product_id" "_book_condition" "$condition_text"
        
        # Mapper vers Vinted
        case "$condition" in
            1|2) vinted_condition="5" ;;
            3) vinted_condition="4" ;;
            4) vinted_condition="3" ;;
            5) vinted_condition="2" ;;
            6) vinted_condition="1" ;;
            *) vinted_condition="3" ;;
        esac
        safe_store_meta "$product_id" "_vinted_condition" "$vinted_condition"
    fi
    
    # Stocker stock si fourni
    if [ -n "$stock" ] && [ "$stock" != "" ]; then
        [ "$VERBOSE" -ge 1 ] && echo "[DEBUG] Stockage du stock : $stock" >&2
        safe_store_meta "$product_id" "_stock_quantity" "$stock"
        if [ "$stock" = "0" ]; then
            safe_store_meta "$product_id" "_stock_status" "outofstock"
        else
            safe_store_meta "$product_id" "_stock_status" "instock"
        fi
    else
        # Stock par défaut = 1
        local current_stock=$(safe_get_meta "$product_id" "_stock_quantity")
        if [ -z "$current_stock" ]; then
            safe_store_meta "$product_id" "_stock_quantity" "1"
            safe_store_meta "$product_id" "_stock_status" "instock"
        fi
    fi
    
    # Code postal par défaut
    local zip=$(safe_get_meta "$product_id" "_location_zip")
    if [ -z "$zip" ]; then
        safe_store_meta "$product_id" "_location_zip" "76000"
    fi
    
    # Vérifier le prix - EN MODE BATCH NE PAS DEMANDER
    local current_price=$(safe_get_meta "$product_id" "_price")
    if [ -z "$current_price" ] || [ "$current_price" = "0" ] || [ "$current_price" = "0.00" ]; then
        if [ -z "$price" ] || [ "$price" = "" ] || [ "$price" = "0" ] || [ "$price" = "0.00" ]; then
            # Si on est en mode batch, ne pas demander interactivement
            if [ -z "$BATCH_MODE" ]; then
                echo ""
                echo "⚠️  CE LIVRE N'A PAS DE PRIX DÉFINI"
                echo "──────────────────────────────────"
                echo "Le prix est OBLIGATOIRE pour l'export vers toutes les marketplaces."
                echo ""
                read -p "Entrez le prix de vente (ex: 7.50) : " price
                
                if [ -n "$price" ] && [ "$price" != "" ] && [ "$price" != "0" ] && [ "$price" != "0.00" ]; then
                    safe_store_meta "$product_id" "_price" "$price"
                    safe_store_meta "$product_id" "_regular_price" "$price"
                fi
            fi
        fi
    fi
    
    local start_time=$(date +%s)
    
    if [ "$NOTABLEAU" -eq 1 ]; then
        # Mode compact sans tableaux
        echo ""
        echo "══════════════════════════════════════════════════════════════════════"
        echo "📚 COLLECTE RAPIDE - ISBN: $isbn"
        echo "══════════════════════════════════════════════════════════════════════"
        
        # Lancer la collecte
        if collect_all_apis "$product_id" "$isbn" "$USE_GROQ"; then
            # Affichage compact des résultats
            show_compact_collection "$product_id" "$isbn" "$start_time" "$USE_GROQ"
        else
            echo "❌ Erreur lors de la collecte"
            return 1
        fi
    else
        # Mode complet avec tableaux AVANT/APRÈS
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo "📚 ANALYSE COMPLÈTE AVEC COLLECTE - ISBN: $isbn"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo ""
        echo "Structure du rapport :"
        echo "  1️⃣  AVANT : État actuel avec toutes les données WordPress et métadonnées"
        echo "  2️⃣  COLLECTE : Résultats détaillés de chaque API"
        echo "  3️⃣  APRÈS : Données finales, images et exportabilité"
        echo ""
        
        # SECTION 1 : AVANT
        show_before_state "$product_id" "$isbn"
        
        # Compter avant
        local before_google=$(count_book_data "$product_id" "_g")
        local before_isbndb=$(count_book_data "$product_id" "_i")
        local before_ol=$(count_book_data "$product_id" "_o")
        local before_best=$(count_book_data "$product_id" "_best")
        local before_calc=$(count_book_data "$product_id" "_calculated")
        local before_total=$((before_google + before_isbndb + before_ol + before_best + before_calc))
        
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo "🔄 LANCEMENT DE LA COLLECTE"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo ""
        
        # Lancer la collecte
        if collect_all_apis "$product_id" "$isbn" "$USE_GROQ"; then
            # Compter après collecte pour détecter si nouvelles données
            local after_google_quick=$(count_book_data "$product_id" "_g")
            local new_data=$((after_google_quick - before_google))
            
            # Message si pas de nouvelles données
            if [ $new_data -eq 0 ] && [ $before_google -gt 10 ]; then
                echo ""
                echo "ℹ️  CE LIVRE A DÉJÀ ÉTÉ ANALYSÉ"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "Toutes les APIs ont déjà été interrogées pour ce livre."
                echo "Les données sont à jour et complètes."
                echo ""
                echo "💡 Utilisez -force pour forcer une nouvelle collecte"
                echo ""
            fi
            
            # SECTION 2 : COLLECTE API
            show_api_collection "$product_id" "$isbn"
            
            # SECTION 3 : APRÈS
            show_after_state "$product_id" "$isbn"
            
            # Compter après (détaillé)
            local after_google=$(count_book_data "$product_id" "_g")
            local after_isbndb=$(count_book_data "$product_id" "_i")
            local after_ol=$(count_book_data "$product_id" "_o")
            local after_best=$(count_book_data "$product_id" "_best")
            local after_calc=$(count_book_data "$product_id" "_calculated")
            local after_total=$((after_google + after_isbndb + after_ol + after_best + after_calc))
            
            # Tableau comparatif
            show_gains_table "$before_google" "$after_google" "$before_isbndb" "$after_isbndb" \
                             "$before_ol" "$after_ol" "$before_best" "$after_best" \
                             "$before_calc" "$after_calc" "$before_total" "$after_total"
            
            local gain_total=$((after_total - before_total))
            
            # Message final adapté
            if [ $gain_total -eq 0 ] && [ $before_total -gt 20 ]; then
                echo ""
                echo "ℹ️  Aucune nouvelle donnée collectée"
                echo "   Causes possibles :"
                echo "   • Le livre a déjà toutes les données disponibles"
                echo "   • Les APIs n'ont pas d'informations supplémentaires"
                echo "   • Utilisez -force pour réinterroger les APIs"
            else
                show_final_stats "$product_id" "$gain_total"
            fi
        else
            echo "❌ Erreur lors de la collecte"
            return 1
        fi
    fi
    
    # Commande pour nouvelle analyse - SEULEMENT SI PAS EN MODE BATCH
    if [ -z "$BATCH_MODE" ]; then
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo "🔄 NOUVELLE ANALYSE"
        echo ""
        echo "Pour analyser un autre livre :"
        echo "./isbn_unified.sh [ISBN] [prix] [état] [stock]"
        echo ""
        echo "Exemples :"
        echo "./isbn_unified.sh 9782070368228                    # Interactif"
        echo "./isbn_unified.sh 9782070368228 7.50 3 1           # Tout défini"
        echo "./isbn_unified.sh -notableau 9782070368228         # Sans tableaux"
        echo "./isbn_unified.sh -vendu 9782070368228             # Marquer vendu"
        echo ""
        echo "États : 1=Neuf étiq. 2=Neuf 3=Très bon 4=Bon 5=Correct 6=Passable"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    fi
}

# Affichage compact pour mode sans tableaux
show_compact_collection() {
    local product_id=$1
    local isbn=$2
    local start_time=$3
    local use_groq=$4
    
    # Calculer durée
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo "✅ COLLECTE TERMINÉE en ${duration}s"
    echo ""
    
    # Afficher les données essentielles
    local title=$(get_best_value "title" "$product_id")
    local authors=$(get_best_value "authors" "$product_id")
    local publisher=$(get_best_value "publisher" "$product_id")
    local pages=$(get_best_value "pages" "$product_id")
    local price=$(get_best_value "price" "$product_id")
    local has_desc=$(safe_get_meta "$product_id" "_has_description")
    local has_image=$(get_best_value "image" "$product_id")
    
    echo "📖 DONNÉES COLLECTÉES :"
    echo "─────────────────────"
    [ -n "$title" ] && echo "Titre      : $title"
    [ -n "$authors" ] && echo "Auteur(s)  : $authors"
    [ -n "$publisher" ] && echo "Éditeur    : $publisher"
    [ -n "$pages" ] && [ "$pages" != "0" ] && echo "Pages      : $pages"
    [ -n "$price" ] && [ "$price" != "0" ] && echo "Prix       : $price €"
    
    # Status description
    if [ "$has_desc" = "1" ]; then
        local desc_source=$(safe_get_meta "$product_id" "_best_description_source")
        [ -z "$desc_source" ] && desc_source=$(safe_get_meta "$product_id" "_description_source")
        echo "Description: ✅ Générée par ${desc_source:-IA}"
    else
        echo "Description: ❌ Manquante"
    fi
    
    # Status image
    if [ -n "$has_image" ]; then
        echo "Image      : ✅ Disponible"
    else
        echo "Image      : ❌ Manquante"
    fi
    
    # Score d'exportabilité
    calculate_export_score "$product_id" > /dev/null
    local score=$(safe_get_meta "$product_id" "_export_score")
    local max_score=$(safe_get_meta "$product_id" "_export_max_score")
    
    echo ""
    echo "📊 EXPORTABILITÉ : $score/$max_score points"
    
    # Marketplaces prêtes
    local ready_markets=$(get_ready_marketplaces "$product_id")
    if [ -n "$ready_markets" ]; then
        echo "✅ Prêt pour : $ready_markets"
    else
        echo "❌ Aucune marketplace prête"
    fi
}

# Ajouter un nouveau livre
add_new_book() {
    local isbn=$1
    
    # Nettoyer l'ISBN
    isbn=$(echo "$isbn" | tr -d '-')
    
    # Vérifier le format
    if [[ ! "$isbn" =~ ^[0-9]{10}$ ]] && [[ ! "$isbn" =~ ^[0-9]{13}$ ]]; then
        echo "❌ Format d'ISBN invalide"
        return 1
    fi
    
    # Vérifier qu'il n'existe pas déjà
    local existing=$(safe_mysql "
        SELECT post_id FROM wp_${SITE_ID}_postmeta 
        WHERE meta_key = '_isbn' AND meta_value = '$isbn' LIMIT 1")
    
    if [ -n "$existing" ]; then
        echo "❌ Ce livre existe déjà avec l'ID : $existing"
        read -p "Voulez-vous lancer l'analyse pour ce livre ? (o/N) " choice
        if [ "$choice" = "o" ] || [ "$choice" = "O" ]; then
            analyze_book "$existing"
        fi
        return 0
    fi
    
    echo ""
    echo "📖 AJOUT D'UN NOUVEAU LIVRE"
    echo "─────────────────────────────"
    echo "ISBN : $isbn"
    echo ""
    echo "Recherche des informations de base..."
    
    # Créer un titre temporaire
    local title="Livre ISBN $isbn"
    local product_id=""
    
    # Date actuelle
    local current_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Créer le produit
    echo "Création du produit dans WordPress..."
    local result=$(safe_mysql "
        INSERT INTO wp_${SITE_ID}_posts (
            post_author, post_date, post_date_gmt, post_content, post_title,
            post_excerpt, post_status, comment_status, ping_status, post_name,
            post_modified, post_modified_gmt, post_parent, menu_order, post_type
        ) VALUES (
            1, '$current_date', '$current_date', '', 'Livre $isbn',
            '', 'publish', 'open', 'closed', 'livre-$isbn',
            '$current_date', '$current_date', 0, 0, 'product'
        );
        SELECT LAST_INSERT_ID();")
    
    product_id=$(echo "$result" | tail -1)
    
    if [ -z "$product_id" ] || [ "$product_id" = "0" ]; then
        echo "❌ Erreur lors de la création du produit"
        return 1
    fi
    
    echo "✅ Produit créé avec l'ID : $product_id"
    
    # Ajouter les métadonnées de base
    echo "Ajout des métadonnées..."
    safe_store_meta "$product_id" "_isbn" "$isbn"
    safe_store_meta "$product_id" "_sku" "$isbn"
    safe_store_meta "$product_id" "_price" "0"
    safe_store_meta "$product_id" "_regular_price" "0"
    safe_store_meta "$product_id" "_stock_quantity" "1"
    safe_store_meta "$product_id" "_stock_status" "instock"
    safe_store_meta "$product_id" "_manage_stock" "no"
    safe_store_meta "$product_id" "_virtual" "no"
    safe_store_meta "$product_id" "_downloadable" "no"
    
    echo "✅ Métadonnées ajoutées"
    echo ""
    echo "Lancement de la collecte de données..."
    
    # Analyser directement
    analyze_book "$product_id"
}

# Marquer un livre comme vendu
mark_as_sold() {
    local isbn=$1
    
    # Nettoyer l'ISBN
    isbn=$(echo "$isbn" | tr -d '-')
    
    # Trouver le produit
    local product_id=$(get_product_id_from_input "$isbn")
    
    if [ -z "$product_id" ]; then
        echo "❌ Aucun livre trouvé avec l'ISBN $isbn"
        return 1
    fi
    
    # Récupérer le stock actuel
    local current_stock=$(safe_get_meta "$product_id" "_stock_quantity")
    if [ -z "$current_stock" ]; then
        current_stock="1"
    fi
    
    echo ""
    echo "📦 GESTION DU STOCK"
    echo "──────────────────"
    echo "Livre #$product_id - ISBN: $isbn"
    echo "Stock actuel : $current_stock exemplaire(s)"
    echo ""
    
    if [ "$current_stock" = "0" ]; then
        echo "❌ Erreur : Ce livre est déjà épuisé (stock = 0)"
        echo "💡 Conseil : Utilisez l'option -force pour remettre en stock"
        return 1
    fi
    
    # Décrémenter le stock
    local new_stock=$((current_stock - 1))
    
    echo "📉 Mise à jour : $current_stock → $new_stock exemplaire(s)"
    
    safe_store_meta "$product_id" "_stock_quantity" "$new_stock"
    
    if [ "$new_stock" = "0" ]; then
        safe_store_meta "$product_id" "_stock_status" "outofstock"
        echo "⚠️  Dernier exemplaire vendu ! Stock : 0 (épuisé)"
    else
        echo "✅ Stock mis à jour : $new_stock exemplaire(s) restant(s)"
    fi
    
    # Ajouter une note de vente
    safe_store_meta "$product_id" "_last_sold_date" "$(date '+%Y-%m-%d %H:%M:%S')"
}

# Traiter par lot
process_batch() {
    local batch_size=$1
    local start_time=$(date +%s)
    
    echo ""
    echo "🔄 TRAITEMENT PAR LOT (-p$batch_size)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Compter les livres incomplets
    local total_incomplete=$(count_incomplete_books "$FORCE_MODE")
    
    if [ "$total_incomplete" = "0" ]; then
        echo "✅ Tous les livres sont déjà complets !"
        if [ "$FORCE_MODE" -eq 0 ]; then
            echo "💡 Utilisez -force -p$batch_size pour retraiter quand même"
        fi
        return 0
    fi
    
    echo "Recherche des livres incomplets..."
    echo "✓ $total_incomplete livres nécessitent une analyse"
    echo ""
    echo "Traitement des $batch_size premiers :"
    echo ""
    
    # Récupérer les livres à traiter
    local books=$(select_incomplete_books "$batch_size" "$FORCE_MODE")
    
    local current=0
    local successful=0
    local errors=0
    
    while IFS=$'\t' read -r product_id isbn; do
        ((current++))
        
        # Afficher la progression
        echo "[$current/$batch_size] ISBN $isbn (ID #$product_id) - Analyse..."
        
        # Analyser le livre AVEC AFFICHAGE COMPLET
        if analyze_book "$product_id"; then
            ((successful++))
            echo "[$current/$batch_size] ✅ ISBN $isbn - Terminé"
        else
            ((errors++))
            echo "[$current/$batch_size] ❌ ISBN $isbn - Erreur"
        fi
        
        # Pause entre les livres
        if [ $current -lt $batch_size ] && [ "$COLLECT_DELAY" -gt 0 ]; then
            sleep "$COLLECT_DELAY"
        fi
        
        echo ""
    done <<< "$books"
    
    # Recompter après traitement
    local remaining=$(count_incomplete_books "$FORCE_MODE")
    
    # Durée totale
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Résumé
    show_batch_summary "$current" "$successful" "$errors" "$total_incomplete" "$remaining" "$duration"
}

# Exporter vers marketplace
export_to_marketplace() {
    local marketplace=$1
    local limit=${2:-0}
    
    echo ""
    echo "📤 EXPORT VERS MARKETPLACE"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Vérifier que le script d'export existe
    local export_script="$SCRIPT_DIR/exports/export_${marketplace}.sh"
    
    if [ "$marketplace" = "all" ]; then
        # Exporter vers toutes les marketplaces
        for market in amazon rakuten vinted fnac cdiscount leboncoin; do
            if [ -f "$SCRIPT_DIR/exports/export_${market}.sh" ]; then
                echo "Export vers $market..."
                if [ "$limit" -gt 0 ]; then
                    "$SCRIPT_DIR/exports/export_${market}.sh" -n "$limit"
                else
                    "$SCRIPT_DIR/exports/export_${market}.sh"
                fi
                echo ""
            fi
        done
    elif [ -f "$export_script" ]; then
        echo "Export vers $marketplace..."
        if [ "$limit" -gt 0 ]; then
            "$export_script" -n "$limit"
        else
            "$export_script"
        fi
    else
        echo "❌ Script d'export non trouvé : $export_script"
        echo ""
        echo "Marketplaces disponibles :"
        echo "  amazon, rakuten, vinted, fnac, cdiscount, leboncoin, all"
    fi
}

# Générer rapport complet (ex-martingale)
generate_full_report() {
    local product_id=$1
    local isbn=$2
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 FICHE COMPLÈTE - ISBN: $isbn"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Récupérer toutes les données
    local all_data=$(safe_mysql "
        SELECT meta_key, meta_value 
        FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $product_id 
        AND meta_key LIKE '_%'
        AND meta_key NOT LIKE '_wp_%'
        AND meta_key NOT LIKE '_edit_%'
        ORDER BY meta_key")
    
    # Créer tableau associatif
    declare -A book_data
    while IFS=$'\t' read -r key value; do
        book_data["$key"]="$value"
    done <<< "$all_data"
    
    # Récupérer les données finales
    local title="${book_data[_best_title]:-${book_data[_g_title]:-${book_data[_i_title]:-${book_data[_o_title]:-}}}}"
    local authors="${book_data[_best_authors]:-${book_data[_g_authors]:-${book_data[_i_authors]:-${book_data[_o_authors]:-}}}}"
    local publisher="${book_data[_best_publisher]:-${book_data[_g_publisher]:-${book_data[_i_publisher]:-${book_data[_o_publishers]:-}}}}"
    local pages="${book_data[_best_pages]:-${book_data[_g_pageCount]:-${book_data[_i_pages]:-${book_data[_o_number_of_pages]:-0}}}}"
    local binding="${book_data[_i_binding]:-${book_data[_o_physical_format]:-Broché}}"
    local language="${book_data[_g_language]:-${book_data[_i_language]:-fr}}"
    local price="${book_data[_price]:-0}"
    local stock="${book_data[_stock_quantity]:-1}"
    local condition="${book_data[_book_condition]:-Non défini}"
    
    # Description
    local description="${book_data[_best_description]:-${book_data[_claude_description]:-${book_data[_groq_description]:-${book_data[_g_description]:-}}}}"
    
    # Affichage
    echo "📖 INFORMATIONS PRINCIPALES"
    echo "──────────────────────────"
    echo "Titre      : $title"
    echo "Auteur(s)  : ${authors:-Non renseigné}"
    echo "Éditeur    : ${publisher:-Non renseigné}"
    echo "Pages      : $pages"
    echo "Reliure    : $binding"
    echo "Langue     : $language"
    echo ""
    
    echo "💰 DONNÉES COMMERCIALES"
    echo "──────────────────────"
    echo "Prix       : $price €"
    echo "Stock      : $stock exemplaire(s)"
    echo "État       : $condition"
    echo "ISBN       : $isbn"
    echo ""
    
    # Images disponibles
    echo "🖼️ IMAGES DISPONIBLES"
    echo "────────────────────"
    local img_count=0
    for key in _g_thumbnail _g_small _g_medium _g_large _g_extraLarge _i_image _o_cover_small _o_cover_medium _o_cover_large; do
        if [ -n "${book_data[$key]}" ] && [ "${book_data[$key]}" != "null" ]; then
            echo "✓ ${key#_} : ${book_data[$key]:0:60}..."
            ((img_count++))
        fi
    done
    [ $img_count -eq 0 ] && echo "✗ Aucune image trouvée"
    echo ""
    
    echo "📝 DESCRIPTION"
    echo "─────────────"
    if [ -n "$description" ]; then
        echo "$description" | fold -w 70 -s | head -10
        [ ${#description} -gt 700 ] && echo "..."
    else
        echo "✗ Aucune description disponible"
    fi
    echo ""
    
    # Score d'exportabilité
    source "$SCRIPT_DIR/lib/export_checks.sh"
    show_export_summary "$product_id" "$isbn"
}

# Menu principal
show_main_menu() {
    clear
    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    echo "📚 ISBN UNIFIED v$VERSION - SYSTÈME DE GESTION COMPLET"
    echo "══════════════════════════════════════════════════════════════════════"
    echo ""
    echo "📖 COLLECTE ET ANALYSE"
    echo "  1) Analyse complète (tableaux AVANT/APRÈS)"
    echo "  2) Collecte rapide (sans tableaux)"
    echo "  3) Ajouter un nouveau livre"
    echo "  4) Traiter par lot (-pX livres incomplets)"
    echo ""
    echo "📦 GESTION DU STOCK"
    echo "  5) Marquer un livre comme vendu"
    echo ""
    echo "📊 RAPPORTS"
    echo "  6) Rapport complet d'un livre"
    echo "  7) Générer rapport statistiques"
    echo ""
    echo "🚀 EXPORT"
    echo "  8) Exporter vers marketplaces"
    echo ""
    echo "🔧 OUTILS"
    echo "  9) Catégorisation IA double"
    echo " 10) Tester les APIs"
    echo " 11) Maintenance"
    echo ""
    echo "  0) Quitter"
    echo ""
    echo "══════════════════════════════════════════════════════════════════════"
    read -p "Votre choix : " choice
    
    case $choice in
        1)
            echo ""
            read -p "ISBN ou ID du livre : " input
            [ -n "$input" ] && analyze_book "$input"
            ;;
        2)
            NOTABLEAU=1
            echo ""
            read -p "ISBN ou ID du livre : " input
            [ -n "$input" ] && analyze_book "$input"
            ;;
        3)
            echo ""
            read -p "ISBN du nouveau livre : " isbn
            [ -n "$isbn" ] && add_new_book "$isbn"
            ;;
        4)
            echo ""
            read -p "Nombre de livres à traiter (défaut: 10) : " batch
            [ -z "$batch" ] && batch=10
            process_batch "$batch"
            ;;
        5)
            echo ""
            read -p "ISBN du livre vendu : " isbn
            [ -n "$isbn" ] && mark_as_sold "$isbn"
            ;;
        6)
            echo ""
            read -p "ISBN ou ID du livre : " input
            if [ -n "$input" ]; then
                local pid=$(get_product_id_from_input "$input")
                local isbn=$(safe_get_meta "$pid" "_isbn")
                [ -n "$pid" ] && generate_full_report "$pid" "$isbn"
            fi
            ;;
        7)
            if [ -f "$SCRIPT_DIR/generate_report.sh" ]; then
                "$SCRIPT_DIR/generate_report.sh"
            else
                echo "❌ Script generate_report.sh non trouvé"
            fi
            ;;
        8)
            echo ""
            echo "EXPORT VERS MARKETPLACES :"
            echo "1) Amazon"
            echo "2) Rakuten"
            echo "3) Vinted"
            echo "4) Fnac"
            echo "5) Cdiscount"
            echo "6) Leboncoin"
            echo "7) TOUTES les marketplaces"
            echo "0) Retour"
            echo ""
            read -p "Votre choix : " export_choice
            
            case $export_choice in
                1) export_to_marketplace "amazon" ;;
                2) export_to_marketplace "rakuten" ;;
                3) export_to_marketplace "vinted" ;;
                4) export_to_marketplace "fnac" ;;
                5) export_to_marketplace "cdiscount" ;;
                6) export_to_marketplace "leboncoin" ;;
                7) export_to_marketplace "all" ;;
            esac
            ;;
        9)
            if [ -f "$SCRIPT_DIR/smart_categorize_dual_ai.sh" ]; then
                "$SCRIPT_DIR/smart_categorize_dual_ai.sh"
            else
                echo "❌ Script smart_categorize_dual_ai.sh non trouvé"
            fi
            ;;
        10)
            if [ -f "$SCRIPT_DIR/test_apis.sh" ]; then
                "$SCRIPT_DIR/test_apis.sh"
            else
                echo "❌ Script test_apis.sh non trouvé"
            fi
            ;;
        11)
            show_maintenance_menu
            ;;
        0)
            echo "Au revoir !"
            exit 0
            ;;
        *)
            echo "❌ Choix invalide"
            ;;
    esac
    
    echo ""
    read -p "Appuyez sur ENTRÉE pour continuer..."
    show_main_menu
}

# ===== POINT D'ENTRÉE PRINCIPAL =====

# Avertissements sur les outils manquants
[ $HAVE_IMAGEMAGICK -eq 0 ] && echo "⚠️  ImageMagick non installé (vérification images limitée)"
[ $HAVE_WGET -eq 0 ] && echo "⚠️  wget non installé (import images impossible)"

# Parser les arguments
parse_arguments "$@"

# Logique principale
if [ -n "$BATCH_MODE" ]; then
    # Mode traitement par lot
    process_batch "$BATCH_SIZE"
elif [ -n "$VENDU_MODE" ]; then
    # Mode marquer comme vendu
    mark_as_sold "$VENDU_ISBN"
elif [ -n "$EXPORT_MODE" ]; then
    # Mode export
    export_to_marketplace "$EXPORT_MARKET" "$EXPORT_LIMIT"
elif [ -n "$INPUT_ISBN" ]; then
    # Mode analyse directe
    analyze_book "$INPUT_ISBN" "$INPUT_PRICE" "$INPUT_STATE" "$INPUT_STOCK"
else
    # Menu interactif
    show_main_menu
fi