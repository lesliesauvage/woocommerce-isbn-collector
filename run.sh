#!/bin/bash
# Script de lancement principal pour la collecte ISBN

# Charger la configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"  # Fonctions sécurisées

echo "=== SYSTÈME DE COLLECTE ISBN ==="
echo "================================"
echo ""
echo "Mode de collecte :"
echo "  1) Test avec 3 livres (16091, 16089, 16087)"
echo "  2) Collecter TOUS les livres sans données"
echo "  3) Collecter UN livre spécifique (par ID ou ISBN)"
echo "  4) AJOUTER un nouveau livre par ISBN"
echo ""
echo "Fiches et rapports :"
echo "  5) Créer des fiches complètes (martingale)"
echo "  6) Générer un rapport des données"
echo "  7) Afficher les données d'un livre"
echo ""
echo "Tests et maintenance :"
echo "  8) Tester toutes les APIs"
echo "  9) Tester Groq IA"
echo " 10) Nettoyer les doublons dans la base"
echo " 11) Effacer les données d'un livre"
echo ""
echo "  0) Quitter"
echo ""
read -p "Votre choix (0-11) : " choice

case $choice in
    1)
        echo ""
        echo "=== TEST AVEC 3 LIVRES ==="
        echo "Livres de test : 16091, 16089, 16087"
        echo ""
        
        # Créer une version temporaire qui ne traite que ces 3 livres
        cp collect_api_data.sh generer_collect_test_3books.sh
        sed -i 's/# query="$query AND p.ID IN (16091, 16089, 16087)"/query="$query AND p.ID IN (16091, 16089, 16087)"/' generer_collect_test_3books.sh
        
        # Option pour effacer d'abord les données existantes
        read -p "Effacer les données existantes de ces 3 livres ? (o/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Oo]$ ]]; then
            echo "Suppression des données existantes..."
            mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id IN (16091, 16089, 16087) AND meta_key LIKE '_g_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id IN (16091, 16089, 16087) AND meta_key LIKE '_i_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id IN (16091, 16089, 16087) AND meta_key LIKE '_o_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id IN (16091, 16089, 16087) AND meta_key LIKE '_best_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id IN (16091, 16089, 16087) AND meta_key LIKE '_calculated_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id IN (16091, 16089, 16087) AND meta_key LIKE '_groq_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id IN (16091, 16089, 16087) AND meta_key LIKE '_api_%';
EOF
            echo "Données supprimées."
        fi
        
        echo ""
        echo "Lancement de la collecte pour 3 livres..."
        ./generer_collect_test_3books.sh
        
        # Nettoyer
        rm -f generer_collect_test_3books.sh
        ;;
        
    2)
        echo ""
        echo "=== COLLECTE DE TOUS LES LIVRES ==="
        read -p "Êtes-vous sûr de vouloir traiter TOUS les livres ? (o/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Oo]$ ]]; then
            ./collect_api_data.sh
        else
            echo "Annulé."
        fi
        ;;
        
    3)
        echo ""
        echo "=== COLLECTE D'UN LIVRE SPÉCIFIQUE ==="
        echo "Vous pouvez entrer soit :"
        echo "  - L'ID du produit (ex: 16091)"
        echo "  - L'ISBN du livre (ex: 2857070063 ou 978-2857070061)"
        echo ""
        read -p "Entrez l'ID ou l'ISBN : " input
        
        # Nettoyer l'input (enlever les tirets)
        input=$(echo "$input" | tr -d '-')
        
        # Déterminer si c'est un ID ou un ISBN
        if [[ "$input" =~ ^[0-9]{1,6}$ ]]; then
            # C'est probablement un ID de produit
            product_id="$input"
            
            # Vérifier que le livre existe
            isbn=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT meta_value FROM wp_${SITE_ID}_postmeta 
                WHERE post_id = $product_id AND meta_key = '_isbn' LIMIT 1;
            ")
            
            if [ -z "$isbn" ]; then
                echo "Aucun livre trouvé avec l'ID $product_id"
                exit 1
            fi
            
        elif [[ "$input" =~ ^[0-9]{10}$ ]] || [[ "$input" =~ ^[0-9]{13}$ ]]; then
            # C'est un ISBN
            isbn="$input"
            
            # Trouver l'ID du produit correspondant
            product_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key = '_isbn' AND meta_value = '$isbn' LIMIT 1;
            ")
            
            if [ -z "$product_id" ]; then
                echo "Aucun livre trouvé avec l'ISBN $isbn"
                exit 1
            fi
            
        else
            echo "Format invalide. Entrez un ID de produit ou un ISBN valide."
            exit 1
        fi
        
        echo ""
        echo "Livre trouvé :"
        echo "  - ID produit : #$product_id"
        echo "  - ISBN : $isbn"
        
        # Afficher le titre si disponible
        title=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT post_title FROM wp_${SITE_ID}_posts WHERE ID = $product_id LIMIT 1;
        ")
        if [ ! -z "$title" ]; then
            echo "  - Titre : $title"
        fi
        
        echo ""
        
        # Option pour effacer d'abord
        read -p "Effacer les données existantes ? (o/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Oo]$ ]]; then
            mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id = $product_id AND meta_key LIKE '_g_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id = $product_id AND meta_key LIKE '_i_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id = $product_id AND meta_key LIKE '_o_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id = $product_id AND meta_key LIKE '_best_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id = $product_id AND meta_key LIKE '_calculated_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id = $product_id AND meta_key LIKE '_groq_%';
