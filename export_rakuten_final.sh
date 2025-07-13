#!/bin/bash
source config/settings.sh

# Fonction pour nettoyer COMPLÈTEMENT le texte selon les règles Rakuten
clean_rakuten_text() {
    echo "$1" | \
    tr '\n' ' ' | \
    tr '\r' ' ' | \
    tr '\t' ' ' | \
    sed 's/'/'\''/g' | \
    sed 's/'/'\''/g' | \
    sed 's/"/"/g' | \
    sed 's/"/"/g' | \
    sed 's/«/ /g' | \
    sed 's/»/ /g' | \
    sed 's/…/.../g' | \
    sed 's/—/-/g' | \
    sed 's/–/-/g' | \
    sed 's/  */ /g' | \
    sed 's/^ *//;s/ *$//'
}

# Fonction pour nettoyer avec <br />
clean_with_br() {
    echo "$1" | \
    sed 's/\r\n/<br \/>/g' | \
    sed 's/\n/<br \/>/g' | \
    sed 's/\r/<br \/>/g' | \
    sed 's/'/'\''/g' | \
    sed 's/'/'\''/g' | \
    sed 's/"/"/g' | \
    sed 's/"/"/g' | \
    sed 's/«/ /g' | \
    sed 's/»/ /g' | \
    sed 's/…/.../g'
}

isbn="${1:-9782070360024}"

echo "📤 EXPORT RAKUTEN CONFORME - ISBN: $isbn"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Récupérer TOUTES les données
all_data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT 
    pm_isbn.meta_value as isbn,
    COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title) as titre,
    CAST(IFNULL(pm_price.meta_value, '0') AS DECIMAL(10,2)) as prix,
    CAST(IFNULL(pm_regular.meta_value, pm_price.meta_value) AS DECIMAL(10,2)) as prix_public,
    pm_condition.meta_value as condition_livre,
    CAST(IFNULL(pm_stock.meta_value, '1') AS UNSIGNED) as stock,
    pm_desc.meta_value as description,
    pm_authors.meta_value as auteurs,
    pm_publisher.meta_value as editeur,
    pm_date.meta_value as date_parution,
    CAST(IFNULL(pm_weight.meta_value, '200') AS UNSIGNED) as poids,
    pm_binding.meta_value as binding,
    CAST(IFNULL(pm_pages.meta_value, '0') AS UNSIGNED) as pages,
    pm_image.meta_value as image,
    (SELECT GROUP_CONCAT(t.name ORDER BY tt.parent SEPARATOR ' > ') 
     FROM wp_${SITE_ID}_term_relationships tr
     JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
     JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
     WHERE tr.object_id = p.ID AND tt.taxonomy = 'product_cat') as wp_category
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
IFS=$'\t' read -r isbn titre prix prix_public condition stock description auteurs editeur date_parution poids binding pages image wp_category <<< "$all_data"

# Nettoyer toutes les variables
titre=$(clean_rakuten_text "$titre")
description=$(clean_with_br "$description")
auteurs=$(clean_rakuten_text "$auteurs")
editeur=$(clean_rakuten_text "$editeur")
commentaire=$(clean_rakuten_text "Envoi rapide et soigné. Livre en ${condition:-bon} état.")

# Mapper la catégorie
source lib/rakuten_category_mapping.sh 2>/dev/null
rakuten_category=$(map_to_rakuten_category "$wp_category")
rakuten_category=$(clean_rakuten_text "$rakuten_category")

# VÉRIFICATIONS STRICTES
echo "📊 VÉRIFICATIONS DES DONNÉES..."
echo "────────────────────────────────"
errors=0

# Vérifier ISBN (13 caractères)
if [[ ! "$isbn" =~ ^[0-9]{13}$ ]] && [[ ! "$isbn" =~ ^[0-9]{10}$ ]]; then
    echo "❌ ISBN invalide : $isbn (doit être 10 ou 13 chiffres)"
    ((errors++))
else
    echo "✅ ISBN : $isbn"
fi

