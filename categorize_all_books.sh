#!/bin/bash
echo "[START: categorize_all_books.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

clear
source config/settings.sh
source lib/safe_functions.sh

echo "=== CATÉGORISATION AUTOMATIQUE VIA GROQ ==="
echo "Date : $(date)"
echo ""

# Récupérer toutes les catégories
echo "📂 Chargement des catégories WordPress..."
categories_list=$(safe_mysql "
    SELECT CONCAT(t.term_id, ':', t.name) 
    FROM wp_${SITE_ID}_terms t
    JOIN wp_${SITE_ID}_term_taxonomy tt ON t.term_id = tt.term_id
    WHERE tt.taxonomy = 'product_cat'
    ORDER BY t.name" | tr '\n' '|' | sed 's/|$//')

echo "✅ $(echo "$categories_list" | tr '|' '\n' | wc -l) catégories trouvées"
echo ""

# Récupérer les livres non catégorisés
echo "🔍 Recherche des livres non catégorisés..."
books=$(safe_mysql "
    SELECT DISTINCT p.ID, pm_isbn.meta_value as isbn
    FROM wp_${SITE_ID}_posts p
    JOIN wp_${SITE_ID}_postmeta pm_isbn ON p.ID = pm_isbn.post_id AND pm_isbn.meta_key = '_isbn'
    LEFT JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id
    LEFT JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id AND tt.taxonomy = 'product_cat'
    WHERE p.post_type = 'product'
    AND p.post_status = 'publish'
    AND tt.term_taxonomy_id IS NULL
    LIMIT 10")

total=$(echo "$books" | wc -l)
echo "📚 $total livres à catégoriser (limité à 10 pour ce test)"
echo ""

if [ $total -eq 0 ]; then
    echo "✅ Tous les livres sont déjà catégorisés !"
    exit 0
fi

echo "Début du traitement..."
echo "══════════════════════════════════════════════════════════════════"
echo ""

current=0
success=0
errors=0

while IFS=$'\t' read -r product_id isbn; do
    [ -z "$product_id" ] && continue
    ((current++))
    
    echo "[$current/$total] Livre ID: $product_id - ISBN: $isbn"
    echo "──────────────────────────────────────────────────────────────────"
    
    # Récupérer les données du livre
    book_data=$(safe_mysql "
        SELECT 
            COALESCE(pm1.meta_value, pm1b.meta_value, 'Sans titre') as title,
            COALESCE(pm2.meta_value, pm2b.meta_value, '') as authors,
            COALESCE(pm3.meta_value, '') as g_cats,
            COALESCE(pm4.meta_value, '') as i_subs,
            COALESCE(pm5.meta_value, pm5b.meta_value, '') as publisher,
            COALESCE(pm6.meta_value, 'fr') as language
        FROM wp_${SITE_ID}_posts p
        LEFT JOIN wp_${SITE_ID}_postmeta pm1 ON p.ID = pm1.post_id AND pm1.meta_key = '_best_title'
        LEFT JOIN wp_${SITE_ID}_postmeta pm1b ON p.ID = pm1b.post_id AND pm1b.meta_key = '_g_title'
        LEFT JOIN wp_${SITE_ID}_postmeta pm2 ON p.ID = pm2.post_id AND pm2.meta_key = '_best_authors'
        LEFT JOIN wp_${SITE_ID}_postmeta pm2b ON p.ID = pm2b.post_id AND pm2b.meta_key = '_g_authors'
        LEFT JOIN wp_${SITE_ID}_postmeta pm3 ON p.ID = pm3.post_id AND pm3.meta_key = '_g_categories'
        LEFT JOIN wp_${SITE_ID}_postmeta pm4 ON p.ID = pm4.post_id AND pm4.meta_key = '_i_subjects'
        LEFT JOIN wp_${SITE_ID}_postmeta pm5 ON p.ID = pm5.post_id AND pm5.meta_key = '_best_publisher'
        LEFT JOIN wp_${SITE_ID}_postmeta pm5b ON p.ID = pm5b.post_id AND pm5b.meta_key = '_g_publisher'
        LEFT JOIN wp_${SITE_ID}_postmeta pm6 ON p.ID = pm6.post_id AND pm6.meta_key = '_g_language'
        WHERE p.ID = $product_id")
    
    IFS=$'\t' read -r title authors g_cats i_subs publisher language <<< "$book_data"
    
    echo "📖 Titre: $title"
    echo "✍️  Auteur: ${authors:-Non renseigné}"
    echo ""
    
    # Préparer le prompt
    prompt="Tu es un système de classification.

Livre:
- Titre: $title
- Auteur: $authors
- Éditeur: $publisher
- Langue: $language
- Catégories Google: $g_cats
- Sujets ISBNdb: $i_subs

Catégories disponibles:
$categories_list

RÈGLES:
1. Pour un auteur français, préfère 'Romans français' à 'Romans'
2. Choisis la catégorie LA PLUS SPÉCIFIQUE
3. Réponds UNIQUEMENT avec: ID|Nom"

    # Appel à Groq
    echo "🤖 Analyse par Groq..."
    
    groq_response=$(curl -s -X POST https://api.groq.com/openai/v1/chat/completions \
        -H "Authorization: Bearer $GROQ_API_KEY" \
        -H "Content-Type: application/json" \
        --max-time 10 \
        -d "{
            \"model\": \"llama3-70b-8192\",
            \"messages\": [{
                \"role\": \"system\",
                \"content\": \"Tu réponds UNIQUEMENT avec le format ID|Nom sans aucun texte.\"
            }, {
                \"role\": \"user\",
                \"content\": \"$(echo "$prompt" | sed 's/"/\\"/g' | tr '\n' ' ')\"
            }],
            \"temperature\": 0.2,
            \"max_tokens\": 30
        }" 2>/dev/null)
    
    # Extraire la suggestion
    suggestion=$(echo "$groq_response" | jq -r '.choices[0].message.content' 2>/dev/null)
    
    # Nettoyer pour extraire le format ID|Nom
    clean_suggestion=$(echo "$suggestion" | grep -oE '[0-9]+\|[^[:space:]]+' | head -1)
    
    if [ -n "$clean_suggestion" ]; then
        echo "✅ Catégorie suggérée: $clean_suggestion"
        
        # Parser
        cat_id=$(echo "$clean_suggestion" | cut -d'|' -f1)
        cat_name=$(echo "$clean_suggestion" | cut -d'|' -f2-)
        
        # Vérifier que la catégorie existe
        exists=$(safe_mysql "SELECT COUNT(*) FROM wp_${SITE_ID}_terms WHERE term_id = $cat_id")
        
        if [ "$exists" = "1" ]; then
            # Assigner la catégorie
            safe_mysql "INSERT INTO wp_${SITE_ID}_term_relationships (object_id, term_taxonomy_id) 
                       SELECT $product_id, term_taxonomy_id 
                       FROM wp_${SITE_ID}_term_taxonomy 
                       WHERE term_id = $cat_id AND taxonomy = 'product_cat'
                       ON DUPLICATE KEY UPDATE term_taxonomy_id = term_taxonomy_id"
            
            # Stocker les métadonnées
            safe_store_meta "$product_id" "_groq_category_id" "$cat_id"
            safe_store_meta "$product_id" "_groq_category_name" "$cat_name"
            safe_store_meta "$product_id" "_groq_category_date" "$(date '+%Y-%m-%d %H:%M:%S')"
            
            # Stocker _g_categorie_reference comme demandé dans vos instructions
            if [ -n "$g_cats" ]; then
                safe_store_meta "$product_id" "_g_categorie_reference" "$g_cats"
            fi
            
            echo "✅ Catégorie assignée avec succès!"
            ((success++))
        else
            echo "❌ Catégorie invalide: $cat_id"
            ((errors++))
        fi
    else
        echo "❌ Pas de suggestion valide reçue"
        echo "Réponse brute: $suggestion"
        ((errors++))
    fi
    
    echo ""
    
    # Pause pour éviter de surcharger l'API
    sleep 1
done <<< "$books"

echo "══════════════════════════════════════════════════════════════════"
echo ""
echo "📊 RÉSUMÉ"
echo "────────"
echo "✅ Succès : $success/$total"
echo "❌ Erreurs : $errors/$total"
echo ""

# Afficher les catégories les plus utilisées
echo "🏷️  TOP 10 DES CATÉGORIES ASSIGNÉES"
echo "──────────────────────────────────"
safe_mysql "
    SELECT t.name as Catégorie, COUNT(*) as 'Nombre de livres'
    FROM wp_${SITE_ID}_term_relationships tr
    JOIN wp_${SITE_ID}_term_taxonomy tt ON tr.term_taxonomy_id = tt.term_taxonomy_id
    JOIN wp_${SITE_ID}_terms t ON tt.term_id = t.term_id
    WHERE tt.taxonomy = 'product_cat'
    GROUP BY t.term_id
    ORDER BY COUNT(*) DESC
    LIMIT 10"

echo ""
echo "✅ Catégorisation terminée!"
echo ""
echo "Pour voir les livres d'une catégorie spécifique:"
echo "mysql -e \"SELECT p.ID, p.post_title FROM wp_${SITE_ID}_posts p JOIN wp_${SITE_ID}_term_relationships tr ON p.ID = tr.object_id WHERE tr.term_taxonomy_id = (SELECT term_taxonomy_id FROM wp_${SITE_ID}_term_taxonomy WHERE term_id = ID_CATEGORIE)\""

echo "[END: categorize_all_books.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