DELETE FROM wp_${SITE_ID}_postmeta WHERE post_id = $product_id AND meta_key LIKE '_api_%';
EOF
            echo "Données supprimées."
        fi
        
        # Créer une version temporaire pour ce livre
        cp collect_api_data.sh generer_collect_single_book.sh
        sed -i "s/# query=\"\$query AND p.ID IN (16091, 16089, 16087)\"/query=\"\$query AND p.ID = $product_id\"/" generer_collect_single_book.sh
        
        echo ""
        echo "Lancement de la collecte..."
        ./generer_collect_single_book.sh
        rm -f generer_collect_single_book.sh
        ;;
        
    4)
        echo ""
        echo "=== AJOUTER UN NOUVEAU LIVRE PAR ISBN ==="
        
        # Demander l'ISBN
        read -p "Entrez l'ISBN du nouveau livre : " isbn
        
        # Nettoyer l'ISBN (enlever les tirets)
        isbn=$(echo "$isbn" | tr -d '-')
        
        # Vérifier le format
        if [[ ! "$isbn" =~ ^[0-9]{10}$ ]] && [[ ! "$isbn" =~ ^[0-9]{13}$ ]]; then
            echo "Format d'ISBN invalide"
            exit 1
        fi
        
        # Vérifier qu'il n'existe pas déjà
        existing=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT post_id FROM wp_28_postmeta 
            WHERE meta_key = '_isbn' AND meta_value = '$isbn' LIMIT 1;
        ")
        
        if [ ! -z "$existing" ]; then
            echo "Ce livre existe déjà avec l'ID : $existing"
            read -p "Voulez-vous lancer la collecte pour ce livre ? (o/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Oo]$ ]]; then
                # Créer une version temporaire pour ce livre
                cp collect_api_data.sh generer_collect_single_book.sh
                sed -i "s/# query=\"\$query AND p.ID IN (16091, 16089, 16087)\"/query=\"\$query AND p.ID = $existing\"/" generer_collect_single_book.sh
                ./generer_collect_single_book.sh
                rm -f generer_collect_single_book.sh
            fi
            exit 0
        fi
        
        echo ""
        echo "ISBN : $isbn"
        echo "Recherche des informations de base..."
        
        # Appeler Google Books pour avoir un titre
        source "$SCRIPT_DIR/apis/google_books.sh"
        google_data=$(fetch_google_books "$isbn")
        
        if [ ! -z "$google_data" ]; then
            title=$(echo "$google_data" | grep -oP 'title:[^|]+' | cut -d':' -f2)
            if [ -z "$title" ]; then
                title="Livre ISBN $isbn"
            fi
        else
            title="Livre ISBN $isbn"
        fi
        
        echo "Titre trouvé : $title"
        
        # Créer le produit
        echo ""
        echo "Création du produit dans WordPress..."
        
        # Échapper le titre pour MySQL (remplacer les apostrophes)
        title_escaped=$(echo "$title" | sed "s/'/\\\\'/g")
        
        # Générer un slug unique (sans apostrophes ni caractères spéciaux)
        slug=$(echo "$title" | sed "s/'//g" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-')
        slug="${slug}-${isbn}"
        
        # Date actuelle
        current_date=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Insérer le produit avec le titre échappé
        result=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
INSERT INTO wp_28_posts (
    post_author, post_date, post_date_gmt, post_content, post_title,
    post_excerpt, post_status, comment_status, ping_status, post_name,
    post_modified, post_modified_gmt, post_parent, menu_order, post_type
) VALUES (
    1, '$current_date', '$current_date', '', '$title_escaped',
    '', 'publish', 'open', 'closed', '$slug',
    '$current_date', '$current_date', 0, 0, 'product'
);
SELECT LAST_INSERT_ID();
EOF
)
        
        # Récupérer l'ID (dernière ligne du résultat)
        product_id=$(echo "$result" | tail -1)
        
        if [ -z "$product_id" ] || [ "$product_id" = "0" ]; then
            echo "Erreur lors de la création du produit"
            echo "Tentative avec titre simplifié..."
            
            # Réessayer avec un titre simple sans caractères spéciaux
            result=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
