#!/bin/bash
source config/settings.sh

isbn="${1:-9782070360024}"
output="rakuten_simple_${isbn}_$(date +%Y%m%d_%H%M%S).txt"

echo "📤 EXPORT RAKUTEN ULTRA SIMPLE - AUCUN CARACTÈRE SPÉCIAL"
echo "════════════════════════════════════════════════════════════════"
echo ""

# En-tête
echo -e "EAN / ISBN / Code produit\tRéférence unique de l'annonce * / Unique Advert Refence (SKU) *\tPrix de vente * / Selling Price *\tPrix d'origine / RRP in euros\tQualité * / Condition *\tQuantité * / Quantity *\tCommentaire de l'annonce * / Advert comment *\tCommentaire privé de l'annonce / Private Advert Comment\tType de Produit * / Type of Product *\tTitre * / Title *\tDescription courte * / Short Description *\tRésumé du Livre ou Revue\tLangue\tAuteurs\tEditeur\tDate de parution\tClassification Thématique\tPoids en grammes / Weight in grammes\tTaille / Size\tNombre de Pages / Number of pages\tURL Image principale * / Main picture *\tURLs Images Secondaires / Secondary Picture\tCode opération promo / Promotion code\tColonne vide / void column\tDescription Annonce Personnalisée\tExpédition, Retrait / Shipping, Pick Up\tTéléphone / Phone number\tCode postale / Zip Code\tPays / Country" > "$output"

# Données ULTRA SIMPLES - AUCUN RISQUE
printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
    "$isbn" \
    "$isbn" \
    "10.00" \
    "13.00" \
    "BE" \
    "1" \
    "Envoi rapide" \
    "A1" \
    "Livre" \
    "Titre du livre" \
    "Description courte" \
    "Resume du livre" \
    "Francais" \
    "Auteur Test" \
    "Editeur Test" \
    "2020" \
    "Litterature" \
    "200" \
    "Moyen" \
    "100" \
    "https://example.com/image.jpg" \
    "" \
    "" \
    "" \
    "Bon etat" \
    "EXP" \
    "0612345678" \
    "75001" \
    "France" >> "$output"

echo "✅ Export créé : $output"
echo ""
echo "📊 VÉRIFICATION :"
echo "────────────────"
echo "Lignes : $(wc -l < "$output")"
echo "Colonnes : $(tail -1 "$output" | awk -F'\t' '{print NF}')"
echo ""

# Vérifier chaque colonne
echo "🔍 CONTENU DE CHAQUE COLONNE :"
echo "─────────────────────────────"
tail -1 "$output" | awk -F'\t' '{
    for(i=1; i<=NF; i++) {
        printf "Col %2d: [%s]\n", i, $i
    }
}'

echo ""
echo "✅ Aucun caractère spécial, aucun accent, aucune apostrophe"
echo "🚀 Ce fichier devrait passer sans problème !"
