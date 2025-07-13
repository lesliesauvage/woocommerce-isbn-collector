#!/bin/bash
source config/settings.sh

# Fonction de nettoyage complète des caractères Microsoft et retours ligne
clean_rakuten_text() {
    echo "$1" | \
    sed "s/'/ /g" | \
    sed "s/'/ /g" | \
    sed 's/"/ /g' | \
    sed 's/"/ /g' | \
    sed 's/«/ /g' | \
    sed 's/»/ /g' | \
    sed 's/…/.../g' | \
    sed 's/—/-/g' | \
    sed 's/–/-/g' | \
    sed 's/\r\n/<br \/>/g' | \
    sed 's/\n/<br \/>/g' | \
    sed 's/\r/<br \/>/g' | \
    sed 's/;/,/g' | \
    sed 's/  */ /g' | \
    sed 's/^ *//;s/ *$//'
}

# Fonction de mapping des catégories WordPress vers Rakuten
map_to_rakuten_category() {
    local category_path="$1"
    local mapping_file="config/rakuten_category_mapping.csv"
    
    if [ -f "$mapping_file" ]; then
        local mapped=$(grep -F "\"$category_path\"," "$mapping_file" | head -1 | cut -d',' -f2 | tr -d '"')
        if [ -n "$mapped" ]; then
            echo "$mapped"
            return
        fi
        
        local last_level=$(echo "$category_path" | rev | cut -d'>' -f1 | rev | xargs)
        mapped=$(grep -i "$last_level" "$mapping_file" | head -1 | cut -d',' -f2 | tr -d '"')
        if [ -n "$mapped" ]; then
            echo "$mapped"
            return
        fi
        
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
    
    echo "Littérature française"
}

