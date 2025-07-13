#!/bin/bash

file="${1}"

if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo "❌ Usage : $0 <fichier.csv>"
    exit 1
fi

echo "🔍 ANALYSE RAKUTEN CSV : $file"
echo "════════════════════════════════════════════════════════════════"
echo ""

errors=0
warnings=0

# 1. VÉRIFIER L'ENCODAGE
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

# 2. COMPTER LES COLONNES
header_cols=$(head -1 "$temp_file" | awk -F';' '{print NF}')
data_cols=$(tail -1 "$temp_file" | awk -F';' '{print NF}')

if [ "$header_cols" -eq 29 ] && [ "$data_cols" -eq 29 ]; then
    echo "✅ Nombre de colonnes : 29"
else
    echo "❌ Nombre de colonnes : en-tête=$header_cols, données=$data_cols (29 attendues)"
    ((errors++))
fi

# 3. VÉRIFIER LES RETOURS LIGNE
line_count=$(wc -l < "$temp_file")
if [ "$line_count" -ne 2 ]; then
    echo "❌ Fichier contient $line_count lignes (2 attendues : en-tête + données)"
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

# Afficher le nombre de colonnes trouvées
echo "   Colonnes détectées : ${#cols[@]}"
echo ""

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

# Vérifier les retours ligne non convertis
if grep -P "[\r\n]" "$temp_file" | grep -v "<br />" > /dev/null 2>&1; then
    echo "⚠️  Retours ligne possibles (vérifiez <br />)"
    ((warnings++))
else
    echo "✅ Retours ligne correctement gérés"
fi

# Nettoyer
rm -f "$temp_file"

# RÉSULTAT FINAL
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "📝 RÉSULTAT :"

if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
    echo "✅ FICHIER PARFAIT - Prêt pour Rakuten !"
    echo ""
    echo "🚀 Uploadez maintenant sur Rakuten"
elif [ $errors -eq 0 ]; then
    echo "⚠️  $warnings avertissement(s) - Fichier utilisable"
    echo ""
    echo "📤 Peut être uploadé sur Rakuten"
else
    echo "❌ $errors erreur(s) à corriger"
    echo ""
    echo "🔧 Corrigez les erreurs avant upload"
fi

echo ""
echo "💡 Pour ouvrir dans Excel : utilisez l'import avec ';' comme séparateur"
