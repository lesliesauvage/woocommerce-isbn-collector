#!/bin/bash
source config/settings.sh

isbn="${1:-9782070360024}"
output="rakuten_complet_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

echo "📤 EXPORT RAKUTEN COMPLET - TOUS LES CHAMPS REMPLIS"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Fonction de nettoyage simple
clean_text() {
    echo "$1" | tr '\n\r\t' ' ' | sed "s/'/ /g" | sed 's/"/ /g' | sed 's/;/,/g' | sed 's/  */ /g'
}

# RÉCUPÉRER LES DONNÉES
data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
SELECT 
    pm_isbn.meta_value,
    COALESCE(pm_title.meta_value, pm_g_title.meta_value, pm_i_title.meta_value, p.post_title, 'Sans titre'),
    IFNULL(pm_price.meta_value, '10.00'),
    IFNULL(pm_authors.meta_value, 'Auteur inconnu'),
    IFNULL(pm_publisher.meta_value, 'Éditeur inconnu'),
    IFNULL(pm_desc.meta_value, 'Description non disponible'),
    IFNULL(pm_condition.meta_value, 'bon'),
    IFNULL(pm_weight.meta_value, '200'),
    IFNULL(pm_pages.meta_value, '100'),
    IFNULL(pm_image.meta_value, ''),
    IFNULL(pm_date.meta_value, '2020')
FROM wp_${SITE_ID}_posts p
JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
LEFT JOIN wp_${SITE_ID}_postmeta pm_title ON p.ID = pm_title.post_id AND pm_title.meta_key = '_best_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_g_title ON p.ID = pm_g_title.post_id AND pm_g_title.meta_key = '_g_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_i_title ON p.ID = pm_i_title.post_id AND pm_i_title.meta_key = '_i_title'
LEFT JOIN wp_${SITE_ID}_postmeta pm_price ON p.ID = pm_price.post_id AND pm_price.meta_key = '_price'
LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
LEFT JOIN wp_${SITE_ID}_postmeta pm_publisher ON p.ID = pm_publisher.post_id AND pm_publisher.meta_key = '_best_publisher'
LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
LEFT JOIN wp_${SITE_ID}_postmeta pm_condition ON p.ID = pm_condition.post_id AND pm_condition.meta_key = '_book_condition'
LEFT JOIN wp_${SITE_ID}_postmeta pm_weight ON p.ID = pm_weight.post_id AND pm_weight.meta_key = '_calculated_weight'
LEFT JOIN wp_${SITE_ID}_postmeta pm_pages ON p.ID = pm_pages.post_id AND pm_pages.meta_key = '_best_pages'
LEFT JOIN wp_${SITE_ID}_postmeta pm_image ON p.ID = pm_image.post_id AND pm_image.meta_key = '_best_cover_image'
LEFT JOIN wp_${SITE_ID}_postmeta pm_date ON p.ID = pm_date.post_id AND pm_date.meta_key = '_g_publishedDate'
WHERE pm_isbn.meta_value = '$isbn'
LIMIT 1" 2>/dev/null)

# Parser
IFS=$'\t' read -r isbn titre prix auteurs editeur description condition poids pages image date_pub <<< "$data"

# Nettoyer tout
titre=$(clean_text "$titre")
auteurs=$(clean_text "$auteurs")
editeur=$(clean_text "$editeur")
description=$(clean_text "$description")

# Mapper condition
case "$condition" in
    "neuf") qualite="N" ;;
    "comme neuf") qualite="CN" ;;
    "très bon") qualite="TBE" ;;
    *) qualite="BE" ;;
esac

# Prix public
prix_public=$(echo "$prix * 1.3" | bc 2>/dev/null || echo "$prix")
prix_public=$(printf "%.2f" $prix_public)

# Image HTTPS
[[ "$image" =~ ^http:// ]] && image="${image/http:/https:}"

# GÉNÉRER LE FICHIER AVEC TOUS LES CHAMPS
{
# En-tête
echo -e "EAN / ISBN / Code produit\tRéférence unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualité * / Condition *\tQuantité * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire privé de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tRésumé du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thématique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode opération promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisée\tExpédition, Retrait / Shipping, Pick Up\tTéléphone / Phone number\tCode postale / Zip Code\tPays / Country"

# DONNÉES - TOUS LES CHAMPS REMPLIS EXPLICITEMENT
echo -ne "$isbn\t"                                                         # 1. ISBN
echo -ne "$isbn\t"                                                         # 2. SKU
echo -ne "$prix\t"                                                         # 3. Prix
echo -ne "$prix_public\t"                                                  # 4. Prix public
echo -ne "$qualite\t"                                                      # 5. Qualité
echo -ne "1\t"                                                             # 6. Quantité
echo -ne "Envoi rapide et soigné\t"                                      # 7. Commentaire
echo -ne "Stock A1\t"                                                      # 8. Commentaire privé
echo -ne "Livre\t"                                                         # 9. Type produit
echo -ne "$titre\t"                                                        # 10. TITRE
echo -ne "${description:0:100}\t"                                          # 11. Description courte
echo -ne "$description\t"                                                  # 12. Résumé
echo -ne "Français\t"                                                      # 13. LANGUE
echo -ne "$auteurs\t"                                                      # 14. Auteurs
echo -ne "$editeur\t"                                                      # 15. Éditeur
echo -ne "$date_pub\t"                                                     # 16. Date
echo -ne "Littérature française\t"                                         # 17. CLASSIFICATION
echo -ne "$poids\t"                                                        # 18. Poids
echo -ne "Moyen\t"                                                         # 19. Taille
echo -ne "$pages\t"                                                        # 20. Pages
echo -ne "$image\t"                                                        # 21. Image
echo -ne "\t"                                                              # 22. Images secondaires
echo -ne "\t"                                                              # 23. Code promo
echo -ne "\t"                                                              # 24. Vide
echo -ne "Livre en bon état\t"                                             # 25. Description perso
echo -ne "EXP / RET\t"                                                     # 26. Expédition
echo -ne "0668563512\t"                                                    # 27. Téléphone
echo -ne "76000\t"                                                         # 28. Code postal
echo "France"                                                              # 29. Pays
} > "$output"

echo "✅ Export créé : $output"
echo ""
echo "📊 VÉRIFICATION RAPIDE :"
echo "────────────────────────"
echo "Colonnes : $(tail -1 "$output" | awk -F'\t' '{print NF}')"
echo ""
echo "🎯 COLONNES CLÉS :"
tail -1 "$output" | awk -F'\t' '{
    printf "Col 1 (ISBN): %s\n", $1
    printf "Col 7 (Commentaire): %s\n", $7
    printf "Col 9 (Type): %s\n", $9
    printf "Col 10 (TITRE): %s\n", $10
    printf "Col 13 (LANGUE): %s\n", $13
    printf "Col 17 (CLASSIFICATION): %s\n", $17
    printf "Col 29 (Pays): %s\n", $29
}'
echo ""
echo "🚀 Fichier prêt : $output"