# Fonction d'analyse du CSV généré
analyze_csv() {
    local file="$1"
    local errors=0
    local warnings=0
    
    echo ""
    echo "🔍 ANALYSE DU FICHIER GÉNÉRÉ"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    
    # VÉRIFIER L'ENCODAGE
    echo "📋 STRUCTURE :"
    echo "─────────────"
    encoding=$(file -bi "$file" | cut -d'=' -f2)
    if [[ "$encoding" =~ "utf-16" ]] || [[ "$encoding" =~ "UTF-16" ]]; then
        echo "✅ Encodage : UTF-16"
    else
        echo "⚠️  Encodage : $encoding (UTF-16 recommandé)"
        ((warnings++))
    fi
    
    # Convertir temporairement en UTF-8 pour l'analyse
    temp_file="/tmp/rakuten_temp_$$.csv"
    iconv -f UTF-16LE -t UTF-8 "$file" > "$temp_file" 2>/dev/null || cp "$file" "$temp_file"
    
    # COMPTER LES COLONNES
    header_cols=$(head -1 "$temp_file" | awk -F';' '{print NF}')
    data_cols=$(tail -1 "$temp_file" | awk -F';' '{print NF}')
    
    if [ "$header_cols" -eq 29 ] && [ "$data_cols" -eq 29 ]; then
        echo "✅ Nombre de colonnes : 29"
    else
        echo "❌ Nombre de colonnes : en-tête=$header_cols, données=$data_cols (29 attendues)"
        ((errors++))
    fi
    
    # VÉRIFIER LES RETOURS LIGNE
    line_count=$(wc -l < "$temp_file")
    if [ "$line_count" -ne 2 ]; then
        echo "❌ Fichier contient $line_count lignes (2 attendues)"
        ((errors++))
    else
        echo "✅ Structure : 2 lignes (en-tête + données)"
    fi
    
    echo ""
    echo "📊 DONNÉES OBLIGATOIRES :"
    echo "────────────────────────"
    
    # Lire la ligne de données
    data_line=$(tail -1 "$temp_file")
    IFS=';' read -r -a cols <<< "$data_line"
    
    # VÉRIFICATIONS DÉTAILLÉES
    checks=(
        "1:ISBN:^[0-9]{10,13}$"
        "3:Prix:^[0-9]+(\.[0-9]{1,2})?$"
        "5:Qualité:^(N|CN|TBE|BE|EC)$"
        "6:Quantité:^[1-9][0-9]{0,2}$"
        "10:Titre:.+"
        "13:Langue:^Français$"
        "14:Auteurs:.+"
        "15:Éditeur:.+"
        "17:Classification:.+"
        "18:Poids:^[0-9]+$"
        "19:Taille:^(Petit|Moyen|Grand)$"
    )
    
    for check in "${checks[@]}"; do
        IFS=':' read -r col_num col_name pattern <<< "$check"
        value="${cols[$((col_num-1))]}"
        
        if [[ "$value" =~ $pattern ]]; then
            if [ ${#value} -gt 30 ]; then
                echo "✅ Col $col_num - $col_name : ${value:0:30}..."
            else
                echo "✅ Col $col_num - $col_name : $value"
            fi
        else
            echo "❌ Col $col_num - $col_name : '$value' (invalide)"
            ((errors++))
        fi
    done
    
    # VÉRIFIER L'IMAGE
    image="${cols[20]}"
    if [ -z "$image" ]; then
        echo "⚠️  Col 21 - Image : vide"
        ((warnings++))
    elif [[ ! "$image" =~ ^https:// ]]; then
        echo "❌ Col 21 - Image : doit commencer par https://"
        ((errors++))
    else
        echo "✅ Col 21 - Image : ${image:0:30}..."
    fi
    
    echo ""
    echo "🔤 CARACTÈRES INTERDITS :"
    echo "───────────────────────"
    
    # Vérifier les caractères Microsoft
    bad_chars=0
    for char in ''' ''' '"' '"' '«' '»' '…' '—' '–'; do
        if grep -F "$char" "$temp_file" > /dev/null 2>&1; then
            echo "❌ Caractère interdit trouvé : $char"
            ((bad_chars++))
        fi
    done
    
    if [ $bad_chars -eq 0 ]; then
        echo "✅ Aucun caractère Microsoft détecté"
    else
        ((errors++))
    fi
    
    rm -f "$temp_file"
    
    # RÉSULTAT
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "📝 RÉSULTAT DE L'ANALYSE :"
    
    if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
        echo "✅ FICHIER PARFAIT - Prêt pour Rakuten !"
        return 0
    elif [ $errors -eq 0 ]; then
        echo "⚠️  $warnings avertissement(s) - Fichier utilisable"
        return 0
    else
        echo "❌ $errors erreur(s) à corriger"
        return 1
    fi
}

# DÉBUT DU SCRIPT PRINCIPAL
isbn="${1:-9782070360024}"
output="rakuten_${isbn}_$(date +%Y%m%d_%H%M%S).csv"

echo "📤 EXPORT RAKUTEN COMPLET - ISBN: $isbn"
echo "════════════════════════════════════════════════════════════════"
echo ""

# RÉCUPÉRER TOUTES LES DONNÉES AVEC HIÉRARCHIE DES CATÉGORIES
echo "📊 Récupération des données..."
all_data=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
WITH RECURSIVE CategoryPath AS (
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
    CAST(IFNULL(pm_price.meta_value, '0') AS DECIMAL(10,2)) as prix,
    CAST(IFNULL(pm_regular.meta_value, pm_price.meta_value) AS DECIMAL(10,2)) as prix_public,
    IFNULL(pm_condition.meta_value, 'bon') as condition_livre,
    CAST(IFNULL(pm_stock.meta_value, '1') AS UNSIGNED) as stock,
    IFNULL(pm_desc.meta_value, '') as description,
    IFNULL(pm_authors.meta_value, '') as auteurs,
    IFNULL(pm_publisher.meta_value, '') as editeur,
    IFNULL(pm_date.meta_value, '') as date_parution,
    CAST(IFNULL(pm_weight.meta_value, '200') AS UNSIGNED) as poids,
    IFNULL(pm_binding.meta_value, '') as binding,
    CAST(IFNULL(pm_pages.meta_value, '0') AS UNSIGNED) as pages,
    IFNULL(pm_image.meta_value, '') as image,
    (SELECT path FROM CategoryPath ORDER BY level DESC LIMIT 1) as wp_category,
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
IFS=$'\t' read -r isbn titre prix prix_public condition stock description auteurs editeur date_parution poids binding pages image wp_category post_id <<< "$all_data"

# VÉRIFICATIONS DES DONNÉES OBLIGATOIRES
echo "🔍 Vérification des données obligatoires..."
errors=0

if [ -z "$isbn" ]; then
    echo "❌ ISBN manquant"
    ((errors++))
fi

if [ -z "$titre" ]; then
    echo "❌ Titre manquant"
    ((errors++))
fi

if [ -z "$prix" ] || [ "$prix" = "0" ] || [ "$prix" = "0.00" ]; then
    echo "❌ Prix invalide ou manquant"
    ((errors++))
fi

if [ -z "$auteurs" ]; then
    echo "❌ Auteurs manquants"
    ((errors++))
fi

if [ -z "$editeur" ]; then
    echo "❌ Éditeur manquant"
    ((errors++))
fi

if [ $errors -gt 0 ]; then
    echo ""
    echo "🛑 EXPORT ANNULÉ : $errors champ(s) obligatoire(s) manquant(s)"
    echo "💡 Lancez d'abord : ./isbn_unified.sh $isbn"
    exit 1
fi

echo "✅ Toutes les données obligatoires sont présentes"
echo ""

# Mapper la catégorie WordPress vers Rakuten
rakuten_category=$(map_to_rakuten_category "$wp_category")
echo "📁 Catégorie WordPress : $wp_category"
echo "📁 Classification Rakuten : $rakuten_category"
echo ""

# Nettoyer toutes les variables
titre=$(clean_rakuten_text "$titre")
description=$(clean_rakuten_text "$description")
auteurs=$(clean_rakuten_text "$auteurs")
editeur=$(clean_rakuten_text "$editeur")
commentaire=$(clean_rakuten_text "Envoi rapide et soigné. Livre en $condition état.")
rakuten_category=$(clean_rakuten_text "$rakuten_category")

# Mapper la condition
case "$condition" in
    "neuf") qualite="N" ;;
    "comme neuf") qualite="CN" ;;
    "très bon") qualite="TBE" ;;
    "bon") qualite="BE" ;;
    *) qualite="BE" ;;