# Vérifier prix (nombre décimal)
if [[ ! "$prix" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] || [ "$prix" = "0" ]; then
    echo "❌ Prix invalide : $prix"
    ((errors++))
else
    echo "✅ Prix : $prix €"
fi

# Vérifier stock (entier 1-999)
if [[ ! "$stock" =~ ^[0-9]+$ ]] || [ "$stock" -lt 1 ] || [ "$stock" -gt 999 ]; then
    echo "❌ Stock invalide : $stock (doit être entre 1 et 999)"
    ((errors++))
else
    echo "✅ Stock : $stock"
fi

# Vérifier poids (entier en grammes)
if [[ ! "$poids" =~ ^[0-9]+$ ]]; then
    echo "❌ Poids invalide : $poids (doit être un entier)"
    ((errors++))
else
    echo "✅ Poids : $poids g"
fi

# Vérifier titre
if [ -z "$titre" ]; then
    echo "❌ Titre VIDE"
    ((errors++))
else
    echo "✅ Titre : $titre"
fi

# Vérifier image (doit commencer par https://)
if [ -n "$image" ] && [[ ! "$image" =~ ^https:// ]]; then
    # Corriger http:// en https://
    image="${image/http:/https:}"
fi

if [ $errors -gt 0 ]; then
    echo ""
    echo "🛑 EXPORT ANNULÉ : $errors erreur(s) détectée(s)"
    exit 1
fi

echo ""
echo "✅ TOUTES LES VÉRIFICATIONS PASSÉES !"
echo ""
echo "📝 Génération du fichier..."

output="rakuten_final_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

# Créer le fichier avec toutes les règles Rakuten
{
# En-tête
echo -e "EAN / ISBN / Code produit\tRéférence unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualité * / Condition *\tQuantité * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire privé de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tRésumé du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thématique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode opération promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisée\tExpédition, Retrait / Shipping, Pick Up\tTéléphone / Phone number\tCode postale / Zip Code\tPays / Country"

# Données nettoyées
echo -ne "$isbn\t"
echo -ne "$isbn\t"
echo -ne "$prix\t"
echo -ne "$prix_public\t"
case "$condition" in
    "neuf") echo -ne "N\t" ;;
    "comme neuf") echo -ne "CN\t" ;;
    "très bon") echo -ne "TBE\t" ;;
    "bon") echo -ne "BE\t" ;;
    *) echo -ne "BE\t" ;;
esac
echo -ne "$stock\t"
echo -ne "$commentaire\t"
echo -ne "\t"
echo -ne "Livre\t"
echo -ne "$titre\t"
echo -ne "${description:0:200}\t"
echo -ne "$description\t"
echo -ne "Français\t"
echo -ne "$auteurs\t"
echo -ne "$editeur\t"
echo -ne "$date_parution\t"
echo -ne "${rakuten_category:-Littérature française}\t"
echo -ne "$poids\t"
case "$binding" in
    *"poche"*) echo -ne "Petit\t" ;;
    *"grand"*) echo -ne "Grand\t" ;;
    *) echo -ne "Moyen\t" ;;
esac
echo -ne "$pages\t"
echo -ne "$image\t"
echo -ne "\t"
echo -ne "\t"
echo -ne "\t"
echo -ne "<div><h3>$titre</h3><p>${description:0:500}</p></div>\t"
echo -ne "EXP / RET\t"
echo -ne "0668563512\t"
echo -ne "76000\t"
echo -e "France"
} > "$output"

# Convertir en UTF-16 si demandé
echo ""
echo "💾 Fichiers créés :"
echo "─────────────────"
echo "✅ UTF-8 : $output"

# Créer version UTF-16
iconv -f UTF-8 -t UTF-16LE "$output" > "${output%.txt}_utf16.txt"
echo "✅ UTF-16 : ${output%.txt}_utf16.txt"

echo ""
echo "📊 Vérifications finales :"
echo "─────────────────────────"
echo "Colonnes : $(head -1 "$output" | awk -F'\t' '{print NF}')"
echo "Titre : $(tail -1 "$output" | cut -f10)"
echo "Classification : $(tail -1 "$output" | cut -f17)"
echo ""
echo "🚀 Uploadez le fichier UTF-16 sur Rakuten !"
