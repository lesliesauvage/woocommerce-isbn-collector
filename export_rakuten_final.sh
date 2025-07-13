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

# RÉCUPÉRER TOUTES LES DONNÉES D'UN COUP
echo "📊 Récupération de TOUTES les données..."
echo "───────────────────────────────────────────"

# Récupérer toutes les données incluant TOUTE la hiérarchie des catégories
all_data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
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
    pm_regular.meta_value as prix_public,
    pm_condition.meta_value as condition_livre,
    pm_stock.meta_value as stock,
    CONCAT('Envoi rapide et soigné. Livre en ', IFNULL(pm_condition.meta_value, 'bon'), ' état.') as commentaire,
    pm_desc.meta_value as description,
    pm_authors.meta_value as auteurs,
    pm_publisher.meta_value as editeur,
    pm_date.meta_value as date_parution,
    (SELECT path FROM CategoryPath ORDER BY level DESC LIMIT 1) as wp_category,
    pm_weight.meta_value as poids,
    pm_binding.meta_value as binding,
    pm_pages.meta_value as pages,
    pm_image.meta_value as image,
    p.ID as post_id
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_g_title ON p.ID = pm_g_title.post_id AND pm_g_title.meta_key = '_g_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_i_title ON p.ID = pm_i_title.post_id AND pm_i_title.meta_key = '_i_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_regular ON p.ID = pm_regular.post_id AND pm_regular.meta_key = '_regular_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
LEFT JOIN wp_${SITE_ID}_postmeta pm_stock ON p.ID = pm_stock.post_id AND pm_stock.meta_key = '_stock'
LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id AND pm_publisher.meta_key = '_best_publisher'
LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_g_publishedDate'
LEFT JOIN wp_${SITE_ID}_postmeta pm_weight ON p.ID = pm_weight.post_id AND pm_weight.meta_key = '_calculated_weight'
LEFT JOIN wp_${SITE_ID}_postmeta pm_binding ON p.ID = pm_binding.post_id AND pm_binding.meta_key = '_best_binding'
LEFT JOIN wp_${SITE_ID}_postmeta pm_pages ON p.ID = pm_pages.post_id AND pm_pages.meta_key = '_best_pages'
LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null)

# Parser les données
IFS=$'\t' read -r isbn titre prix prix_public condition stock commentaire description auteurs editeur date_parution wp_category poids binding pages image post_id <<< "$all_data"

# Mapper la catégorie
rakuten_category=$(map_to_rakuten_category "$wp_category")

# VÉRIFICATION STRICTE DE TOUS LES CHAMPS OBLIGATOIRES
echo ""
echo "🔍 VÉRIFICATION DES CHAMPS OBLIGATOIRES..."
echo "══════════════════════════════════════════"
errors=0

# ISBN (col 1)
if [ -z "$isbn" ]; then
    echo "❌ [Col 1] ISBN/EAN : VIDE"
    ((errors++))
else
    echo "✅ [Col 1] ISBN/EAN : $isbn"
fi

# Prix (col 3)
if [ -z "$prix" ] || [ "$prix" = "0" ]; then
    echo "❌ [Col 3] Prix de vente : VIDE ou 0"
    ((errors++))
else
    echo "✅ [Col 3] Prix de vente : $prix €"
fi

# Qualité (col 5)
if [ -z "$condition" ]; then
    echo "❌ [Col 5] Qualité/Condition : VIDE"
    ((errors++))
else
    echo "✅ [Col 5] Qualité/Condition : $condition"
fi

# Commentaire annonce (col 7)
if [ -z "$commentaire" ]; then
    echo "❌ [Col 7] Commentaire annonce : VIDE"
    ((errors++))
else
    echo "✅ [Col 7] Commentaire annonce : $commentaire"
fi

# TITRE (col 10) - LE PLUS IMPORTANT
if [ -z "$titre" ]; then
    echo "❌ [Col 10] TITRE : VIDE ⚠️⚠️⚠️"
    ((errors++))
else
    echo "✅ [Col 10] Titre : $titre"
fi

# LANGUE (col 13) - TOUJOURS FRANÇAIS
echo "✅ [Col 13] Langue : Français (FIXÉ EN DUR)"

# Auteurs (col 14)
if [ -z "$auteurs" ]; then
    echo "❌ [Col 14] Auteurs : VIDE"
    ((errors++))
else
    echo "✅ [Col 14] Auteurs : $auteurs"
fi

# Éditeur (col 15)
if [ -z "$editeur" ]; then
    echo "❌ [Col 15] Éditeur : VIDE"
    ((errors++))
else
    echo "✅ [Col 15] Éditeur : $editeur"
fi

