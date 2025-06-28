#!/bin/bash
# Script pour migrer les données de l'ancien système vers le nouveau

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/database.sh"

echo "=== Migration des données existantes ==="
echo ""

# Vérifier si des données existent déjà
existing_count=$(mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -sN -e "
    SELECT COUNT(DISTINCT post_id) 
    FROM wp_${SITE_ID}_postmeta 
    WHERE meta_key LIKE '_%' 
    AND meta_key NOT LIKE '_wp_%'
    AND meta_key NOT LIKE '_edit_%'
    AND meta_key NOT LIKE '_sku'
    AND meta_key NOT LIKE '_price'
    AND meta_key NOT LIKE '_stock%';")

echo "Nombre de produits avec données API : $existing_count"

if [ "$existing_count" -gt 0 ]; then
    echo ""
    echo "Des données existent déjà. Voulez-vous :"
    echo "1) Garder les données existantes"
    echo "2) Supprimer et recollecte (ATTENTION: supprime TOUTES les données API)"
    echo "3) Annuler"
    read -p "Votre choix (1/2/3) : " choice
    
    case $choice in
        1)
            echo "Les données existantes seront conservées."
            ;;
        2)
            echo "Suppression des données API existantes..."
            mysql --default-character-set=utf8mb4 -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "
                DELETE FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key LIKE '_%' 
                AND meta_key NOT LIKE '_wp_%'
                AND meta_key NOT LIKE '_edit_%'
                AND meta_key NOT LIKE '_sku'
                AND meta_key NOT LIKE '_price'
                AND meta_key NOT LIKE '_stock%'
                AND post_id IN (
                    SELECT ID FROM wp_${SITE_ID}_posts 
                    WHERE post_type = 'product'
                );"
            echo "Données supprimées."
            ;;
        3)
            echo "Migration annulée."
            exit 0
            ;;
    esac
fi

echo ""
echo "Migration terminée."
echo "Vous pouvez maintenant lancer : ./collect_api_data_v2.sh"