INSERT INTO wp_28_posts (
    post_author, post_date, post_date_gmt, post_content, post_title,
    post_excerpt, post_status, comment_status, ping_status, post_name,
    post_modified, post_modified_gmt, post_parent, menu_order, post_type
) VALUES (
    1, '$current_date', '$current_date', '', 'Livre $isbn',
    '', 'publish', 'open', 'closed', 'livre-$isbn',
    '$current_date', '$current_date', 0, 0, 'product'
);
SELECT LAST_INSERT_ID();
EOF
)
            product_id=$(echo "$result" | tail -1)
            
            if [ -z "$product_id" ] || [ "$product_id" = "0" ]; then
                echo "Impossible de créer le produit"
                exit 1
            fi
        fi
        
        echo "✓ Produit créé avec l'ID : $product_id"
        
        # Ajouter les métadonnées
        echo "Ajout des métadonnées..."
        
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
INSERT INTO wp_28_postmeta (post_id, meta_key, meta_value) VALUES 
($product_id, '_isbn', '$isbn'),
($product_id, '_sku', '$isbn'),
($product_id, '_price', '0'),
($product_id, '_regular_price', '0'),
($product_id, '_stock_status', 'instock'),
($product_id, '_manage_stock', 'no'),
($product_id, '_virtual', 'no'),
($product_id, '_downloadable', 'no');
EOF
        
        echo "✓ Métadonnées ajoutées"
        
        # Lancer la collecte
        echo ""
        echo "Lancement de la collecte de données..."
        
        # Créer une version temporaire pour ce livre
        cp collect_api_data.sh generer_collect_single_book.sh
        sed -i "s/# query=\"\$query AND p.ID IN (16091, 16089, 16087)\"/query=\"\$query AND p.ID = $product_id\"/" generer_collect_single_book.sh
        
        ./generer_collect_single_book.sh
        rm -f generer_collect_single_book.sh
        
        echo ""
        echo "✓ Livre ajouté et données collectées !"
        ;;
        
    5)
        echo ""
        echo "=== CRÉATION DE FICHES COMPLÈTES ==="
        ./martingale.sh
        ;;
        
    6)
        echo ""
        echo "=== GÉNÉRATION DU RAPPORT ==="
        ./generate_report.sh
        ;;
        
    7)
        echo ""
        echo "=== AFFICHER LES DONNÉES D'UN LIVRE ==="
        echo "Vous pouvez entrer soit :"
        echo "  - L'ID du produit (ex: 16091)"
        echo "  - L'ISBN du livre (ex: 2857070063 ou 978-2857070061)"
        echo ""
        read -p "Entrez l'ID ou l'ISBN : " input
        
        # Nettoyer l'input (enlever les tirets)
        input=$(echo "$input" | tr -d '-')
        
        # Déterminer si c'est un ID ou un ISBN
        if [[ "$input" =~ ^[0-9]{1,6}$ ]]; then
            # C'est probablement un ID de produit
            product_id="$input"
        elif [[ "$input" =~ ^[0-9]{10}$ ]] || [[ "$input" =~ ^[0-9]{13}$ ]]; then
            # C'est un ISBN - trouver l'ID correspondant
            product_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key = '_isbn' AND meta_value = '$input' LIMIT 1;
            ")
            
            if [ -z "$product_id" ]; then
                echo "Aucun livre trouvé avec l'ISBN $input"
                exit 1
            fi
        else
            echo "Format invalide"
            exit 1
        fi
        
        # Afficher toutes les données
        echo ""
        echo "Données pour le produit #$product_id :"
        echo "======================================"
        
        mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            SELECT meta_key, LEFT(meta_value, 100) as value 
            FROM wp_${SITE_ID}_postmeta 
            WHERE post_id = $product_id 
            AND (meta_key LIKE '_g_%' OR meta_key LIKE '_i_%' OR meta_key LIKE '_o_%' OR meta_key LIKE '_best_%' OR meta_key LIKE '_calculated_%' OR meta_key LIKE '_groq_%' OR meta_key = '_isbn')
            ORDER BY meta_key;
        "
        ;;
        
    8)
        echo ""
        echo "=== TEST DES APIs ==="
        ./test_apis.sh
        ;;
        
    9)
        echo ""
        echo "=== TEST DE GROQ IA ==="
        ./test_groq.sh
        ;;
        
    10)
        echo ""
        echo "=== NETTOYAGE DES DOUBLONS ==="
        echo "Cette opération va supprimer tous les doublons dans la base de données."
        read -p "Continuer ? (o/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Oo]$ ]]; then
            echo "Nettoyage en cours..."
            
            # Script SQL pour nettoyer les doublons
            mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << 'EOF'
