#!/bin/bash
# lib/analyze_after.sh - Affichage de l'état APRÈS collecte avec requirements

# Fonction pour afficher l'état après collecte
show_after_state() {
    local id=$1
    local isbn=$2
    
    # Tableau des meilleures données sélectionnées
    echo ""
    echo "🏆 MEILLEURES DONNÉES SÉLECTIONNÉES PAR LA MARTINGALE"
    printf "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐\n"
    printf "│ %-44s │ %-102s │ %-8s │\n" "Variable finale" "Valeur sélectionnée" "Source"
    printf "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤\n"
    
    # Titre final
    local best_title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_title' LIMIT 1")
    local best_title_source=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_title_source' LIMIT 1")
    if [ -n "$best_title" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Titre final" "$best_title" "$best_title_source"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Titre final" "Non défini" "✗ MANQUE"
    fi
    
    # Auteur(s)
    local best_authors=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_authors' LIMIT 1")
    local best_authors_source=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_authors_source' LIMIT 1")
    if [ -n "$best_authors" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Auteur(s)" "$best_authors" "$best_authors_source"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Auteur(s)" "Non défini" "✗ MANQUE"
    fi
    
    # Éditeur
    local best_publisher=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_publisher' LIMIT 1")
    local best_publisher_source=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_publisher_source' LIMIT 1")
    if [ -n "$best_publisher" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Éditeur" "$best_publisher" "$best_publisher_source"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Éditeur" "Non défini" "✗ MANQUE"
    fi
    
    # Nombre de pages
    local best_pages=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_pages' LIMIT 1")
    local best_pages_source=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_pages_source' LIMIT 1")
    if [ -n "$best_pages" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Nombre de pages" "$best_pages" "$best_pages_source"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Nombre de pages" "Non défini" "✗ MANQUE"
    fi
    
    # Description
    local best_description=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_best_description' LIMIT 1")
    if [ -n "$best_description" ]; then
        if [ ${#best_description} -gt 97 ]; then
            best_description="${best_description:0:97}..."
        fi
        printf "│ %-44s │ %-102s │ %-8s │\n" "Description" "$best_description" "google"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Description" "Non définie" "✗ MANQUE"
    fi
    
    # Poids calculé
    local weight=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_calculated_weight' LIMIT 1")
    if [ -n "$weight" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Poids calculé" "$weight g" "CALCULÉ"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Poids calculé" "Non calculé" "✗ MANQUE"
    fi
    
    # Dimensions calculées
    local dimensions=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_calculated_dimensions' LIMIT 1")
    if [ -n "$dimensions" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Dimensions calculées" "$dimensions cm" "CALCULÉ"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Dimensions calculées" "Non calculées" "✗ MANQUE"
    fi
    
    # Prix de vente
    local price=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_price' LIMIT 1")
    if [ -n "$price" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Prix de vente" "$price €" "MANUEL"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Prix de vente" "À définir" "✗ MANQUE"
    fi
    
    # État du livre
    local condition=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_book_condition' LIMIT 1")
    if [ -n "$condition" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "État du livre" "$condition" "MANUEL"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "État du livre" "À définir" "✗ MANQUE"
    fi
    
    # Condition Vinted
    local vinted_condition=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_vinted_condition' LIMIT 1")
    if [ -n "$vinted_condition" ]; then
        case "$vinted_condition" in
            1) vinted_text="1 - Neuf avec étiquette" ;;
            2) vinted_text="2 - Neuf sans étiquette" ;;
            3) vinted_text="3 - Très bon état" ;;
            4) vinted_text="4 - Bon état" ;;
            5) vinted_text="5 - Satisfaisant" ;;
            *) vinted_text="$vinted_condition" ;;
        esac
        printf "│ %-44s │ %-102s │ %-8s │\n" "Condition Vinted" "$vinted_text" "AUTO"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Condition Vinted" "À définir" "✗ MANQUE"
    fi
    
    # Catégorie Vinted - CORRECTION : utiliser _cat_vinted
    local vinted_cat=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_cat_vinted' LIMIT 1")
    if [ -n "$vinted_cat" ]; then
        case "$vinted_cat" in
            1601) vinted_cat_text="1601 - Livres (défaut)" ;;
            57) vinted_cat_text="57 - Bandes dessinées" ;;
            *) vinted_cat_text="$vinted_cat" ;;
        esac
        printf "│ %-44s │ %-102s │ %-8s │\n" "Catégorie Vinted" "$vinted_cat_text" "✓ OK"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Catégorie Vinted" "Non défini" "✗ MANQUE"
    fi
    
    # Code postal
    local zip=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_location_zip' LIMIT 1")
    if [ -n "$zip" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Code postal" "$zip" "DÉFAUT"
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Code postal" "Non défini" "✗ MANQUE"
    fi
    
    printf "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘\n"
    
    # Images disponibles après collecte
    echo ""
    echo "🖼️  IMAGES DISPONIBLES APRÈS COLLECTE"
    printf "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐\n"
    printf "│ %-44s │ %-102s │ %-8s │\n" "Source / Type" "URL de l'image" "Priorité"
    printf "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤\n"
    
    # Compter et afficher les images
    local image_count=0
    
    # Google Thumbnail
    local g_thumb=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_g_thumbnail' LIMIT 1")
    if [ -n "$g_thumb" ]; then
        ((image_count++))
        printf "│ %-44s │ %-102s │ %-8s │\n" "Google Thumbnail" "$g_thumb" "#$image_count"
    fi
    
    # Open Library Large
    local o_large=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_o_cover_large' LIMIT 1")
    if [ -n "$o_large" ]; then
        ((image_count++))
        printf "│ %-44s │ %-102s │ %-8s │\n" "Open Library Large" "$o_large" "#$image_count"
    fi
    
    printf "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘\n"
    
    # Bullet points Amazon
    echo ""
    echo "📍 BULLET POINTS AMAZON GÉNÉRÉS"
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    
    # Afficher les bullet points
    for i in {1..5}; do
        local bullet=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_calculated_bullet$i' LIMIT 1")
        if [ -n "$bullet" ]; then
            echo "• $bullet"
        fi
    done
    
    # Statut d'exportabilité
    echo ""
    echo "📤 STATUT D'EXPORTABILITÉ PAR MARKETPLACE"
    printf "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐\n"
    printf "│ %-44s │ %-102s │ %-8s │\n" "Marketplace" "Statut et données manquantes" "Export"
    printf "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤\n"
    
    # Vérifier l'exportabilité pour chaque marketplace
    local ready_count=0
    local total_marketplaces=6
    
    # Amazon
    if [ -n "$best_title" ] && [ -n "$price" ] && [ -n "$best_description" ] && [ $image_count -gt 0 ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Amazon" "Toutes les données obligatoires sont présentes" "✅ PRÊT"
        ((ready_count++))
    else
        local missing=""
        [ -z "$best_title" ] && missing="${missing}titre, "
        [ -z "$price" ] && missing="${missing}prix, "
        [ -z "$best_description" ] && missing="${missing}description, "
        [ $image_count -eq 0 ] && missing="${missing}image, "
        missing=${missing%, }
        printf "│ %-44s │ %-102s │ %-8s │\n" "Amazon" "Données manquantes : $missing" "❌ BLOQUÉ"
    fi
    
    # Rakuten
    if [ -n "$best_title" ] && [ -n "$price" ] && [ -n "$best_description" ] && [ ${#best_description} -ge 20 ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Rakuten/PriceMinister" "Toutes les données obligatoires sont présentes" "✅ PRÊT"
        ((ready_count++))
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Rakuten/PriceMinister" "Description trop courte ou données manquantes" "❌ BLOQUÉ"
    fi
    
    # Vinted
    if [ -n "$best_title" ] && [ -n "$price" ] && [ $image_count -gt 0 ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Vinted" "Toutes les données obligatoires sont présentes" "✅ PRÊT"
        ((ready_count++))
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Vinted" "Titre, prix ou image manquant" "❌ BLOQUÉ"
    fi
    
    # Fnac
    if [ -n "$best_title" ] && [ -n "$best_authors" ] && [ -n "$best_publisher" ] && [ -n "$price" ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Fnac" "Toutes les données obligatoires sont présentes" "✅ PRÊT"
        ((ready_count++))
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Fnac" "Auteur, éditeur ou prix manquant" "❌ BLOQUÉ"
    fi
    
    # Cdiscount
    if [ -n "$best_title" ] && [ -n "$price" ] && [ -n "$best_description" ] && [ $image_count -gt 0 ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Cdiscount" "Toutes les données obligatoires sont présentes" "✅ PRÊT"
        ((ready_count++))
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Cdiscount" "Données de base manquantes" "❌ BLOQUÉ"
    fi
    
    # Leboncoin
    if [ -n "$best_title" ] && [ -n "$price" ] && [ $image_count -gt 0 ]; then
        printf "│ %-44s │ %-102s │ %-8s │\n" "Leboncoin" "Toutes les données obligatoires sont présentes" "✅ PRÊT"
        ((ready_count++))
    else
        printf "│ %-44s │ %-102s │ %-8s │\n" "Leboncoin" "Titre, prix ou image manquant" "❌ BLOQUÉ"
    fi
    
    printf "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘\n"
    
    # Message récapitulatif
    echo ""
    if [ $ready_count -eq $total_marketplaces ]; then
        echo "🎉 EXCELLENT ! Le livre est prêt pour l'export vers TOUTES les marketplaces ($ready_count/$total_marketplaces)"
    elif [ $ready_count -gt 0 ]; then
        echo "⚠️  Le livre est prêt pour $ready_count marketplace(s) sur $total_marketplaces"
    else
        echo "❌ Le livre n'est prêt pour AUCUNE marketplace - données essentielles manquantes"
    fi
    
    # Métadonnées de collecte
    echo ""
    echo "📊 MÉTADONNÉES DE COLLECTE"
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    
    local last_collected=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_last_collected' LIMIT 1")
    local collection_status=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_collection_status' LIMIT 1")
    local api_calls=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta WHERE post_id=$id AND meta_key='_api_calls_count' LIMIT 1")
    
    echo "Date de collecte    : ${last_collected:-Non collecté}"
    echo "Statut              : ${collection_status:-Non défini}"
    echo "Appels API totaux   : ${api_calls:-0}"
    echo "Version collecteur  : Non renseignée"
    
    # Appeler l'affichage des requirements détaillés
    echo ""
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📋 REQUIREMENTS DÉTAILLÉS PAR MARKETPLACE"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo ""
    
    # Source les fonctions get_best_value si nécessaire
    if [ -f "$SCRIPT_DIR/lib/analyze_functions.sh" ]; then
        source "$SCRIPT_DIR/lib/analyze_functions.sh"
    elif [ -f "$SCRIPT_DIR/lib/best_data.sh" ]; then
        source "$SCRIPT_DIR/lib/best_data.sh"
    fi
    
    # Afficher les requirements de chaque marketplace
    show_amazon_requirements "$id" "$isbn"
    echo ""
    echo ""
    show_rakuten_requirements "$id" "$isbn"
    echo ""
    echo ""
    show_vinted_requirements "$id" "$isbn"
    echo ""
    echo ""
    show_fnac_requirements "$id" "$isbn"
    echo ""
    echo ""
    show_cdiscount_requirements "$id" "$isbn"
    echo ""
    echo ""
    show_leboncoin_requirements "$id" "$isbn"
}
