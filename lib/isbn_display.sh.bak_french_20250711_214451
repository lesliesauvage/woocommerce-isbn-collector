#!/bin/bash
echo "[START: isbn_display.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# Bibliothèque de fonctions d'affichage pour isbn_unified.sh
# Gère l'affichage de l'aide, des résultats et des états

# Fonction d'aide
show_help() {
    cat << EOF
══════════════════════════════════════════════════════════════════════════════════════════════
                             📚 ISBN UNIFIED V4 - Script complet avec Martingale
══════════════════════════════════════════════════════════════════════════════════════════════

UTILISATION :
    ./isbn_unified.sh [OPTIONS] [ISBN] [prix] [état] [stock]

OPTIONS :
    -h, --help          Afficher cette aide
    -force              Forcer la collecte même si déjà fait
    -notableau          Mode compact sans tableaux détaillés
    -simple             Mode très simplifié (ID et titre uniquement)
    -vendu              Marquer le livre comme vendu
    -nostatus           Ne pas afficher le statut de collecte
    -p[N]               Traiter les N prochains livres sans données
    -export             Exporter vers les marketplaces

PARAMÈTRES :
    ISBN               Code ISBN ou ID du produit (optionnel si mode -p)
    prix               Prix de vente en euros (optionnel)
    état               1=Neuf avec étiquette, 2=Neuf, 3=Très bon, 4=Bon, 5=Correct, 6=Passable
    stock              Quantité en stock (défaut: 1)

EXEMPLES :
    ./isbn_unified.sh                         # Mode interactif
    ./isbn_unified.sh 9782070368228          # Analyse simple
    ./isbn_unified.sh 9782070368228 7.50     # Avec prix
    ./isbn_unified.sh 9782070368228 7.50 3 1 # Complet
    ./isbn_unified.sh -p10                   # 10 prochains livres
    ./isbn_unified.sh -vendu 12345           # Marquer vendu
    ./isbn_unified.sh -force 12345           # Forcer collecte

══════════════════════════════════════════════════════════════════════════════════════════════
EOF
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$1"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$1"
    fi
}

