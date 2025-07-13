#!/bin/bash
source config/settings.sh

# Fonction pour nettoyer le texte
clean_text() {
    echo "$1" | tr '\n' ' ' | tr '\r' ' ' | tr '\t' ' ' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//'
}

# FONCTION DE MAPPING DEPUIS LE FICHIER CSV
map_to_rakuten_category() {
    local category_path="$1"
    local mapping_file="config/rakuten_category_mapping.csv"
    
    # Chercher une correspondance exacte dans le fichier
    if [ -f "$mapping_file" ]; then
        local mapped=$(grep -F "\"$category_path\"," "$mapping_file" | head -1 | cut -d',' -f2 | tr -d '"')
        if [ -n "$mapped" ]; then
            echo "$mapped"
            return
        fi
        
        # Si pas de correspondance exacte, chercher une correspondance partielle
        # D'abord essayer avec le dernier niveau
        local last_level=$(echo "$category_path" | rev | cut -d'>' -f1 | rev | xargs)
        mapped=$(grep -i "$last_level" "$mapping_file" | head -1 | cut -d',' -f2 | tr -d '"')
        if [ -n "$mapped" ]; then
            echo "$mapped"
            return
        fi
        
        # Ensuite essayer avec des mots-clés
        local keywords=("littérature" "romans" "jeunesse" "histoire" "science" "art" "philosophie" "médecine" "informatique" "cuisine" "voyage")
        for keyword in "${keywords[@]}"; do
            if [[ "${category_path,,}" =~ $keyword ]]; then
                mapped=$(grep -i "$keyword" "$mapping_file" | head -1 | cut -d',' -f2 | tr -d '"')
                if [ -n "$mapped" ]; then
                    echo "$mapped"
                    return
                fi
            fi
        done
    fi
    
    # Valeur par défaut
    echo "Littérature française"
}

isbn="${1:-9782070360024}"

echo "📤 EXPORT RAKUTEN - ISBN: $isbn"
echo "════════════════════════════════════════════════════════════════"
echo ""

# VÉRIFICATION DES DONNÉES OBLIGATOIRES AVANT EXPORT
echo "🔍 VÉRIFICATION DES DONNÉES OBLIGATOIRES..."
echo "───────────────────────────────────────────"

# Récupérer toutes les données incluant TOUTE la hiérarchie des catégories
data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
WITH RECURSIVE CategoryPath AS (
    -- Trouver toutes les catégories du produit
    SELECT 
        tt.term_id,
        t.name,
        tt.parent,
        CAST(t.name AS CHAR(1000)) AS path,
        0 as level
    FROM wp_${SITE_ID}_posts p
    JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
    JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id AND tt.taxonomy = 'product_cat'
    JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
    WHERE pm_isbn.meta_value = '$isbn'
    
    UNION ALL
    
    -- Remonter la hiérarchie
    SELECT 
        tt.term_id,
        t.name,
        tt.parent,
        CONCAT(t.name, ' > ', cp.path) AS path,
        cp.level + 1
    FROM CategoryPath cp
    JOIN wp_${SITE_ID}_term_taxonomy tt ON cp.parent = tt.term_id AND tt.taxonomy = 'product_cat'
    JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
    WHERE cp.parent > 0
)
SELECT 
    pm_isbn.meta_value as isbn,
    COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title) as titre,
    pm_price.meta_value as prix,
    pm_condition.meta_value as condition_livre,
    pm_authors.meta_value as auteurs,
    pm_publisher.meta_value as editeur,
    pm_date.meta_value as date_parution,
    (SELECT path FROM CategoryPath ORDER BY level DESC LIMIT 1) as wp_category,
    p.ID as post_id
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_g_title ON p.ID = pm_g_title.post_id AND pm_g_title.meta_key = '_g_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_i_title ON p.ID = pm_i_title.post_id AND pm_i_title.meta_key = '_i_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id AND pm_publisher.meta_key = '_best_publisher'
LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_g_publishedDate'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null)

# Parser les données
IFS=$'\t' read -r isbn titre prix condition auteurs editeur date_parution wp_category post_id <<< "$data"

# Mapper la catégorie
rakuten_category=$(map_to_rakuten_category "$wp_category")

# Vérifier chaque champ obligatoire
errors=0
echo ""
echo "📋 CHAMPS OBLIGATOIRES RAKUTEN :"
echo ""

# ISBN
if [ -z "$isbn" ]; then
    echo "❌ ISBN/EAN : VIDE (obligatoire)"
    ((errors++))
else
    echo "✅ ISBN/EAN : $isbn"
fi

# Prix
if [ -z "$prix" ] || [ "$prix" = "0" ]; then
    echo "❌ Prix de vente : VIDE ou 0 (obligatoire)"
    ((errors++))
else
    echo "✅ Prix de vente : $prix €"
fi

# Qualité
if [ -z "$condition" ]; then
    echo "❌ Qualité/Condition : VIDE (obligatoire)"
    ((errors++))
else
    echo "✅ Qualité/Condition : $condition"
fi

# TITRE - LE PLUS IMPORTANT
if [ -z "$titre" ]; then
    echo "❌ TITRE : VIDE (obligatoire) ⚠️  CRITIQUE !"
    ((errors++))
else
    echo "✅ Titre : $titre"
fi

# Auteurs
if [ -z "$auteurs" ]; then
    echo "❌ Auteurs : VIDE (obligatoire)"
    ((errors++))
else
    echo "✅ Auteurs : $auteurs"
fi

# Éditeur
if [ -z "$editeur" ]; then
    echo "❌ Éditeur : VIDE (obligatoire)"
    ((errors++))
else
    echo "✅ Éditeur : $editeur"
fi