-- Créer une table temporaire avec les données uniques
CREATE TEMPORARY TABLE temp_unique AS
SELECT MIN(meta_id) as keep_id, post_id, meta_key, meta_value
FROM wp_28_postmeta
WHERE meta_key LIKE '_g_%' OR meta_key LIKE '_i_%' OR meta_key LIKE '_o_%' OR meta_key LIKE '_best_%' OR meta_key LIKE '_calculated_%' OR meta_key LIKE '_groq_%'
GROUP BY post_id, meta_key, meta_value;

-- Supprimer tous les doublons sauf le premier
DELETE pm FROM wp_28_postmeta pm
LEFT JOIN temp_unique tu ON pm.meta_id = tu.keep_id
WHERE pm.meta_key LIKE '_g_%' OR pm.meta_key LIKE '_i_%' OR pm.meta_key LIKE '_o_%' OR pm.meta_key LIKE '_best_%' OR pm.meta_key LIKE '_calculated_%' OR pm.meta_key LIKE '_groq_%'
AND tu.keep_id IS NULL;

-- Afficher le nombre de doublons supprimés
SELECT ROW_COUNT() as 'Doublons supprimés';
EOF
            echo "Nettoyage terminé !"
        fi
        ;;
        
    11)
        echo ""
        echo "=== EFFACER LES DONNÉES D'UN LIVRE ==="
        echo "Vous pouvez entrer soit :"
        echo "  - L'ID du produit (ex: 16091)"
        echo "  - L'ISBN du livre (ex: 2857070063 ou 978-2857070061)"
        echo ""
        read -p "Entrez l'ID ou l'ISBN : " input
        
        # Nettoyer l'input (enlever les tirets)
        input=$(echo "$input" | tr -d '-')
        
        # Déterminer si c'est un ID ou un ISBN
        if [[ "$input" =~ ^[0-9]{1,6}$ ]]; then
            product_id="$input"
        elif [[ "$input" =~ ^[0-9]{10}$ ]] || [[ "$input" =~ ^[0-9]{13}$ ]]; then
            # C'est un ISBN - trouver l'ID correspondant
            product_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key = '_isbn' AND meta_value = '$input' LIMIT 1;
            ")
            
            if [ -z "$product_id" ]; then
                echo "Aucun livre trouvé avec l'ISBN $input"
                exit 1
            fi
        else
            echo "Format invalide"
            exit 1
        fi
        
        echo "Cette opération va supprimer toutes les données API pour le produit #$product_id"
        read -p "Confirmer ? (o/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Oo]$ ]]; then
            mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" << EOF
DELETE FROM wp_${SITE_ID}_postmeta 
WHERE post_id = $product_id 
AND (meta_key LIKE '_g_%' OR meta_key LIKE '_i_%' OR meta_key LIKE '_o_%' OR meta_key LIKE '_best_%' OR meta_key LIKE '_calculated_%' OR meta_key LIKE '_groq_%' OR meta_key LIKE '_api_%');
EOF
            echo "Données supprimées pour le produit #$product_id"
        fi
        ;;
        
    0)
        echo "Au revoir !"
        exit 0
        ;;
        
    *)
        echo "Choix invalide"
        exit 1
        ;;
esac

echo ""
read -p "Appuyez sur Entrée pour continuer..."
