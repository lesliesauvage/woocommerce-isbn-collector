#!/bin/bash
echo "[START: wordpress_to_rakuten_smart_mapping.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# Mapping intelligent basé sur la hiérarchie

get_rakuten_category_smart() {
    local wp_full_path="$1"
    local wp_cat_lower=$(echo "$wp_full_path" | tr '[:upper:]' '[:lower:]')
    
    # 1. D'ABORD VÉRIFIER LA CATÉGORIE PRINCIPALE (niveau 1)
    case "$wp_full_path" in
        "LITTÉRATURE"*|"Littérature"*)
            # Sous-catégories de LITTÉRATURE
            case "$wp_full_path" in
                *"Romans français"*) echo "Littérature française" ;;
                *"Romans anglais"*|*"Romans allemands"*|*"Romans italiens"*|*"Romans espagnols"*|*"Romans russes"*|*"Romans portugais"*) echo "Littérature étrangère" ;;
                *"Romans africains"*|*"Romans asiatiques"*) echo "Littérature étrangère" ;;
                *"Romans historiques"*) echo "Roman historique" ;;
                *"Romans du terroir"*) echo "Régionalisme" ;;
                *"Biographies"*) echo "Critique littéraire" ;;
                *"Poésie"*) echo "Poésie" ;;
                *"Théâtre"*) echo "Théâtre" ;;
                *"Thriller"*|*"Policier"*|*"Roman noir"*) echo "Policiers" ;;
                *"Romance"*|*"Roman érotique"*) echo "Littérature française" ;;
                *"Récit de voyage"*) echo "Récits de voyages" ;;
                *"Humour"*) echo "Humour" ;;
                *) echo "Littérature française" ;; # Par défaut pour LITTÉRATURE
            esac
            ;;
            
        "SAVOIRS"*)
            case "$wp_full_path" in
                *"Informatique"*) echo "Informatique" ;;
                *"Mathématiques"*) echo "Mathématiques" ;;
                *"Physique"*) echo "Physique - Chimie" ;;
                *"Chimie"*) echo "Physique - Chimie" ;;
                *"Biologie"*) echo "Sciences de la vie et de la terre" ;;
                *"Médecine"*) echo "Généralités médicales" ;;
                *"Droit"*) echo "Droit" ;;
                *"Business"*|*"Économie"*) echo "Économie" ;;
                *"Gestion"*) echo "Gestion" ;;
                *"Langues"*) echo "Français langue étrangère" ;;
                *"Sciences de la terre"*) echo "Sciences de la vie et de la terre" ;;
                *) echo "Sciences historiques" ;;
            esac
            ;;
            
        "ENFANTS"*|"ADOS"*)
            case "$wp_full_path" in
                *"Albums"*) echo "Album jeunesse" ;;
                *"BD"*) echo "BD jeunesse" ;;
                *"Documentaires"*) echo "Documentaires jeunesse" ;;
                *"Contes"*) echo "Album jeunesse" ;;
                *"Romans"*|*"Fiction"*) echo "Littérature jeunesse" ;;
                *"Manga"*) echo "Comics et manga > Mangas divers" ;;
                *) echo "Littérature jeunesse" ;;
            esac
            ;;
            
        "ART & CULTURE"*)
            case "$wp_full_path" in
                *"Peinture"*) echo "Beaux arts" ;;
                *"Photographie"*) echo "Photographie" ;;
                *"Cinéma"*) echo "Cinéma" ;;
                *"Musique"*) echo "Musique - danse" ;;
                *"Architecture"*) echo "Beaux arts" ;;
                *"Histoire de l'art"*|*"Histoire et critique"*) echo "Beaux arts" ;;
                *"Philosophie"*) echo "Philosophie" ;;
                *"Psychologie"*) echo "Psychologie - Psychanalyse" ;;
                *"Sociologie"*) echo "Sociologie" ;;
                *"Histoire"*"France"*) echo "Histoire de France" ;;
                *"Histoire"*) echo "Histoire internationale" ;;
                *"Religions"*) echo "Religion" ;;
                *"Ésotérisme"*) echo "Ésotérisme" ;;
                *) echo "Critique littéraire" ;;
            esac
            ;;
            
        "BANDE DESSINÉE"*|"BD"*)
            case "$wp_full_path" in
                *"Comics"*) echo "Comics et manga > Comics divers" ;;
                *"Manga"*"Shōnen"*) echo "Comics et manga > Mangas ado/adultes" ;;
                *"Manga"*"Shōjo"*) echo "Comics et manga > Mangas Shojo/filles" ;;
                *"Manga"*"érotique"*|*"Hentai"*) echo "Comics et manga > Mangas érotiques" ;;
                *"Manga"*) echo "Comics et manga > Mangas divers" ;;
                *"franco-belge"*) echo "Comics et manga > Bandes Dessinées Poche" ;;
                *) echo "Comics et manga > Bandes Dessinées Poche" ;;
            esac
            ;;
            
        "BIEN-ÊTRE & VIE PRATIQUE"*)
            case "$wp_full_path" in
                *"Cuisine"*) echo "Art culinaire - Oenologie" ;;
                *"Santé"*) echo "Santé" ;;
                *"Développement personnel"*) echo "Développement personnel" ;;
                *"Parentalité"*) echo "Couple - Famille" ;;
                *"Sexualité"*|*"Érotisme"*) echo "Développement personnel" ;;
                *) echo "Développement personnel" ;;
            esac
            ;;
            
        "LOISIRS & VOYAGES"*)
            case "$wp_full_path" in
                *"Sports"*) echo "Sports" ;;
                *"Guide France"*) echo "Guides touristiques France" ;;
                *"Guide"*) echo "Guides touristiques Monde" ;;
                *"Récits de voyages"*) echo "Récits de voyages" ;;
                *"Jardinage"*) echo "Jardinage" ;;
                *"Bricolage"*) echo "Décoration" ;;
                *"Nature"*) echo "Faits de société" ;;
                *) echo "Loisirs et Jeux" ;;
            esac
            ;;
            
        "MANGA"*)
            case "$wp_full_path" in
                *"Shōnen"*) echo "Comics et manga > Mangas ado/adultes" ;;
                *"Shōjo"*) echo "Comics et manga > Mangas Shojo/filles" ;;
                *"Seinen"*) echo "Comics et manga > Mangas ado/adultes" ;;
                *"Josei"*) echo "Comics et manga > Mangas Shojo/filles" ;;
                *"Hentai"*) echo "Comics et manga > Mangas érotiques" ;;
                *) echo "Comics et manga > Mangas divers" ;;
            esac
            ;;
            
        "SCOLAIRE"*)
            case "$wp_full_path" in
                *"Maternelle"*) echo "Enseignement primaire" ;;
                *"Primaire"*) echo "Primaire parascolaire" ;;
                *"Collège"*) echo "Enseignement secondaire 1er cycle" ;;
                *"Lycée"*) echo "Lycée parascolaire" ;;
                *"Dictionnaires"*) echo "Dictionnaire de français" ;;
                *) echo "Enseignement secondaire 1er cycle" ;;
            esac
            ;;
            
        "JEUNES ADULTES"*)
            echo "Littérature jeunesse"
            ;;
            
        # CATÉGORIES SPÉCIALES (non hiérarchiques)
        "Récit de voyage"|"Récits de voyages") echo "Récits de voyages" ;;
        "Humour") echo "Humour" ;;
        "Poésie") echo "Poésie" ;;
        "Théâtre") echo "Théâtre" ;;
        "Philosophie") echo "Philosophie" ;;
        "Psychologie") echo "Psychologie - Psychanalyse" ;;
        
        # PAR DÉFAUT
        *) 
            # Analyser par mots-clés
            if [[ "$wp_cat_lower" =~ "dictionnaire" ]]; then
                echo "Dictionnaire de français"
            elif [[ "$wp_cat_lower" =~ "encyclopédie" ]]; then
                echo "Encyclopédie de poche"
            elif [[ "$wp_cat_lower" =~ "cuisine" ]] || [[ "$wp_cat_lower" =~ "pâtisserie" ]]; then
                echo "Art culinaire - Oenologie"
            elif [[ "$wp_cat_lower" =~ "voyage" ]]; then
                echo "Récits de voyages"
            elif [[ "$wp_cat_lower" =~ "photo" ]]; then
                echo "Photographie"
            elif [[ "$wp_cat_lower" =~ "cinéma" ]]; then
                echo "Cinéma"
            elif [[ "$wp_cat_lower" =~ "musique" ]]; then
                echo "Musique - danse"
            else
                echo "Littérature française" # Défaut ultime
            fi
            ;;
    esac
}

# Fonction wrapper qui récupère la catégorie WordPress et la mappe
get_rakuten_category_from_post_smart() {
    local post_id="$1"
    
    # Récupérer la catégorie WordPress complète avec hiérarchie
    local wp_category=$(get_wordpress_category_path "$post_id")
    
    # Si pas de catégorie, essayer de récupérer au moins une catégorie simple
    if [ -z "$wp_category" ] || [ "$wp_category" = "NULL" ]; then
        wp_category=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT t.name
            FROM wp_${SITE_ID}_term_relationships tr
            JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
            WHERE tr.object_id = $post_id
            AND tt.taxonomy = 'product_cat'
            LIMIT 1")
    fi
    
    # Mapper vers Rakuten
    local rakuten_category=$(get_rakuten_category_smart "$wp_category")
    
    echo "$rakuten_category"
}

# Export des fonctions
export -f get_rakuten_category_smart
export -f get_rakuten_category_from_post_smart

echo "[END: wordpress_to_rakuten_smart_mapping.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
