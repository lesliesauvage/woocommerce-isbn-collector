#!/bin/bash
# analyze_with_collect.sh - Analyse structurée AVANT/API/APRÈS avec colonnes XXL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"
source "$SCRIPT_DIR/lib/analyze_functions.sh"
source "$SCRIPT_DIR/lib/analyze_display.sh"
source "$SCRIPT_DIR/lib/analyze_after.sh"
source "$SCRIPT_DIR/lib/analyze_stats.sh"

# Charger toutes les fonctions marketplace
for marketplace_file in "$SCRIPT_DIR"/lib/marketplace/*.sh; do
    [ -f "$marketplace_file" ] && source "$marketplace_file"
done

# Fonction pour compter les données
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

# Fonction principale d'analyse avec collecte
analyze_and_collect() {
    local input=$1
    local price=$2
    local condition=$3
    local product_id=""
    local isbn=""
    
    # DEBUG : Afficher les paramètres reçus
    echo "DEBUG: Paramètres reçus - input=$input, price=$price, condition=$condition" >&2
    
    # Déterminer si c'est un ID ou un ISBN
    input=$(echo "$input" | tr -d '-')  # Enlever les tirets
    
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
            return 1
        fi
    else
        echo "❌ Format invalide. Utilisez un ID produit ou un ISBN."
        return 1
    fi
    
    # STOCKER LE PRIX IMMÉDIATEMENT SI FOURNI
    if [ -n "$price" ] && [ "$price" != "" ] && [ "$price" != "0" ]; then
        echo "💰 Stockage du prix : $price €"
        safe_store_meta "$product_id" "_price" "$price"
        safe_store_meta "$product_id" "_regular_price" "$price"
        # Vérifier que c'est bien stocké
        local verify_price=$(safe_get_meta "$product_id" "_price")
        echo "   Vérification : prix stocké = $verify_price €"
    fi
    
    # STOCKER L'ÉTAT SI FOURNI
    if [ -n "$condition" ] && [ "$condition" != "" ]; then
        echo "📖 Stockage de l'état : $condition"
        safe_store_meta "$product_id" "_book_condition" "$condition"
        
        # Mapper l'état vers Vinted (1-5)
        case "$condition" in
            "neuf"|"Neuf") vinted_condition="5" ;;
            "comme neuf"|"Comme neuf") vinted_condition="4" ;;
            "très bon"|"Très bon") vinted_condition="3" ;;
            "bon"|"Bon") vinted_condition="3" ;;
            "correct"|"Correct") vinted_condition="2" ;;
            "mauvais"|"Mauvais") vinted_condition="1" ;;
            *) vinted_condition="3" ;;  # Par défaut
        esac
        safe_store_meta "$product_id" "_vinted_condition" "$vinted_condition"
    fi
    
    # Code postal par défaut 76000
    local zip=$(safe_get_meta "$product_id" "_location_zip")
    if [ -z "$zip" ]; then
        safe_store_meta "$product_id" "_location_zip" "76000"
    fi
    
    # Vérifier si le livre a déjà un prix, sinon le demander
    local current_price=$(safe_get_meta "$product_id" "_price")
    if [ -z "$current_price" ] || [ "$current_price" = "0" ]; then
        if [ -z "$price" ] || [ "$price" = "" ] || [ "$price" = "0" ]; then
            echo ""
            echo "⚠️  CE LIVRE N'A PAS DE PRIX DÉFINI"
            echo "──────────────────────────────────"
            echo "Le prix est OBLIGATOIRE pour l'export vers toutes les marketplaces."
            echo ""
            read -p "Entrez le prix de vente (ex: 7.50) : " price
            
            if [ -n "$price" ] && [ "$price" != "" ] && [ "$price" != "0" ]; then
                echo "💰 Stockage du prix saisi : $price €"
                safe_store_meta "$product_id" "_price" "$price"
                safe_store_meta "$product_id" "_regular_price" "$price"
            fi
        fi
    fi
    
    # SECTION 1 : AVANT
    show_before_state "$product_id" "$isbn"
    
    # Compter avant
    local before_google=$(count_book_data "$product_id" "_g")
    local before_isbndb=$(count_book_data "$product_id" "_i")
    local before_ol=$(count_book_data "$product_id" "_o")
    local before_best=$(count_book_data "$product_id" "_best")
    local before_calc=$(count_book_data "$product_id" "_calculated")
    local before_total=$((before_google + before_isbndb + before_ol + before_best + before_calc))
    
    # Demander confirmation pour la collecte
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "🔄 LANCEMENT DE LA COLLECTE"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Appuyer sur ENTRÉE pour lancer la collecte des données via APIs..."
    echo "(ou CTRL+C pour annuler)"
    read
    
    # Lancer la collecte
    echo "🔄 Collecte en cours..."
    "$SCRIPT_DIR/collect_api_data.sh" "p.ID = $product_id"
    
    sleep 2
    
    # CORRECTION DU BUG PUBLISHER
    local best_publisher=$(safe_get_meta "$product_id" "_best_publisher")
    if [ -z "$best_publisher" ] || [ "$best_publisher" = "null" ]; then
        local i_publisher=$(safe_get_meta "$product_id" "_i_publisher")
        if [ -n "$i_publisher" ] && [ "$i_publisher" != "null" ]; then
            safe_store_meta "$product_id" "_best_publisher" "$i_publisher"
            safe_store_meta "$product_id" "_best_publisher_source" "isbndb"
        else
            local o_publisher=$(safe_get_meta "$product_id" "_o_publishers")
            if [ -n "$o_publisher" ] && [ "$o_publisher" != "null" ]; then
                safe_store_meta "$product_id" "_best_publisher" "$o_publisher"
                safe_store_meta "$product_id" "_best_publisher_source" "openlibrary"
            fi
        fi
    fi
    
    # NE PAS EFFACER L'ÉCRAN ICI !
    # clear  # SUPPRIMÉ
    
    # SECTION 2 : COLLECTE API
    show_api_collection "$product_id" "$isbn"
    
    # SECTION 3 : APRÈS
    show_after_state "$product_id" "$isbn"
    
    # Calculer les gains
    local after_google=$(count_book_data "$product_id" "_g")
    local after_isbndb=$(count_book_data "$product_id" "_i")
    local after_ol=$(count_book_data "$product_id" "_o")
    local after_best=$(count_book_data "$product_id" "_best")
    local after_calc=$(count_book_data "$product_id" "_calculated")
    local after_total=$((after_google + after_isbndb + after_ol + after_best + after_calc))
    
    # Tableau comparatif final (utilise la fonction du module stats)
    show_gains_table "$before_google" "$after_google" "$before_isbndb" "$after_isbndb" \
                     "$before_ol" "$after_ol" "$before_best" "$after_best" \
                     "$before_calc" "$after_calc" "$before_total" "$after_total"
    
    local gain_total=$?
    
    # Message final (utilise la fonction du module stats)
    show_final_stats "$product_id" "$gain_total"
    
    # Prompt pour nouvelle session (utilise la fonction du module stats)
    show_new_session_prompt
}

# Menu principal
echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
echo "📚 ANALYSE COMPLÈTE AVEC COLLECTE - VERSION STRUCTURÉE"
echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Structure du rapport :"
echo "  1️⃣  AVANT : État actuel avec toutes les données WordPress et métadonnées"
echo "  2️⃣  COLLECTE : Résultats détaillés de chaque API"
echo "  3️⃣  APRÈS : Données finales, images et exportabilité"
echo ""
echo "Usage :"
echo "  $0 [ISBN/ID] [prix] [état]"
echo ""
echo "États possibles : neuf, comme neuf, très bon, bon, correct, mauvais"
echo ""

# Gérer les paramètres
if [ -n "$1" ]; then
    input="$1"
    price="$2"
    condition="$3"
    echo "DEBUG: Mode ligne de commande - input=$input, price=$price, condition=$condition"
else
    echo "Entrez l'ID du produit ou l'ISBN :"
    read -p "> " input
    echo ""
    echo "Prix de vente (laisser vide pour ne pas modifier) :"
    read -p "> " price
    echo ""
    echo "État du livre :"
    echo "  1) Neuf avec étiquettes"
    echo "  2) Neuf sans étiquettes"  
    echo "  3) Très bon état"
    echo "  4) Bon état"
    echo "  5) État correct"
    echo "  6) État passable"
    echo ""
    read -p "Votre choix (1-6 ou laisser vide) : " condition_choice
    
    case $condition_choice in
        1) condition="neuf" ;;
        2) condition="comme neuf" ;;
        3) condition="très bon" ;;
        4) condition="bon" ;;
        5) condition="correct" ;;
        6) condition="mauvais" ;;
        *) condition="" ;;
    esac
    echo "DEBUG: Mode interactif - input=$input, price=$price, condition=$condition"
fi

# Lancer l'analyse
analyze_and_collect "$input" "$price" "$condition"