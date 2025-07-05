#!/bin/bash
# ⚠️  FICHIER CRITIQUE - NE JAMAIS SUPPRIMER ⚠️
# Ce fichier utilise l'IA Groq pour catégoriser automatiquement les livres
# Il est ESSENTIEL au fonctionnement du projet
# smart_categorize.sh - Catégorisation intelligente des livres avec Groq

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config/settings.sh"
source "$SCRIPT_DIR/lib/safe_functions.sh"

# Fonction pour afficher l'aide
show_help() {
    cat << EOF
=== SMART CATEGORIZE - Catégorisation IA avec Groq ===

USAGE:
    ./smart_categorize.sh                    # Mode interactif
    ./smart_categorize.sh ISBN               # Catégoriser par ISBN
    ./smart_categorize.sh -id ID             # Catégoriser par ID produit
    ./smart_categorize.sh -all               # Catégoriser TOUS les livres non catégorisés
    ./smart_categorize.sh -batch N           # Catégoriser N livres non catégorisés
    ./smart_categorize.sh -search "terme"    # Rechercher et catégoriser
    ./smart_categorize.sh -test ISBN         # Tester sans sauvegarder

EXEMPLES:
    ./smart_categorize.sh 9782070360024
    ./smart_categorize.sh -id 16127
    ./smart_categorize.sh -batch 10
    ./smart_categorize.sh -search "Camus"

EOF
}

# Fonction pour obtenir les catégories disponibles
get_available_categories() {
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT t.term_id, t.name 
    FROM wp_${SITE_ID}_terms t
    JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
    WHERE tt.taxonomy = 'product_cat'
    AND t.term_id NOT IN (15, 16)
    ORDER BY t.name
    " 2>/dev/null
}

# Fonction pour catégoriser avec Groq
categorize_with_groq() {
    local title="$1"
    local authors="$2"
    local description="$3"
    local current_categories="$4"
    
    # Nettoyer et tronquer la description
    description=$(echo "$description" | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-500)
    
    # Obtenir toutes les catégories
    local categories_list=""
    while IFS=$'\t' read -r cat_id cat_name; do
        categories_list="${categories_list}ID: $cat_id - $cat_name\n"
    done < <(get_available_categories)
    
    # Prompt pour Groq
    local prompt="Tu es un expert en catégorisation de livres. Analyse ce livre et choisis la catégorie la plus appropriée.

LIVRE À ANALYSER:
- Titre: $title
- Auteurs: $authors
- Description: $description
- Catégories actuelles: $current_categories

CATÉGORIES DISPONIBLES:
$categories_list

INSTRUCTIONS:
1. Analyse le contenu du livre (titre, auteur, description)
2. Choisis LA catégorie la plus pertinente parmi la liste
3. Réponds UNIQUEMENT avec l'ID de la catégorie (nombre seul)
4. Si aucune catégorie ne convient, réponds 0

Réponds avec l'ID de catégorie uniquement:"

    # Échapper le prompt pour JSON
    prompt_escaped=$(echo "$prompt" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    # Appel à Groq
    local response=$(curl -s -X POST "$GROQ_API_URL" \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"$GROQ_MODEL\",
            \"messages\": [
                {
                    \"role\": \"system\",
                    \"content\": \"Tu es un assistant de catégorisation de livres. Tu réponds UNIQUEMENT avec des ID numériques.\"
                },
                {
                    \"role\": \"user\",
                    \"content\": \"$prompt_escaped\"
                }
            ],
            \"temperature\": 0.3,
            \"max_tokens\": 10
        }" 2>/dev/null)
    
    # Extraire la réponse
    local category_id=$(echo "$response" | grep -o '"content":"[^"]*"' | sed 's/"content":"//;s/"//' | grep -o '[0-9]*' | head -1)
    
    # Débugger si nécessaire
    if [ "$DEBUG" = "1" ]; then
        echo "[DEBUG] Réponse Groq: $response" >&2
        echo "[DEBUG] ID extrait: $category_id" >&2
    fi
    
    echo "${category_id:-0}"
}