# Date de parution (col 16)
if [ -z "$date_parution" ]; then
    echo "❌ [Col 16] Date de parution : VIDE"
    ((errors++))
else
    echo "✅ [Col 16] Date de parution : $date_parution"
fi

# Classification Thématique (col 17)
if [ -z "$rakuten_category" ]; then
    echo "❌ [Col 17] Classification Thématique : VIDE"
    ((errors++))
else
    echo "✅ [Col 17] Classification Thématique : $rakuten_category"
fi

echo ""
echo "🔍 Catégorie WordPress complète : $wp_category"
echo ""

# DÉCISION FINALE
echo "════════════════════════════════════════════════════════════════"

if [ $errors -gt 0 ]; then
    echo "🛑 EXPORT ANNULÉ : $errors champ(s) obligatoire(s) manquant(s) !"
    echo ""
    echo "⚠️  AUCUN FICHIER N'A ÉTÉ GÉNÉRÉ !"
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
    exit 1
fi

echo "✅ TOUS LES CHAMPS OBLIGATOIRES SONT REMPLIS !"
echo ""
echo "📝 Génération du fichier d'export..."

output="rakuten_final_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

# Créer le fichier avec TOUS les champs REMPLIS
{
# En-tête
echo -e "EAN / ISBN / Code produit\tRéférence unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualité * / Condition *\tQuantité * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire privé de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tRésumé du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thématique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode opération promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisée\tExpédition, Retrait / Shipping, Pick Up\tTéléphone / Phone number\tCode postale / Zip Code\tPays / Country"

# Données - UNE SEULE LIGNE AVEC TOUT
echo -ne "$isbn\t"                                                          # 1. EAN/ISBN
echo -ne "$isbn\t"                                                          # 2. SKU
echo -ne "$prix\t"                                                          # 3. Prix de vente
echo -ne "${prix_public:-$prix}\t"                                          # 4. Prix public
case "$condition" in
    "neuf") echo -ne "N\t" ;;
    "comme neuf") echo -ne "CN\t" ;;
    "très bon") echo -ne "TBE\t" ;;
    "bon") echo -ne "BE\t" ;;
    *) echo -ne "BE\t" ;;
esac                                                                        # 5. Qualité
echo -ne "${stock:-1}\t"                                                    # 6. Quantité
echo -ne "$commentaire\t"                                                   # 7. Commentaire annonce
echo -ne "\t"                                                               # 8. Commentaire privé
echo -ne "Livre\t"                                                          # 9. Type de produit
echo -ne "$(clean_text "$titre" | sed "s/L'/L /g")\t"                     # 10. TITRE
echo -ne "$(clean_text "${description:0:200}")\t"                          # 11. Description courte
echo -ne "$(clean_text "$description")\t"                                  # 12. Résumé
echo -ne "Français\t"                                                       # 13. LANGUE TOUJOURS FRANÇAIS
echo -ne "$auteurs\t"                                                       # 14. Auteurs
echo -ne "$editeur\t"                                                       # 15. Éditeur
echo -ne "$date_parution\t"                                                 # 16. Date parution
echo -ne "$rakuten_category\t"                                              # 17. CLASSIFICATION THÉMATIQUE
echo -ne "${poids:-200}\t"                                                  # 18. Poids
case "$binding" in
    *"poche"*) echo -ne "Petit\t" ;;
    *"grand"*) echo -ne "Grand\t" ;;
    *) echo -ne "Moyen\t" ;;
esac                                                                        # 19. Taille
echo -ne "${pages:-}\t"                                                     # 20. Pages
echo -ne "${image:-}\t"                                                     # 21. Image principale
echo -ne "\t"                                                               # 22. Images secondaires
echo -ne "\t"                                                               # 23. Code promo
echo -ne "\t"                                                               # 24. Vide
echo -ne "<div><h3>$(clean_text "$titre" | sed "s/L'/L /g")</h3><p>$(clean_text "${description:0:500}")</p></div>\t"  # 25. Description HTML
echo -ne "EXP / RET\t"                                                      # 26. Expédition
echo -ne "0668563512\t"                                                     # 27. Téléphone
echo -ne "76000\t"                                                          # 28. Code postal
echo -e "France"                                                            # 29. Pays
} > "$output"

echo ""
echo "✅ Export créé : $output"
echo ""
echo "📋 VÉRIFICATIONS FINALES :"
echo "──────────────────────────"
echo "Nombre de colonnes : $(head -1 "$output" | awk -F'\t' '{print NF}')"
echo "Titre exporté : $(tail -1 "$output" | cut -f10)"
echo "Langue : $(tail -1 "$output" | cut -f13)"
echo "Classification : $(tail -1 "$output" | cut -f17)"
echo ""
echo "💾 Fichier prêt pour upload sur Rakuten !"
