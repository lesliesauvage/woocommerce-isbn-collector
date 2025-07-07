#!/bin/bash
# lib/category_filter.sh - Filtrage intelligent des catégories pour réduire les tokens

# Fonction pour filtrer les catégories pertinentes basées sur le titre et la description
filter_relevant_categories() {
    local title="$1"
    local authors="$2"
    local description="$3"
    local all_categories="$4"
    
    debug_echo "[DEBUG] Filtrage des catégories pour : $title"
    
    # Convertir en minuscules pour la comparaison
    local title_lower=$(echo "$title" | tr '[:upper:]' '[:lower:]')
    local desc_lower=$(echo "$description" | tr '[:upper:]' '[:lower:]')
    local combined_text="$title_lower $desc_lower $authors"
    
    # Mots-clés pour identifier les catégories pertinentes
    local keywords=""
    local excluded_categories=""
    
    # Détection basée sur des mots-clés
    if echo "$combined_text" | grep -qE "roman|nouvelle|récit|histoire|conte"; then
        keywords="$keywords|Romans|Nouvelle|Fiction"
    fi
    
    if echo "$combined_text" | grep -qE "enfant|jeune|ado|collège|lycée"; then
        keywords="$keywords|ADOS|ENFANTS|JEUNES"
    else
        excluded_categories="$excluded_categories|ENFANTS|ADOS|JEUNES"
    fi
    
    if echo "$combined_text" | grep -qE "cuisine|recette|gastronomie|chef"; then
        keywords="$keywords|Cuisine|Gastronomie"
    fi
    
    if echo "$combined_text" | grep -qE "jardin|plante|fleur|arbre|potager"; then
        keywords="$keywords|Jardin|Nature"
    fi
    
    if echo "$combined_text" | grep -qE "histoire|historique|guerre|bataille|époque"; then
        keywords="$keywords|Histoire|Historique"
    fi
    
    if echo "$combined_text" | grep -qE "science|biologie|physique|chimie|mathématique"; then
        keywords="$keywords|Sciences|SAVOIRS"
    fi
    
    if echo "$combined_text" | grep -qE "philosophie|pensée|essai|réflexion"; then
        keywords="$keywords|Philosophie|Essais"
    fi
    
    if echo "$combined_text" | grep -qE "art|peinture|sculpture|musique|cinéma"; then
        keywords="$keywords|Arts|ART & CULTURE"
    fi
    
    if echo "$combined_text" | grep -qE "informatique|ordinateur|programmation|internet"; then
        keywords="$keywords|Informatique"
    fi
    
    if echo "$combined_text" | grep -qE "voyage|guide|tourisme|pays|ville"; then
        keywords="$keywords|Voyage|LOISIRS & VOYAGES"
    fi
    
    if echo "$combined_text" | grep -qE "manga|bd|bande dessinée|comic"; then
        keywords="$keywords|MANGA|BANDE DESSINÉE|BD"
    fi
    
    # Si aucun mot-clé spécifique, garder les catégories principales
    if [ -z "$keywords" ]; then
        keywords="LITTÉRATURE|ART & CULTURE|SAVOIRS|BIEN-ÊTRE|LOISIRS"
    fi
    
    # Supprimer le premier | si présent
    keywords=$(echo "$keywords" | sed 's/^|//')
    excluded_categories=$(echo "$excluded_categories" | sed 's/^|//')
    
    debug_echo "[DEBUG] Keywords: $keywords"
    debug_echo "[DEBUG] Excluded: $excluded_categories"
    
    # Filtrer les catégories
    local filtered_categories=""
    if [ -n "$excluded_categories" ]; then
        filtered_categories=$(echo "$all_categories" | grep -iE "$keywords" | grep -viE "$excluded_categories")
    else
        filtered_categories=$(echo "$all_categories" | grep -iE "$keywords")
    fi
    
    # Si trop peu de résultats, prendre les catégories de niveau 1 et 2
    local filtered_count=$(echo "$filtered_categories" | grep -c "ID:")
    if [ $filtered_count -lt 50 ]; then
        debug_echo "[DEBUG] Peu de catégories ($filtered_count), ajout des principales..."
        local main_categories=$(echo "$all_categories" | grep -E "^[A-Z& ]+ > [^>]+ \(ID:" | head -100)
        filtered_categories="$filtered_categories"$'\n'"$main_categories"
        filtered_categories=$(echo "$filtered_categories" | sort -u)
    fi
    
    # Limiter à 200 catégories maximum
    filtered_categories=$(echo "$filtered_categories" | head -200)
    
    local final_count=$(echo "$filtered_categories" | grep -c "ID:")
    debug_echo "[DEBUG] Catégories filtrées : $final_count (au lieu de 619)"
    
    echo "$filtered_categories"
}