# Fonction pour afficher les informations d'un livre
display_book_info() {
    local post_id="$1"
    
    # Récupérer les infos
    local book_info=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT 
        p.ID,
        p.post_title,
        IFNULL(pm_isbn.meta_value, '') as isbn,
        IFNULL(pm_authors.meta_value, '') as authors,
        IFNULL(pm_desc.meta_value, '') as description,
        GROUP_CONCAT(t.name SEPARATOR ', ') as categories
    FROM wp_${SITE_ID}_posts p
    LEFT JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_authors ON p.ID = pm_authors.post_id AND pm_authors.meta_key = '_best_authors'
    LEFT JOIN wp_${SITE_ID}_postmeta pm_desc ON p.ID = pm_desc.post_id AND pm_desc.meta_key = '_best_description'
    LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
    LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id AND tt.taxonomy = 'product_cat'
    LEFT JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
    WHERE p.ID = $post_id
    GROUP BY p.ID
    " 2>/dev/null)
    
    if [ -z "$book_info" ]; then
        return 1
    fi
    
    # Parser les infos
    IFS=$'\t' read -r id title isbn authors description categories <<< "$book_info"
    
    echo ""
    echo "📚 LIVRE À CATÉGORISER :"
    echo "════════════════════════════════════════════════════"
    echo "ID      : $id"
    echo "ISBN    : ${isbn:-Non défini}"
    echo "Titre   : $title"
    echo "Auteurs : ${authors:-Non défini}"
    echo "Description : $(echo "${description:-Non disponible}" | cut -c1-100)..."
    echo "Catégories actuelles : ${categories:-AUCUNE}"
    echo "════════════════════════════════════════════════════"
    
    # Retourner les valeurs pour utilisation
    echo "$title|$authors|$description|$categories"
}

# Fonction pour catégoriser un livre
categorize_book() {
    local post_id="$1"
    local test_mode="${2:-0}"
    
    echo ""
    echo "🔄 Traitement du livre ID: $post_id"
    
    # Afficher les infos et récupérer les données
    local book_data=$(display_book_info "$post_id" | tail -1)
    if [ "$book_data" = "0" ]; then
        echo "❌ Livre introuvable"
        return 1
    fi
    
    # Parser les données
    IFS='|' read -r title authors description current_cats <<< "$book_data"
    
    # Catégoriser avec Groq
    echo ""
    echo "🤖 Analyse par IA Groq..."
    local suggested_category=$(categorize_with_groq "$title" "$authors" "$description" "$current_cats")
    
    if [ -z "$suggested_category" ] || [ "$suggested_category" = "0" ]; then
        echo "❌ Impossible de déterminer une catégorie"
        return 1
    fi
    
    # Récupérer le nom de la catégorie
    local category_name=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT name FROM wp_${SITE_ID}_terms WHERE term_id = $suggested_category
    " 2>/dev/null)
    
    echo ""
    echo "✅ Catégorie suggérée : $category_name (ID: $suggested_category)"
    
    # Si mode test, s'arrêter ici
    if [ "$test_mode" = "1" ]; then
        echo "🧪 MODE TEST - Pas de sauvegarde"
        return 0
    fi
    
    # Appliquer la catégorie
    echo ""
    echo "💾 Application de la catégorie..."
    
    # Obtenir le term_taxonomy_id
    local term_taxonomy_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
    SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
    WHERE term_id = $suggested_category AND taxonomy = 'product_cat'
    " 2>/dev/null)
    
    # Supprimer les anciennes catégories
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    DELETE FROM wp_${SITE_ID}_term_relationships 
    WHERE object_id = $post_id 
    AND term_taxonomy_id IN (
        SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy 
        WHERE taxonomy = 'product_cat'
    )
    " 2>/dev/null
    
    # Ajouter la nouvelle catégorie
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    INSERT IGNORE INTO wp_${SITE_ID}_term_relationships (object_id, term_taxonomy_id)
    VALUES ($post_id, $term_taxonomy_id)
    " 2>/dev/null
    
    # Mettre à jour le compteur
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    UPDATE wp_${SITE_ID}_term_taxonomy 
    SET count = (
        SELECT COUNT(*) FROM wp_${SITE_ID}_term_relationships 
        WHERE term_taxonomy_id = $term_taxonomy_id
    )
    WHERE term_taxonomy_id = $term_taxonomy_id
    " 2>/dev/null
    
    echo "✅ Catégorie appliquée avec succès !"
    
    # Log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Livre $post_id catégorisé : $category_name (ID: $suggested_category)" >> "$LOG_DIR/smart_categorize.log"
    
    return 0
}

