#!/bin/bash
# lib/analyze_after.sh - Fonction show_after_state pour la section 3

# Fonction pour afficher l'état APRÈS collecte (Section 3)
show_after_state() {
    local product_id=$1
    local isbn=$2
    
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📊 SECTION 3 : RÉSULTAT APRÈS COLLECTE ET EXPORTABILITÉ"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    # Tableau des meilleures données sélectionnées
    echo ""
    echo "🏆 MEILLEURES DONNÉES SÉLECTIONNÉES PAR LA MARTINGALE"
    echo "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Variable finale                              │ Valeur sélectionnée                                                                                    │ Source   │"
    echo "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤"
    
    # Variables essentielles avec leurs sources
    local final_vars=(
        "_best_title|Titre final"
        "_best_authors|Auteur(s)"
        "_best_publisher|Éditeur"
        "_best_pages|Nombre de pages"
        "_best_description|Description"
        "_calculated_weight|Poids calculé"
        "_calculated_dimensions|Dimensions calculées"
        "_price|Prix de vente"
        "_book_condition|État du livre"
        "_vinted_condition|Condition Vinted"
        "_vinted_category_id|Catégorie Vinted"
        "_location_zip|Code postal"
    )
    
    for var_info in "${final_vars[@]}"; do
        IFS='|' read -r var_key var_name <<< "$var_info"
        local value=$(safe_get_meta "$product_id" "$var_key")
        local source=""
        
        # Récupérer la source si c'est une variable _best_
        if [[ "$var_key" =~ ^_best_ ]]; then
            local source_key="${var_key}_source"
            source=$(safe_get_meta "$product_id" "$source_key")
        elif [[ "$var_key" =~ ^_calculated_ ]]; then
            source="CALCULÉ"
        elif [ "$var_key" = "_price" ] || [ "$var_key" = "_book_condition" ]; then
            source="MANUEL"
        elif [ "$var_key" = "_vinted_condition" ] || [ "$var_key" = "_vinted_category_id" ]; then
            source="AUTO"
        elif [ "$var_key" = "_location_zip" ]; then
            source="DÉFAUT"
        fi
        
        if [ -n "$value" ] && [ "$value" != "null" ] && [ "$value" != "0" ]; then
            # Gérer l'affichage spécial pour certains champs
            if [ "$var_key" = "_vinted_condition" ]; then
                case "$value" in
                    "5") value="5 - Neuf avec étiquettes" ;;
                    "4") value="4 - Neuf sans étiquettes" ;;
                    "3") value="3 - Très bon état" ;;
                    "2") value="2 - Bon état" ;;
                    "1") value="1 - Satisfaisant" ;;
                esac
            elif [ "$var_key" = "_vinted_category_id" ]; then
                case "$value" in
                    "1196") value="1196 - Romans et littérature" ;;
                    "1197") value="1197 - BD et mangas" ;;
                    "1198") value="1198 - Livres pour enfants" ;;
                    "1199") value="1199 - Études et références" ;;
                    "1200") value="1200 - Non-fiction et documentaires" ;;
                    "1201") value="1201 - Autres livres" ;;
                    "1601") value="1601 - Livres (général)" ;;
                esac
            elif [ "$var_key" = "_price" ]; then
                value="$value €"
            elif [ "$var_key" = "_calculated_weight" ]; then
                value="$value g"
            elif [ "$var_key" = "_calculated_dimensions" ]; then
                value="$value cm"
            fi
            
            # Affichage
            if [ ${#value} -gt 102 ]; then
                printf "│ %-44s │ %-102s │ \033[32m%-8s\033[0m │\n" "$var_name" "${value:0:99}..." "$source"
            else
                printf "│ %-44s │ %-102s │ \033[32m%-8s\033[0m │\n" "$var_name" "$value" "$source"
            fi
        else
            # BUG FIX : Afficher correctement la ligne du prix même si vide
            if [ "$var_key" = "_price" ]; then
                printf "│ %-44s │ %-102s │ \033[31m✗ MANQUE\033[0m │\n" "$var_name" "Non défini - OBLIGATOIRE POUR EXPORT"
            else
                printf "│ %-44s │ %-102s │ \033[31m✗ MANQUE\033[0m │\n" "$var_name" "Non défini"
            fi
        fi
    done
    
    echo "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘"
    
    # Images après collecte
    echo ""
    echo "🖼️  IMAGES DISPONIBLES APRÈS COLLECTE"
    echo "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Source / Type                                │ URL de l'image                                                                                         │ Priorité │"
    echo "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤"
    
    # Ordre de priorité pour les images
    local best_image=""
    local image_priority=1
    
    # ISBNdb d'abord (souvent meilleure qualité)
    local i_image=$(safe_get_meta "$product_id" "_i_image")
    if [ -n "$i_image" ] && [ "$i_image" != "null" ]; then
        printf "│ %-44s │ %-102s │ \033[32m#%d ⭐\033[0m    │\n" "ISBNdb" "$i_image" "$image_priority"
        [ -z "$best_image" ] && best_image="$i_image"
        ((image_priority++))
    fi
    
    # Google Extra Large
    local g_xl=$(safe_get_meta "$product_id" "_g_extraLarge")
    if [ -n "$g_xl" ] && [ "$g_xl" != "null" ]; then
        printf "│ %-44s │ %-102s │ \033[32m#%d\033[0m       │\n" "Google Extra Large" "$g_xl" "$image_priority"
        [ -z "$best_image" ] && best_image="$g_xl"
        ((image_priority++))
    fi
    
    # Google Large
    local g_l=$(safe_get_meta "$product_id" "_g_large")
    if [ -n "$g_l" ] && [ "$g_l" != "null" ]; then
        printf "│ %-44s │ %-102s │ \033[32m#%d\033[0m       │\n" "Google Large" "$g_l" "$image_priority"
        [ -z "$best_image" ] && best_image="$g_l"
        ((image_priority++))
    fi
    
    # Google Medium
    local g_m=$(safe_get_meta "$product_id" "_g_medium")
    if [ -n "$g_m" ] && [ "$g_m" != "null" ]; then
        printf "│ %-44s │ %-102s │ \033[32m#%d\033[0m       │\n" "Google Medium" "$g_m" "$image_priority"
        [ -z "$best_image" ] && best_image="$g_m"
        ((image_priority++))
    fi
    
    # Google Thumbnail
    local g_t=$(safe_get_meta "$product_id" "_g_thumbnail")
    if [ -n "$g_t" ] && [ "$g_t" != "null" ]; then
        printf "│ %-44s │ %-102s │ \033[33m#%d\033[0m       │\n" "Google Thumbnail" "$g_t" "$image_priority"
        [ -z "$best_image" ] && best_image="$g_t"
        ((image_priority++))
    fi
    
    # Open Library
    local o_l=$(safe_get_meta "$product_id" "_o_cover_large")
    if [ -n "$o_l" ] && [ "$o_l" != "null" ]; then
        printf "│ %-44s │ %-102s │ \033[33m#%d\033[0m       │\n" "Open Library Large" "$o_l" "$image_priority"
        [ -z "$best_image" ] && best_image="$o_l"
        ((image_priority++))
    fi
    
    if [ -z "$best_image" ]; then
        printf "│ %-44s │ %-102s │ \033[31m✗\033[0m        │\n" "AUCUNE IMAGE TROUVÉE" "❌ Bloquant pour export" ""
    fi
    
    echo "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘"
    
    # Bullet points Amazon
    echo ""
    echo "📍 BULLET POINTS AMAZON GÉNÉRÉS"
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    for i in 1 2 3 4 5; do
        local bullet=$(safe_get_meta "$product_id" "_calculated_bullet$i")
        [ -n "$bullet" ] && echo "• $bullet"
    done
    
    # Statut d'exportabilité par marketplace
    echo ""
    echo "📤 STATUT D'EXPORTABILITÉ PAR MARKETPLACE"
    echo "┌──────────────────────────────────────────────┬────────────────────────────────────────────────────────────────────────────────────────────────────────┬──────────┐"
    echo "│ Marketplace                                  │ Statut et données manquantes                                                                          │ Export   │"
    echo "├──────────────────────────────────────────────┼────────────────────────────────────────────────────────────────────────────────────────────────────────┼──────────┤"
    
    # Vérifier l'exportabilité pour chaque marketplace
    local price=$(safe_get_meta "$product_id" "_price")
    local title=$(safe_get_meta "$product_id" "_best_title")
    [ -z "$title" ] && title=$(safe_get_meta "$product_id" "_g_title")
    local authors=$(safe_get_meta "$product_id" "_best_authors")
    local publisher=$(safe_get_meta "$product_id" "_best_publisher")
    local description=$(safe_get_meta "$product_id" "_best_description")
    local has_price=0
    [ -n "$price" ] && [ "$price" != "0" ] && has_price=1
    
    # Amazon
    local amazon_ok=1
    local amazon_missing=""
    [ -z "$title" ] && { amazon_ok=0; amazon_missing="titre, "; }
    [ -z "$publisher" ] && { amazon_ok=0; amazon_missing="${amazon_missing}éditeur/brand, "; }
    [ -z "$description" ] && { amazon_ok=0; amazon_missing="${amazon_missing}description, "; }
    [ $has_price -eq 0 ] && { amazon_ok=0; amazon_missing="${amazon_missing}prix, "; }
    [ -z "$best_image" ] && { amazon_ok=0; amazon_missing="${amazon_missing}image, "; }
    
    if [ $amazon_ok -eq 1 ]; then
        printf "│ %-44s │ %-102s │ \033[32m✅ PRÊT\033[0m  │\n" "Amazon" "Toutes les données obligatoires sont présentes"
    else
        amazon_missing=${amazon_missing%, }
        printf "│ %-44s │ %-102s │ \033[31m❌ NON\033[0m   │\n" "Amazon" "Manque : $amazon_missing"
    fi
    
    # Rakuten
    local rakuten_ok=1
    local rakuten_missing=""
    [ -z "$title" ] && { rakuten_ok=0; rakuten_missing="titre, "; }
    [ -z "$description" ] || [ ${#description} -lt 20 ] && { rakuten_ok=0; rakuten_missing="${rakuten_missing}description (min 20 car), "; }
    [ $has_price -eq 0 ] && { rakuten_ok=0; rakuten_missing="${rakuten_missing}prix, "; }
    [ -z "$best_image" ] && { rakuten_ok=0; rakuten_missing="${rakuten_missing}image, "; }
    
    if [ $rakuten_ok -eq 1 ]; then
        printf "│ %-44s │ %-102s │ \033[32m✅ PRÊT\033[0m  │\n" "Rakuten/PriceMinister" "Toutes les données obligatoires sont présentes"
    else
        rakuten_missing=${rakuten_missing%, }
        printf "│ %-44s │ %-102s │ \033[31m❌ NON\033[0m   │\n" "Rakuten/PriceMinister" "Manque : $rakuten_missing"
    fi
    
    # Vinted
    local vinted_ok=1
    local vinted_missing=""
    [ -z "$title" ] && { vinted_ok=0; vinted_missing="titre, "; }
    [ -z "$description" ] && { vinted_ok=0; vinted_missing="${vinted_missing}description, "; }
    [ $has_price -eq 0 ] && { vinted_ok=0; vinted_missing="${vinted_missing}prix, "; }
    [ -z "$best_image" ] && { vinted_ok=0; vinted_missing="${vinted_missing}photo, "; }
    [ -z "$(safe_get_meta "$product_id" "_book_condition")" ] && { vinted_ok=0; vinted_missing="${vinted_missing}état, "; }
    
    if [ $vinted_ok -eq 1 ]; then
        printf "│ %-44s │ %-102s │ \033[32m✅ PRÊT\033[0m  │\n" "Vinted" "Toutes les données obligatoires sont présentes"
    else
        vinted_missing=${vinted_missing%, }
        printf "│ %-44s │ %-102s │ \033[31m❌ NON\033[0m   │\n" "Vinted" "Manque : $vinted_missing"
    fi
    
    # Fnac
    local fnac_ok=1
    local fnac_missing=""
    [ -z "$title" ] && { fnac_ok=0; fnac_missing="titre, "; }
    [ -z "$authors" ] && { fnac_ok=0; fnac_missing="${fnac_missing}auteur, "; }
    [ -z "$publisher" ] && { fnac_ok=0; fnac_missing="${fnac_missing}éditeur, "; }
    [ $has_price -eq 0 ] && { fnac_ok=0; fnac_missing="${fnac_missing}prix, "; }
    
    if [ $fnac_ok -eq 1 ]; then
        printf "│ %-44s │ %-102s │ \033[32m✅ PRÊT\033[0m  │\n" "Fnac" "Toutes les données obligatoires sont présentes"
    else
        fnac_missing=${fnac_missing%, }
        printf "│ %-44s │ %-102s │ \033[31m❌ NON\033[0m   │\n" "Fnac" "Manque : $fnac_missing"
    fi
    
    # Cdiscount
    local cdiscount_ok=1
    local cdiscount_missing=""
    [ -z "$title" ] && { cdiscount_ok=0; cdiscount_missing="titre, "; }
    [ -z "$publisher" ] && { cdiscount_ok=0; cdiscount_missing="${cdiscount_missing}brand, "; }
    [ -z "$description" ] && { cdiscount_ok=0; cdiscount_missing="${cdiscount_missing}description, "; }
    [ $has_price -eq 0 ] && { cdiscount_ok=0; cdiscount_missing="${cdiscount_missing}prix, "; }
    [ -z "$best_image" ] && { cdiscount_ok=0; cdiscount_missing="${cdiscount_missing}image, "; }
    
    if [ $cdiscount_ok -eq 1 ]; then
        printf "│ %-44s │ %-102s │ \033[32m✅ PRÊT\033[0m  │\n" "Cdiscount" "Toutes les données obligatoires sont présentes"
    else
        cdiscount_missing=${cdiscount_missing%, }
        printf "│ %-44s │ %-102s │ \033[31m❌ NON\033[0m   │\n" "Cdiscount" "Manque : $cdiscount_missing"
    fi
    
    # Leboncoin
    local lbc_ok=1
    local lbc_missing=""
    [ -z "$title" ] && { lbc_ok=0; lbc_missing="titre, "; }
    [ -z "$description" ] && { lbc_ok=0; lbc_missing="${lbc_missing}description, "; }
    [ $has_price -eq 0 ] && { lbc_ok=0; lbc_missing="${lbc_missing}prix, "; }
    [ -z "$best_image" ] && { lbc_ok=0; lbc_missing="${lbc_missing}photo, "; }
    local zip=$(safe_get_meta "$product_id" "_location_zip")
    [ -z "$zip" ] && { lbc_ok=0; lbc_missing="${lbc_missing}code postal, "; }
    
    if [ $lbc_ok -eq 1 ]; then
        printf "│ %-44s │ %-102s │ \033[32m✅ PRÊT\033[0m  │\n" "Leboncoin" "Toutes les données obligatoires sont présentes"
    else
        lbc_missing=${lbc_missing%, }
        printf "│ %-44s │ %-102s │ \033[31m❌ NON\033[0m   │\n" "Leboncoin" "Manque : $lbc_missing"
    fi
    
    echo "└──────────────────────────────────────────────┴────────────────────────────────────────────────────────────────────────────────────────────────────────┴──────────┘"
    
    # Comptage final
    local ready_count=0
    [ $amazon_ok -eq 1 ] && ((ready_count++))
    [ $rakuten_ok -eq 1 ] && ((ready_count++))
    [ $vinted_ok -eq 1 ] && ((ready_count++))
    [ $fnac_ok -eq 1 ] && ((ready_count++))
    [ $cdiscount_ok -eq 1 ] && ((ready_count++))
    [ $lbc_ok -eq 1 ] && ((ready_count++))
    
    echo ""
    if [ $ready_count -eq 6 ]; then
        echo "🎉 EXCELLENT ! Le livre est prêt pour l'export vers TOUTES les marketplaces (6/6)"
    elif [ $ready_count -ge 3 ]; then
        echo "✅ BON ! Le livre est exportable vers $ready_count/6 marketplaces"
    else
        echo "⚠️  INSUFFISANT ! Le livre n'est exportable que vers $ready_count/6 marketplaces"
    fi
    
    # Métadonnées de collecte
    echo ""
    echo "📊 MÉTADONNÉES DE COLLECTE"
    echo "──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
    local collect_date=$(safe_get_meta "$product_id" "_api_collect_date")
    local collect_status=$(safe_get_meta "$product_id" "_api_collect_status")
    local api_calls=$(safe_get_meta "$product_id" "_api_calls_made")
    local collect_version=$(safe_get_meta "$product_id" "_api_collect_version")
    
    echo "Date de collecte    : ${collect_date:-Non renseignée}"
    echo "Statut              : ${collect_status:-Non renseigné}"
    echo "Appels API totaux   : ${api_calls:-0}"
    echo "Version collecteur  : ${collect_version:-Non renseignée}"
    
    # AFFICHER LES TABLEAUX DES MARKETPLACES
    echo ""
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    echo "📋 REQUIREMENTS DÉTAILLÉS PAR MARKETPLACE"
    echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
    
    # Appeler toutes les fonctions marketplace
    show_amazon_requirements "$product_id" "$isbn"
    show_rakuten_requirements "$product_id" "$isbn"
    show_vinted_requirements "$product_id" "$isbn"
    show_fnac_requirements "$product_id" "$isbn"
    show_cdiscount_requirements "$product_id" "$isbn"
    show_leboncoin_requirements "$product_id" "$isbn"
}
