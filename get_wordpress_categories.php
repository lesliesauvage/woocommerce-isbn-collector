<?php
// Script pour récupérer toutes les catégories WordPress avec leur hiérarchie complète

// Configuration de la base de données
$db_host = 'localhost';
$db_user = 'wordpress';
$db_pass = 'e96e30c154b7a661211a793bbac6416dcbaf9843ff19fb54';
$db_name = 'savoir';
$table_prefix = 'wp_';

$mysqli = new mysqli($db_host, $db_user, $db_pass, $db_name);

if ($mysqli->connect_error) {
    die("Erreur de connexion: " . $mysqli->connect_error);
}

// Fonction pour obtenir le chemin complet d'une catégorie
function getCategoryPath($term_id, $mysqli, $table_prefix) {
    $path = [];
    $current_id = $term_id;
    
    while ($current_id != 0) {
        $query = "
            SELECT t.name, tt.parent 
            FROM {$table_prefix}terms t
            INNER JOIN {$table_prefix}term_taxonomy tt ON t.term_id = tt.term_id
            WHERE t.term_id = $current_id AND tt.taxonomy = 'product_cat'
        ";
        
        $result = $mysqli->query($query);
        if ($row = $result->fetch_assoc()) {
            array_unshift($path, $row['name']);
            $current_id = $row['parent'];
        } else {
            break;
        }
    }
    
    return implode(' > ', $path);
}

// Récupérer toutes les catégories WordPress
$query = "
    SELECT 
        t.term_id,
        t.name as category_name,
        t.slug,
        tt.parent,
        tt.count
    FROM {$table_prefix}terms t
    INNER JOIN {$table_prefix}term_taxonomy tt ON t.term_id = tt.term_id
    WHERE tt.taxonomy = 'product_cat'
    ORDER BY t.name ASC
";

$result = $mysqli->query($query);

if (!$result) {
    die("Erreur requête: " . $mysqli->error);
}

// Créer le tableau CSV avec les mappings
$csv_file = '/var/www/scripts-home-root/isbn/exports/categories_mapping_complet.csv';
$fp = fopen($csv_file, 'w');

// En-tête du CSV
fputcsv($fp, [
    'ID',
    'Catégorie Ecolivre',
    'Chemin complet',
    'Slug',
    'Parent ID',
    'Amazon (ID: Catégorie)',
    'Rakuten (Catégorie)',
    'eBay (ID: Catégorie)',
    'FNAC (Catégorie)',
    'Cdiscount (Catégorie)',
    'Leboncoin (ID: Catégorie)',
    'Vinted (ID: Catégorie)',
    'Facebook (ID: Catégorie)'
], ';');

// Charger le fichier de mapping Rakuten existant
$rakuten_mappings = [];
$rakuten_file = '/var/www/scripts-home-root/isbn/config/rakuten_category_mapping.csv';
if (file_exists($rakuten_file)) {
    if (($handle = fopen($rakuten_file, "r")) !== FALSE) {
        while (($data = fgetcsv($handle, 1000, ",")) !== FALSE) {
            if (count($data) >= 2) {
                $rakuten_mappings[strtolower(trim($data[0]))] = trim($data[1]);
            }
        }
        fclose($handle);
    }
}

// Mappings détaillés pour Amazon (sous-catégories livres)
$amazon_mappings = [
    'art' => '283155: Arts & Photography',
    'biographie' => '283155: Biographies & Memoirs',
    'business' => '283155: Business & Money',
    'enfant' => '283155: Children\'s Books',
    'cuisine' => '283155: Cookbooks, Food & Wine',
    'informatique' => '283155: Computers & Technology',
    'histoire' => '283155: History',
    'littérature' => '283155: Literature & Fiction',
    'mystère' => '283155: Mystery, Thriller & Suspense',
    'romance' => '283155: Romance',
    'science-fiction' => '283155: Science Fiction & Fantasy',
    'jeunesse' => '283155: Teen & Young Adult',
    'voyage' => '283155: Travel'
];

// Mappings eBay (sous-catégories livres)
$ebay_mappings = [
    'art' => '267: Art & Photography',
    'enfant' => '267: Children & Young Adults',
    'bd' => '267: Comics & Graphic Novels',
    'fiction' => '267: Fiction & Literature',
    'histoire' => '267: History',
    'magazine' => '267: Magazine Back Issues',
    'non-fiction' => '267: Nonfiction',
    'textbook' => '267: Textbooks, Education & Reference'
];

// Parcourir toutes les catégories
while ($row = $result->fetch_assoc()) {
    $term_id = $row['term_id'];
    $category_name = $row['category_name'];
    $slug = $row['slug'];
    $parent_id = $row['parent'];
    
    // Obtenir le chemin complet de la catégorie
    $full_path = getCategoryPath($term_id, $mysqli, $table_prefix);
    
    // Logique de mapping intelligente basée sur le chemin complet
    $category_lower = strtolower($full_path);
    
    // Amazon mapping
    $amazon_map = '283155: Books';
    foreach ($amazon_mappings as $keyword => $mapping) {
        if (strpos($category_lower, $keyword) !== false) {
            $amazon_map = $mapping;
            break;
        }
    }
    
    // Rakuten mapping - utiliser le fichier existant
    $rakuten_map = 'Littérature française';
    foreach ($rakuten_mappings as $rakuten_cat => $rakuten_val) {
        if (strpos($category_lower, strtolower($rakuten_cat)) !== false) {
            $rakuten_map = $rakuten_val;
            break;
        }
    }
    
    // eBay mapping
    $ebay_map = '267: Books';
    foreach ($ebay_mappings as $keyword => $mapping) {
        if (strpos($category_lower, $keyword) !== false) {
            $ebay_map = $mapping;
            break;
        }
    }
    
    // Autres marketplaces avec leur logique spécifique
    $fnac_map = 'livre';
    $cdiscount_map = 'livres';
    $leboncoin_map = '27: Livres';
    $vinted_map = '1601: Livres';
    $facebook_map = '287: Books';
    
    // Mappings spécifiques selon les mots-clés dans le chemin complet
    if (strpos($category_lower, 'bd') !== false || strpos($category_lower, 'bande dessinée') !== false) {
        $fnac_map = 'bd';
        $cdiscount_map = 'bd-mangas';
    } elseif (strpos($category_lower, 'manga') !== false) {
        $fnac_map = 'manga';
        $cdiscount_map = 'bd-mangas';
    } elseif (strpos($category_lower, 'jeunesse') !== false || strpos($category_lower, 'enfant') !== false) {
        $fnac_map = 'livre-jeunesse';
        $cdiscount_map = 'livres-jeunesse';
    }
    
    // Écrire la ligne dans le CSV
    fputcsv($fp, [
        $term_id,
        $category_name,
        $full_path,
        $slug,
        $parent_id,
        $amazon_map,
        $rakuten_map,
        $ebay_map,
        $fnac_map,
        $cdiscount_map,
        $leboncoin_map,
        $vinted_map,
        $facebook_map
    ], ';');
}

fclose($fp);
$mysqli->close();

echo "Tableau de mapping créé avec succès : $csv_file\n";
echo "Nombre de catégories trouvées : " . $result->num_rows . "\n";
?>