#!/bin/bash
# lib/category_filter.sh - Filtrage intelligent des catégories pour réduire les tokens

# Fonction pour filtrer les catégories pertinentes basées sur le titre et la description
filter_relevant_categories() {
    local title="$1"
    local authors="$2"
    local description="$3"
    local all_categories="$4"
    local post_id="$5"  # NOUVEAU : pour récupérer la catégorie Google Books
    
    debug_echo "[DEBUG] Filtrage des catégories pour : $title"
    
    # PRIORITÉ 1 : Utiliser la catégorie Google Books si disponible
    local google_category=""
    if [ -n "$post_id" ]; then
        google_category=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_value FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = $post_id AND meta_key = '_g_categories' LIMIT 1" 2>/dev/null)
        
        debug_echo "[DEBUG] Catégorie Google Books : $google_category"
    fi
    
    # Convertir en minuscules pour la comparaison
    local title_lower=$(echo "$title" | tr '[:upper:]' '[:lower:]')
    local desc_lower=$(echo "$description" | tr '[:upper:]' '[:lower:]')
    local google_cat_lower=$(echo "$google_category" | tr '[:upper:]' '[:lower:]')
    local combined_text="$title_lower $desc_lower $authors $google_cat_lower"
    
    # Mots-clés pour identifier les catégories pertinentes
    local keywords=""
    local excluded_categories=""
    
    # MAPPING basé sur Google Books en priorité
    if [ -n "$google_category" ]; then
        debug_echo "[DEBUG] Utilisation du mapping Google Books"
        
        # Fiction / Literature
        if echo "$google_cat_lower" | grep -qE "fiction|literature|literary|novel"; then
            keywords="LITTÉRATURE|Romans|Nouvelle|Fiction|Thriller|Policier"
            excluded_categories="ENFANTS|ADOS|SAVOIRS|BIEN-ÊTRE"
        fi
        
        # Science / Technology
        if echo "$google_cat_lower" | grep -qE "science|technology|computers|mathematics"; then
            keywords="SAVOIRS|Sciences|Informatique|Mathématiques"
            excluded_categories="LITTÉRATURE|ENFANTS|ADOS"
        fi
        
        # Children / Juvenile
        if echo "$google_cat_lower" | grep -qE "juvenile|children|young"; then
            keywords="ENFANTS|ADOS|JEUNES|Albums"
            excluded_categories="LITTÉRATURE.*Romans|ART.*CULTURE.*(?!.*jeunesse)"
        fi
        
        # Cooking / Food
        if echo "$google_cat_lower" | grep -qE "cooking|food|cuisine|recipe"; then
            keywords="Cuisine|Gastronomie|BIEN-ÊTRE.*VIE PRATIQUE"
            excluded_categories="LITTÉRATURE|ENFANTS|SAVOIRS"
        fi
        
        # History
        if echo "$google_cat_lower" | grep -qE "history|historical"; then
            keywords="Histoire|ART.*CULTURE.*Histoire|Biographies"
            excluded_categories="ENFANTS|ADOS.*(?!.*historique)"
        fi
        
        # Art / Design
        if echo "$google_cat_lower" | grep -qE "art|design|architecture|photography"; then
            keywords="ART.*CULTURE|Arts|Architecture|Photographie|Design"
            excluded_categories="ENFANTS|SAVOIRS.*(?!.*art)"
        fi
        
        # Philosophy / Psychology
        if echo "$google_cat_lower" | grep -qE "philosophy|psychology|self-help"; then
            keywords="Philosophie|Psychologie|Développement personnel|BIEN-ÊTRE"
            excluded_categories="ENFANTS|ADOS"
        fi
        
        # Comics / Manga
        if echo "$google_cat_lower" | grep -qE "comics|manga|graphic"; then
            keywords="MANGA|BANDE DESSINÉE|BD|Comics"
            excluded_categories="LITTÉRATURE.*(?!.*graphique)"
        fi
        
        # Travel
        if echo "$google_cat_lower" | grep -qE "travel|guide"; then
            keywords="Voyage|LOISIRS.*VOYAGES|Guide"
            excluded_categories="ENFANTS|SAVOIRS"
        fi
        
        # Religion / Spirituality
        if echo "$google_cat_lower" | grep -qE "religion|spiritual|esoteric"; then
            keywords="Religions|Ésotérisme|Spiritualité"
            excluded_categories="ENFANTS|ADOS"
        fi
        
        # Business / Economics
        if echo "$google_cat_lower" | grep -qE "business|economics|management"; then
            keywords="Business|Économie|Management|SAVOIRS.*Business"
            excluded_categories="ENFANTS|LITTÉRATURE"
        fi
        
        # Medical / Health
        if echo "$google_cat_lower" | grep -qE "medical|health|medicine"; then
            keywords="Médecine|Santé|SAVOIRS.*Médecine|BIEN-ÊTRE.*Santé"
            excluded_categories="ENFANTS|LITTÉRATURE"
        fi
    fi
    
    # Si pas de catégorie Google ou pas de match, utiliser l'ancienne méthode
    if [ -z "$keywords" ]; then
        debug_echo "[DEBUG] Pas de mapping Google Books, utilisation des mots-clés du titre"
    
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