# Date de parution
if [ -z "$date_parution" ]; then
    echo "❌ Date de parution : VIDE (obligatoire)"
    ((errors++))
else
    echo "✅ Date de parution : $date_parution"
fi

# Catégorie
echo "✅ Catégorie WP : $wp_category"
echo "✅ Classification Rakuten : $rakuten_category"

# DÉCISION FINALE
echo ""
echo "════════════════════════════════════════════════════════════════"

if [ $errors -gt 0 ]; then
    echo "🛑 EXPORT ANNULÉ : $errors champ(s) obligatoire(s) manquant(s) !"
    echo ""
    echo "💡 SOLUTIONS :"
    echo "───────────────"
    echo "1. Relancer la collecte complète :"
    echo "   ./isbn_unified.sh $isbn -force"
    echo ""
    echo "2. Vérifier le statut de collecte :"
    echo "   ./analyze_with_collect.sh $isbn"
    echo ""
    echo "3. Si le problème persiste, collecter manuellement :"
    echo "   ./add_and_collect.sh $isbn"
    echo ""
    echo "❌ Aucun fichier d'export n'a été généré."
    exit 1
fi

echo "✅ TOUTES LES DONNÉES OBLIGATOIRES SONT PRÉSENTES !"
echo ""
echo "📝 Génération du fichier d'export..."

output="rakuten_final_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

# Créer le fichier avec TOUS les champs
{
# En-tête
echo -e "EAN / ISBN / Code produit\tRéférence unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualité * / Condition *\tQuantité * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire privé de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tRésumé du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thématique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode opération promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisée\tExpédition, Retrait / Shipping, Pick Up\tTéléphone / Phone number\tCode postale / Zip Code\tPays / Country"

# Données complètes - AVEC LA CATÉGORIE MAPPÉE
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT 
    pm_isbn.meta_value,
    pm_isbn.meta_value,
    IFNULL(pm_price.meta_value, '0'),
    IFNULL(pm_regular.meta_value, pm_price.meta_value),
    CASE 
        WHEN pm_condition.meta_value = 'neuf' THEN 'N'
        WHEN pm_condition.meta_value = 'comme neuf' THEN 'CN'
        WHEN pm_condition.meta_value = 'très bon' THEN 'TBE'
        WHEN pm_condition.meta_value = 'bon' THEN 'BE'
        ELSE 'BE'
    END,
    IFNULL(pm_stock.meta_value, '1'),
    CONCAT('Envoi rapide et soigné. Livre en ', IFNULL(pm_condition.meta_value, 'bon'), ' état.'),
    '',
    'Livre',
    REPLACE(REPLACE(REPLACE(REPLACE(COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title), '''', ' '), CHAR(10), ' '), CHAR(13), ' '), 'L''', 'L '),
    LEFT(REPLACE(REPLACE(IFNULL(pm_desc.meta_value, 'Roman classique'), CHAR(10), ' '), CHAR(13), ' '), 200),
    REPLACE(REPLACE(IFNULL(pm_desc.meta_value, 'Roman classique de la littérature française'), CHAR(10), ' '), CHAR(13), ' '),
    'Français',
    IFNULL(pm_authors.meta_value, ''),
    IFNULL(pm_publisher.meta_value, ''),
    IFNULL(pm_date.meta_value, ''),
    '$rakuten_category',
    IFNULL(pm_weight.meta_value, '200'),
    CASE
        WHEN pm_binding.meta_value LIKE '%poche%' THEN 'Petit'
        WHEN pm_binding.meta_value LIKE '%grand%' THEN 'Grand'
        ELSE 'Moyen'
    END,
    IFNULL(pm_pages.meta_value, ''),
    IFNULL(pm_image.meta_value, ''),
    '',
    '',
    '',
    CONCAT('<div><h3>', REPLACE(REPLACE(REPLACE(COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title), '''', ' '), CHAR(10), ' '), CHAR(13), ' '), '</h3><p>', LEFT(REPLACE(REPLACE(IFNULL(pm_desc.meta_value, ''), CHAR(10), ' '), CHAR(13), ' '), 500), '</p></div>'),
    'EXP / RET',
    '0668563512',
    '76000',
    'France'
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_regular ON p.ID = pm_regular.post_id AND pm_regular.meta_key = '_regular_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
LEFT JOIN wp_${SITE_ID}_postmeta pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_stock'
LEFT JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_g_title ON p.ID = pm_g_title.post_id AND pm_g_title.meta_key = '_g_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_i_title ON p.ID = pm_i_title.post_id AND pm_i_title.meta_key = '_i_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id AND pm_publisher.meta_key = '_best_publisher'
LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_g_publishedDate'
LEFT JOIN wp_${SITE_ID}_postmeta pm_weight ON p.ID = pm_weight.post_id AND pm_weight.meta_key = '_calculated_weight'
LEFT JOIN wp_${SITE_ID}_postmeta pm_binding ON p.ID = pm_binding.post_id AND pm_binding.meta_key = '_best_binding'
LEFT JOIN wp_${SITE_ID}_postmeta pm_pages ON p.ID = pm_pages.post_id AND pm_pages.meta_key = '_best_pages'
LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null
} > "$output"

echo ""
echo "✅ Export créé : $output"
echo ""
echo "📋 VÉRIFICATIONS FINALES :"
echo "──────────────────────────"
echo "Nombre de colonnes : $(head -1 "$output" | awk -F'\t' '{print NF}')"
echo "Titre exporté : $(tail -1 "$output" | cut -f10)"
echo "Classification : $(tail -1 "$output" | cut -f17)"
echo ""
echo "💾 Fichier prêt pour upload sur Rakuten !"
echo ""
echo "⚠️  NOTE : Les apostrophes ont été remplacées par des espaces"
echo "    'L'étranger' devient 'L étranger'"