# Fonction pour rechercher des livres
search_books() {
    local search_term="$1"
    
    echo ""
    echo "🔍 Recherche de livres contenant '$search_term'..."
    echo ""
    
    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
    SELECT 
        p.ID,
        SUBSTRING(p.post_title, 1, 50) as Titre,
        IFNULL(pm_isbn.meta_value, 'N/A') as ISBN,
        CASE 
            WHEN COUNT(t.term_id) > 0 THEN 'OUI'
            ELSE 'NON'
        END as Catégorisé
    FROM wp_${SITE_ID}_posts p
    LEFT JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
    LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id AND tt.taxonomy = 'product_cat'
    LEFT JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
    WHERE p.post_type = 'product'
    AND p.post_status = 'publish'
    AND (p.post_title LIKE '%$search_term%' OR pm_isbn.meta_value LIKE '%$search_term%')
    GROUP BY p.ID
    ORDER BY p.ID DESC
    LIMIT 20
    " 2>/dev/null
}

# Programme principal
main() {
    clear
    
    # Vérifier la configuration
    if [ -z "$GROQ_API_KEY" ]; then
        echo "❌ ERREUR : Clé API Groq non configurée"
        echo "Configurez-la dans config/credentials.sh"
        exit 1
    fi
    
    # Créer le dossier de logs si nécessaire
    mkdir -p "$LOG_DIR"
    
    # Traiter les arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
            
        -all)
            echo "=== CATÉGORISATION DE TOUS LES LIVRES NON CATÉGORISÉS ==="
            echo ""
            
            # Compter les livres non catégorisés
            count=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT COUNT(DISTINCT p.ID)
            FROM wp_${SITE_ID}_posts p
            LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
            LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE p.post_type = 'product'
            AND p.post_status = 'publish'
            AND (tt.taxonomy != 'product_cat' OR tt.taxonomy IS NULL)
            " 2>/dev/null)
            
            echo "📊 $count livres non catégorisés trouvés"
            echo ""
            echo "⚠️  Cela peut prendre du temps. Continuer ? (oui/non)"
            read confirm
            
            if [ "$confirm" = "oui" ]; then
                # Traiter tous les livres
                mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                SELECT DISTINCT p.ID
                FROM wp_${SITE_ID}_posts p
                LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
                LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
                WHERE p.post_type = 'product'
                AND p.post_status = 'publish'
                AND (tt.taxonomy != 'product_cat' OR tt.taxonomy IS NULL)
                " 2>/dev/null | while read post_id; do
                    categorize_book "$post_id"
                    sleep 1  # Pause pour éviter de surcharger l'API
                done
            fi
            ;;
            
        -batch)
            limit="${2:-10}"
            echo "=== CATÉGORISATION PAR LOT ($limit livres) ==="
            
            # Traiter N livres
            mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT DISTINCT p.ID
            FROM wp_${SITE_ID}_posts p
            LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
            LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
            WHERE p.post_type = 'product'
            AND p.post_status = 'publish'
            AND (tt.taxonomy != 'product_cat' OR tt.taxonomy IS NULL)
            LIMIT $limit
            " 2>/dev/null | while read post_id; do
                categorize_book "$post_id"
                sleep 1
            done
            ;;
            
        -id)
            if [ -z "$2" ]; then
                echo "❌ ERREUR : ID manquant"
                exit 1
            fi
            echo "=== CATÉGORISATION PAR ID ==="
            categorize_book "$2"
            ;;
            
        -search)
            if [ -z "$2" ]; then
                echo "❌ ERREUR : Terme de recherche manquant"
                exit 1
            fi
            search_books "$2"
            echo ""
            echo "Entrez l'ID du livre à catégoriser (ou 'q' pour quitter) :"
            read book_id
            if [ "$book_id" != "q" ] && [ -n "$book_id" ]; then
                categorize_book "$book_id"
            fi
            ;;
            
        -test)
            if [ -z "$2" ]; then
                echo "❌ ERREUR : ISBN manquant pour le test"
                exit 1
            fi
            echo "=== MODE TEST (pas de sauvegarde) ==="
            # Trouver l'ID par ISBN
            post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT post_id FROM wp_${SITE_ID}_postmeta 
            WHERE meta_key = '_isbn' AND meta_value = '$2'
            LIMIT 1
            " 2>/dev/null)
            
            if [ -n "$post_id" ]; then
                categorize_book "$post_id" 1
            else
                echo "❌ ISBN non trouvé"
            fi
            ;;
            
        "")
            # Mode interactif
            echo "=== SMART CATEGORIZE - Mode Interactif ==="
            echo ""
            echo "Choisissez une option :"
            echo "1) Catégoriser par ISBN"
            echo "2) Catégoriser par ID"
            echo "3) Rechercher un livre"
            echo "4) Catégoriser 10 livres non catégorisés"
            echo "5) Voir les livres non catégorisés"
            echo ""
            echo -n "Votre choix (1-5) : "
            read choice
            
            case $choice in
                1)
                    echo -n "Entrez l'ISBN : "
                    read isbn
                    # Trouver l'ID par ISBN
                    post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
                    SELECT post_id FROM wp_${SITE_ID}_postmeta 
                    WHERE meta_key = '_isbn' AND meta_value = '$isbn'
                    LIMIT 1
                    " 2>/dev/null)
                    
                    if [ -n "$post_id" ]; then
                        categorize_book "$post_id"
                    else
                        echo "❌ ISBN non trouvé"
                    fi
                    ;;
                    
                2)
                    echo -n "Entrez l'ID du produit : "
                    read post_id
                    categorize_book "$post_id"
                    ;;
                    
                3)
                    echo -n "Terme de recherche : "
                    read term
                    search_books "$term"
                    echo ""
                    echo -n "ID du livre à catégoriser : "
                    read post_id
                    if [ -n "$post_id" ]; then
                        categorize_book "$post_id"
                    fi
                    ;;
                    
                4)
                    $0 -batch 10
                    ;;
                    
                5)
                    echo ""
                    echo "📚 Livres non catégorisés (20 premiers) :"
                    mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
                    SELECT 
                        p.ID,
                        SUBSTRING(p.post_title, 1, 50) as Titre,
                        IFNULL(pm_isbn.meta_value, 'N/A') as ISBN
                    FROM wp_${SITE_ID}_posts p
                    LEFT JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
                    LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
                    LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
                    WHERE p.post_type = 'product'
                    AND p.post_status = 'publish'
                    AND (tt.taxonomy != 'product_cat' OR tt.taxonomy IS NULL)
                    GROUP BY p.ID
                    LIMIT 20
                    " 2>/dev/null
                    ;;
            esac
            ;;
            
        *)
            # Supposer que c'est un ISBN
            echo "=== CATÉGORISATION PAR ISBN ==="
            # Trouver l'ID par ISBN
            post_id=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
            SELECT post_id FROM wp_${SITE_ID}_postmeta 
            WHERE meta_key = '_isbn' AND meta_value = '$1'
            LIMIT 1
            " 2>/dev/null)
            
            if [ -n "$post_id" ]; then
                categorize_book "$post_id"
            else
                echo "❌ ISBN '$1' non trouvé"
                echo ""
                echo "Utilisez -h pour voir l'aide"
            fi
            ;;
    esac
    
    echo ""
    echo "📊 Logs disponibles dans : $LOG_DIR/smart_categorize.log"
}

# Lancer le programme principal
main "$@"