#!/bin/bash
# Export Claude AI - Format optimisé pour recommandations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

MARKETPLACE="claude"
OUTPUT_FILE="exports/output/generer_${MARKETPLACE}_$(date +%Y%m%d_%H%M%S).txt"

echo "=== EXPORT CLAUDE AI ==="
echo "Date : $(date)"
echo ""

# Récupérer TOUS les livres avec données enrichies
books=$(safe_mysql "
    SELECT DISTINCT p.ID
    FROM wp_${SITE_ID}_posts p
    JOIN wp_${SITE_ID}_postmeta pm1 ON p.ID = pm1.post_id AND pm1.meta_key = '_isbn'
    WHERE p.post_type = 'product'
    AND p.post_status = 'publish'
    ORDER BY p.ID DESC")

count=$(echo "$books" | wc -l)
echo "📊 Livres à exporter : $count"
echo ""

# En-tête du fichier pour Claude
cat > "$OUTPUT_FILE" << 'HEADER'
CATALOGUE LIVRES POUR RECOMMANDATIONS IA
========================================

Ce fichier contient l'inventaire complet des livres disponibles.
Utilisez ces données pour recommander des livres connexes lors d'un achat.

Format : Un livre par bloc avec toutes les métadonnées disponibles.

========================================

HEADER

# Export des données
exported=0
while read -r product_id; do
    [ -z "$product_id" ] && continue
    
    # Récupérer toutes les données du livre
    isbn=$(safe_get_meta "$product_id" "_isbn")
    sku=$(safe_get_meta "$product_id" "_sku")
    
    # Données bibliographiques
    title=$(safe_get_meta "$product_id" "_best_title")
    [ -z "$title" ] && title=$(safe_get_meta "$product_id" "_g_title")
    [ -z "$title" ] && title=$(safe_mysql "SELECT post_title FROM wp_${SITE_ID}_posts WHERE ID=$product_id")
    
    authors=$(safe_get_meta "$product_id" "_best_authors")
    [ -z "$authors" ] && authors=$(safe_get_meta "$product_id" "_g_authors")
    
    publisher=$(safe_get_meta "$product_id" "_best_publisher")
    [ -z "$publisher" ] && publisher=$(safe_get_meta "$product_id" "_g_publisher")
    
    publish_date=$(safe_get_meta "$product_id" "_g_publishedDate")
    
    # Description et contenu
    description=$(safe_get_meta "$product_id" "_best_description")
    [ -z "$description" ] && description=$(safe_get_meta "$product_id" "_g_description")
    [ -z "$description" ] && description=$(safe_get_meta "$product_id" "_groq_description")
    
    # Catégorisation
    categories=$(safe_get_meta "$product_id" "_g_categories")
    subjects=$(safe_get_meta "$product_id" "_i_subjects")
    [ -z "$subjects" ] && subjects=$(safe_get_meta "$product_id" "_o_subjects")
    
    genre=$(safe_get_meta "$product_id" "_calculated_genre")
    target_age=$(safe_get_meta "$product_id" "_calculated_target_age")
    
    # Catégorie de référence pour mapping
    cat_reference=$(safe_get_meta "$product_id" "_g_categorie_reference")
    
    # Caractéristiques physiques
    pages=$(safe_get_meta "$product_id" "_best_pages")
    [ -z "$pages" ] && pages=$(safe_get_meta "$product_id" "_g_pageCount")
    
    binding=$(safe_get_meta "$product_id" "_i_binding")
    [ -z "$binding" ] && binding=$(safe_get_meta "$product_id" "_o_physical_format")
    
    language=$(safe_get_meta "$product_id" "_g_language")
    [ -z "$language" ] && language="fr"
    
    weight=$(safe_get_meta "$product_id" "_calculated_weight")
    
    # Commercial
    price=$(safe_get_meta "$product_id" "_price")
    stock=$(safe_get_meta "$product_id" "_stock")
    condition=$(safe_get_meta "$product_id" "_book_condition")
    
    # Catégories WordPress
    wp_categories=$(safe_mysql "
        SELECT GROUP_CONCAT(t.name SEPARATOR ', ')
        FROM wp_${SITE_ID}_term_relationships tr
        JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
        JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
        WHERE tr.object_id = $product_id
        AND tt.taxonomy = 'product_cat'")
    
    # Écrire dans le fichier
    {
        echo "────────────────────────────────────────────────────────────────"
        echo "📚 ID: $product_id | ISBN: $isbn"
        echo "────────────────────────────────────────────────────────────────"
        echo ""
        echo "TITRE: $title"
        [ -n "$authors" ] && echo "AUTEUR(S): $authors"
        [ -n "$publisher" ] && echo "ÉDITEUR: $publisher"
        [ -n "$publish_date" ] && echo "DATE PUBLICATION: $publish_date"
        echo ""
        
        if [ -n "$categories" ] || [ -n "$subjects" ] || [ -n "$wp_categories" ]; then
            echo "🏷️ CATÉGORISATION:"
            [ -n "$categories" ] && echo "  Catégories Google: $categories"
            [ -n "$cat_reference" ] && echo "  Catégorie référence: $cat_reference"
            [ -n "$subjects" ] && echo "  Sujets: $subjects"
            [ -n "$wp_categories" ] && echo "  Catégories site: $wp_categories"
            [ -n "$genre" ] && echo "  Genre: $genre"
            [ -n "$target_age" ] && echo "  Âge cible: $target_age"
            echo ""
        fi
        
        echo "📖 CARACTÉRISTIQUES:"
        echo "  Prix: ${price:-0}€ | Stock: ${stock:-0} | État: ${condition:-Non précisé}"
        [ -n "$pages" ] && [ "$pages" != "0" ] && echo "  Pages: $pages"
        [ -n "$binding" ] && echo "  Format: $binding"
        [ -n "$language" ] && echo "  Langue: $language"
        [ -n "$weight" ] && echo "  Poids: ${weight}g"
        echo ""
        
        if [ -n "$description" ]; then
            echo "📄 DESCRIPTION:"
            # Limiter la description à 500 caractères pour la lisibilité
            if [ ${#description} -gt 500 ]; then
                echo "${description:0:497}..."
            else
                echo "$description"
            fi
            echo ""
        fi
        
        # Tags de recherche pour l'IA
        echo "🔍 MOTS-CLÉS POUR RECOMMANDATIONS:"
        tags=""
        [ -n "$authors" ] && tags="$tags auteur:${authors// /, }"
        [ -n "$publisher" ] && tags="$tags éditeur:$publisher"
        [ -n "$categories" ] && tags="$tags catégories:$categories"
        [ -n "$genre" ] && tags="$tags genre:$genre"
        [ -n "$binding" ] && tags="$tags format:$binding"
        [ -n "$language" ] && tags="$tags langue:$language"
        echo "$tags"
        echo ""
        echo ""
    } >> "$OUTPUT_FILE"
    
    ((exported++))
    echo -ne "\r🔄 Export : $exported/$count"
done <<< "$books"

# Ajouter les instructions pour Claude à la fin
cat >> "$OUTPUT_FILE" << 'FOOTER'

========================================
INSTRUCTIONS POUR CLAUDE AI
========================================

Utilisez ce catalogue pour :

1. RECOMMANDATIONS PAR SIMILARITÉ
   - Même auteur → proposer autres œuvres
   - Même éditeur/collection → suggérer la série
   - Même catégorie → livres du même genre
   - Même âge cible → adaptés au public

2. RECOMMANDATIONS COMPLÉMENTAIRES
   - Romans → autres tomes, même univers
   - Pratique → livres connexes du domaine
   - Jeunesse → même tranche d'âge
   - BD/Manga → suites ou même style

3. CRITÈRES DE SÉLECTION
   - Privilégier les livres EN STOCK
   - Tenir compte du PRIX (gamme similaire)
   - Vérifier la LANGUE
   - Considérer l'ÉTAT du livre

4. FORMAT DE RÉPONSE SUGGÉRÉ
   "Vous pourriez aussi aimer :"
   - [Titre] de [Auteur] - [Prix]€
     → Pourquoi : [raison courte]

Exemple : Client achète "L'Étranger" de Camus
→ Suggérer : "La Peste" de Camus (même auteur)
→ Suggérer : "Huis Clos" de Sartre (existentialisme)

========================================
FOOTER

echo ""
echo ""
echo "✅ Export terminé : $OUTPUT_FILE"
echo "📊 Livres exportés : $exported"
echo ""
echo "💡 Ce fichier est optimisé pour Claude AI avec :"
echo "   • Toutes les métadonnées de chaque livre"
echo "   • Format structuré et lisible"
echo "   • Mots-clés pour faciliter les recommandations"
echo "   • Instructions d'utilisation intégrées"