# Fonction pour afficher les résultats des APIs
show_api_results() {
    local id=$1
    
    # Google Books
    echo ""
    echo -e "${BLUE}🔵 GOOGLE BOOKS API${NC}"
    local g_test=$(get_meta_value "$id" "_g_title")
    local google_timestamp=$(get_meta_timestamp "$id" "_google_last_attempt")
    
    if [ -n "$g_test" ]; then
        echo -e "${GREEN}✅ Statut : Données collectées avec succès${NC}"
        echo -e "${CYAN}⏰ Collecté le : $google_timestamp${NC}"
    else
        local google_attempt=$(get_meta_value "$id" "_google_last_attempt")
        if [ -n "$google_attempt" ]; then
            echo -e "${YELLOW}⚠️  Statut : Aucune donnée trouvée pour cet ISBN${NC}"
            echo -e "${YELLOW}⏰ Dernière tentative : $google_attempt${NC}"
        else
            echo -e "${RED}❌ Statut : Jamais collecté${NC}"
        fi
    fi
    
    # ISBNdb
    echo ""
    echo -e "${GREEN}🟢 ISBNDB API${NC}"
    local i_test=$(get_meta_value "$id" "_i_title")
    local isbndb_timestamp=$(get_meta_timestamp "$id" "_isbndb_last_attempt")
    
    if [ -n "$i_test" ]; then
        echo -e "${GREEN}✅ Statut : Données collectées avec succès${NC}"
        echo -e "${CYAN}⏰ Collecté le : $isbndb_timestamp${NC}"
    else
        local isbndb_attempt=$(get_meta_value "$id" "_isbndb_last_attempt")
        if [ -n "$isbndb_attempt" ]; then
            echo -e "${YELLOW}⚠️  Statut : Aucune donnée trouvée pour cet ISBN${NC}"
            echo -e "${YELLOW}⏰ Dernière tentative : $isbndb_attempt${NC}"
        else
            echo -e "${RED}❌ Statut : Jamais collecté${NC}"
        fi
    fi
    
    # Open Library
    echo ""
    echo -e "${YELLOW}🟠 OPEN LIBRARY API${NC}"
    local o_test=$(get_meta_value "$id" "_o_title")
    local openlibrary_timestamp=$(get_meta_timestamp "$id" "_openlibrary_last_attempt")
    
    if [ -n "$o_test" ]; then
        echo -e "${GREEN}✅ Statut : Données collectées avec succès${NC}"
        echo -e "${CYAN}⏰ Collecté le : $openlibrary_timestamp${NC}"
    else
        local openlibrary_attempt=$(get_meta_value "$id" "_openlibrary_last_attempt")
        if [ -n "$openlibrary_attempt" ]; then
            echo -e "${YELLOW}⚠️  Statut : Aucune donnée trouvée pour cet ISBN${NC}"
            echo -e "${YELLOW}⏰ Dernière tentative : $openlibrary_attempt${NC}"
        else
            echo -e "${RED}❌ Statut : Jamais collecté${NC}"
        fi
    fi
    
    # Claude AI
    echo ""
    echo -e "${PURPLE}🤖 CLAUDE AI${NC}"
    local claude_desc=$(get_meta_value "$id" "_claude_description")
    
    if [ -n "$claude_desc" ] && [ ${#claude_desc} -gt 20 ]; then
        echo -e "${GREEN}✅ Statut : Description générée avec succès${NC}"
        echo -e "${CYAN}📝 Longueur : ${#claude_desc} caractères${NC}"
    else
        echo -e "${RED}❌ Statut : Pas de description Claude${NC}"
    fi
    
    # Groq AI
    echo ""
    echo -e "${CYAN}🧠 GROQ AI${NC}"
    local groq_desc=$(get_meta_value "$id" "_groq_description")
    
    if [ -n "$groq_desc" ] && [ ${#groq_desc} -gt 20 ]; then
        echo -e "${GREEN}✅ Statut : Description générée avec succès${NC}"
        echo -e "${CYAN}📝 Longueur : ${#groq_desc} caractères${NC}"
    else
        echo -e "${RED}❌ Statut : Pas de description Groq${NC}"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$id"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$id"
    fi
}

# Fonction pour afficher le statut de collecte détaillé
show_collection_status() {
    local id=$1
    local isbn=$2
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${CYAN}📊 STATUT DE COLLECTE DÉTAILLÉ${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    # Vérifier chaque API
    local apis=(
        "Google Books:_google_last_attempt:_g_title"
        "ISBNdb:_isbndb_last_attempt:_i_title"
        "Open Library:_openlibrary_last_attempt:_o_title"
        "Claude AI:_claude_ai_date:_claude_description"
        "Groq AI:_groq_ai_date:_groq_description"
    )
    
    for api_info in "${apis[@]}"; do
        IFS=':' read -r api_name timestamp_field data_field <<< "$api_info"
        
        local timestamp=$(get_meta_value "$id" "$timestamp_field")
        local has_data=$(get_meta_value "$id" "$data_field")
        
        echo -n "• $api_name : "
        
        if [ -n "$has_data" ]; then
            echo -e "${GREEN}✅ Collecté${NC}"
            [ -n "$timestamp" ] && echo "  └─ Date : $timestamp"
        elif [ -n "$timestamp" ]; then
            echo -e "${YELLOW}⚠️  Tenté sans succès${NC}"
            echo "  └─ Date : $timestamp"
        else
            echo -e "${RED}❌ Jamais tenté${NC}"
        fi
    done
    
    # Statut global
    local collection_status=$(get_meta_value "$id" "_collection_status")
    local last_collect=$(get_meta_value "$id" "_last_collect_date")
    
    echo ""
    echo -n "📌 Statut global : "
    if [ "$collection_status" = "completed" ]; then
        echo -e "${GREEN}✅ COLLECTE COMPLÈTE${NC}"
    else
        echo -e "${YELLOW}⚠️  COLLECTE PARTIELLE${NC}"
    fi
    
    [ -n "$last_collect" ] && echo "📅 Dernière collecte : $last_collect"
    
    # Score d'export
    local export_score=$(get_meta_value "$id" "_export_score")
    local export_max=$(get_meta_value "$id" "_export_max_score")
    local missing_data=$(get_meta_value "$id" "_missing_data")
    
    if [ -n "$export_score" ] && [ -n "$export_max" ]; then
        echo ""
        echo -n "🎯 Score d'export : $export_score/$export_max "
        
        local percentage=$((export_score * 100 / export_max))
        if [ $percentage -eq 100 ]; then
            echo -e "${GREEN}(100% - Prêt pour export)${NC}"
        elif [ $percentage -ge 80 ]; then
            echo -e "${YELLOW}($percentage% - Export possible)${NC}"
        else
            echo -e "${RED}($percentage% - Données manquantes)${NC}"
        fi
        
        if [ -n "$missing_data" ] && [ "$missing_data" != "" ]; then
            echo "❌ Données manquantes : $missing_data"
        fi
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$id"
    fi
}

# Fonction pour afficher un résumé compact
show_compact_summary() {
    local id=$1
    local isbn=$2
    
    # Titre
    local title=$(get_meta_value "$id" "_best_title")
    [ -z "$title" ] && title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "SELECT post_title FROM wp_${SITE_ID}_posts WHERE ID=$id")
    
    # Données essentielles
    local price=$(get_meta_value "$id" "_price")
    local stock=$(get_meta_value "$id" "_stock")
    local condition=$(get_meta_value "$id" "_book_condition")
    local export_score=$(get_meta_value "$id" "_export_score")
    local export_max=$(get_meta_value "$id" "_export_max_score")
    
    echo ""
    echo "📚 ID: $id | ISBN: $isbn"
    echo "📖 Titre: $title"
    echo -n "💰 Prix: "
    [ -n "$price" ] && [ "$price" != "0" ] && echo "$price €" || echo -e "${RED}Non défini${NC}"
    echo "📦 Stock: ${stock:-1} | État: ${condition:-Non défini}"
    
    if [ -n "$export_score" ] && [ -n "$export_max" ]; then
        local percentage=$((export_score * 100 / export_max))
        echo -n "🎯 Export: $export_score/$export_max ($percentage%) "
        [ $percentage -eq 100 ] && echo -e "${GREEN}✅${NC}" || echo -e "${YELLOW}⚠️${NC}"
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$id"
    fi
}

# Fonction pour afficher les données marketplace
show_marketplace_status() {
    local id=$1
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${PURPLE}🛒 STATUT EXPORT MARKETPLACES${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    local marketplaces=(
        "Amazon:_amazon_export_status:_amazon_last_export:_amazon_asin"
        "Rakuten:_rakuten_export_status:_rakuten_last_export:_rakuten_product_id"
        "Fnac:_fnac_export_status:_fnac_last_export:_fnac_product_id"
        "Cdiscount:_cdiscount_export_status:_cdiscount_last_export:_cdiscount_product_id"
        "LeBonCoin:_leboncoin_export_status:_leboncoin_last_export:_leboncoin_ad_id"
        "Vinted:_vinted_export_status:_vinted_last_export:_vinted_item_id"
    )
    
    for mp_info in "${marketplaces[@]}"; do
        IFS=':' read -r mp_name status_field date_field id_field <<< "$mp_info"
        
        local status=$(get_meta_value "$id" "$status_field")
        local date=$(get_meta_value "$id" "$date_field")
        local mp_id=$(get_meta_value "$id" "$id_field")
        
        echo -n "• $mp_name : "
        
        if [ "$status" = "exported" ] && [ -n "$mp_id" ]; then
            echo -e "${GREEN}✅ Exporté${NC}"
            echo "  ├─ ID : $mp_id"
            [ -n "$date" ] && echo "  └─ Date : $date"
        elif [ "$status" = "pending" ]; then
            echo -e "${YELLOW}⏳ En attente${NC}"
        elif [ "$status" = "error" ]; then
            echo -e "${RED}❌ Erreur${NC}"
            [ -n "$date" ] && echo "  └─ Date : $date"
        else
            echo -e "${GRAY}➖ Non exporté${NC}"
        fi
    done
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "$id"
    fi
}

# Fonction pour afficher une barre de progression
show_progress_bar() {
    local current=$1
    local total=$2
    local width=50
    
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    
    echo -n "["
    for ((i=0; i<filled; i++)); do echo -n "█"; done
    for ((i=filled; i<width; i++)); do echo -n "░"; done
    echo -n "] $percentage% ($current/$total)"
}

# Fonction pour afficher les résultats de traitement batch
show_batch_summary() {
    local processed=$1
    local success=$2
    local failed=$3
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo -e "${BOLD}${CYAN}📊 RÉSUMÉ DU TRAITEMENT BATCH${NC}"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    echo "📚 Total traité : $processed livres"
    echo -e "✅ Succès : ${GREEN}$success${NC}"
    echo -e "❌ Échecs : ${RED}$failed${NC}"
    
    if [ $processed -gt 0 ]; then
        local success_rate=$((success * 100 / processed))
        echo ""
        echo -n "📈 Taux de réussite : "
        show_progress_bar $success $processed
        echo ""
        
        if [ $success_rate -eq 100 ]; then
            echo -e "${GREEN}🎉 Parfait ! Tous les livres ont été traités avec succès.${NC}"
        elif [ $success_rate -ge 80 ]; then
            echo -e "${YELLOW}👍 Bon résultat ! La majorité des livres ont été traités.${NC}"
        else
            echo -e "${RED}⚠️  Attention ! Plusieurs livres n'ont pas pu être traités.${NC}"
        fi
    fi
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        # DISABLED:         echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # DISABLED:         display_martingale_complete "batch"
    fi
}

# Fonction pour afficher les erreurs
show_error() {
    local error_msg=$1
    local error_code=${2:-1}
    
    echo ""
    echo -e "${RED}══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}${BOLD}❌ ERREUR${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${RED}$error_msg${NC}"
    echo ""
    echo "Code d'erreur : $error_code"
    echo ""
    
    # Suggestions selon le code d'erreur
    case $error_code in
        1)
            echo "💡 Suggestion : Vérifiez les paramètres fournis"
            ;;
        2)
            echo "💡 Suggestion : Vérifiez que l'ISBN est valide"
            ;;
        3)
            echo "💡 Suggestion : Vérifiez la connexion à la base de données"
            ;;
        4)
            echo "💡 Suggestion : Vérifiez que les fichiers API sont présents"
            ;;
        *)
            echo "💡 Suggestion : Consultez les logs pour plus de détails"
            ;;
    esac
}

# Fonction pour afficher un spinner pendant les opérations longues
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}
echo "[END: isbn_display.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