esac

# Mapper la taille selon le binding
case "$binding" in
    *"poche"*) taille="Petit" ;;
    *"grand"*) taille="Grand" ;;
    *) taille="Moyen" ;;
esac

# Corriger l'URL de l'image (forcer https)
if [[ "$image" =~ ^http:// ]]; then
    image="${image/http:/https:}"
fi

# Description courte (200 caractères max)
description_courte="${description:0:200}"

# GÉNÉRER LE FICHIER CSV
echo "📝 Génération du fichier CSV..."
{
# En-tête (29 colonnes)
echo "EAN / ISBN / Code produit;Référence unique de l annonce * / Unique Advert Refence (SKU) *;Prix de vente * / Selling Price *;Prix d origine / RRP in euros;Qualité * / Condition *;Quantité * / Quantity *;Commentaire de l annonce * / Advert comment *;Commentaire privé de l annonce / Private Advert Comment;Type de Produit * / Type of Product *;Titre * / Title *;Description courte * / Short Description *;Résumé du Livre ou Revue;Langue;Auteurs;Editeur;Date de parution;Classification Thématique;Poids en grammes / Weight in grammes;Taille / Size;Nombre de Pages / Number of pages;URL Image principale * / Main picture *;URLs Images Secondaires / Secondary Picture;Code opération promo / Promotion code;Colonne vide / void column;Description Annonce Personnalisée;Expédition, Retrait / Shipping, Pick Up;Téléphone / Phone number;Code postale / Zip Code;Pays / Country"

# Données (29 colonnes) - SANS HTML
echo -n "$isbn;"                    # 1
echo -n "$isbn;"                    # 2
echo -n "$prix;"                    # 3
echo -n "$prix_public;"             # 4
echo -n "$qualite;"                 # 5
echo -n "$stock;"                   # 6
echo -n "$commentaire;"             # 7
echo -n ";"                         # 8
echo -n "Livre;"                    # 9
echo -n "$titre;"                   # 10
echo -n "$description_courte;"      # 11
echo -n "$description;"             # 12
echo -n "Français;"                 # 13
echo -n "$auteurs;"                 # 14
echo -n "$editeur;"                 # 15
echo -n "$date_parution;"           # 16
echo -n "$rakuten_category;"        # 17
echo -n "$poids;"                   # 18
echo -n "$taille;"                  # 19
echo -n "$pages;"                   # 20
echo -n "$image;"                   # 21
echo -n ";"                         # 22
echo -n ";"                         # 23
echo -n ";"                         # 24
echo -n ";"                         # 25 (pas de HTML)
echo -n "EXP / RET;"               # 26
echo -n "0668563512;"              # 27
echo -n "76000;"                   # 28
echo "France"                       # 29
} > "${output}.tmp"

# Convertir en UTF-16LE (recommandé par Rakuten)
iconv -f UTF-8 -t UTF-16LE "${output}.tmp" > "$output"
rm -f "${output}.tmp"

echo ""
echo "✅ Export créé : $output"
echo ""
echo "📋 INFORMATIONS DU FICHIER :"
echo "────────────────────────────"
echo "Format : CSV avec point-virgule"
echo "Encodage : UTF-16LE (recommandé)"
echo "Colonnes : 29"
echo "Titre : $titre"
echo "Prix : $prix €"
echo "Classification : $rakuten_category"

# LANCER L'ANALYSE AUTOMATIQUEMENT
if analyze_csv "$output"; then
    echo ""
    echo "🚀 FICHIER PRÊT POUR UPLOAD SUR RAKUTEN !"
else
    echo ""
    echo "⚠️  Corrigez les erreurs avant upload"
fi
