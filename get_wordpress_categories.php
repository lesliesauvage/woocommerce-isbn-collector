<?php
// Script pour récupérer toutes les catégories WordPress et créer un tableau de mapping

// Connexion à la base de données WordPress
require_once('/var/www/html/wp-config.php');

$mysqli = new mysqli(DB_HOST, DB_USER, DB_PASSWORD, DB_NAME);

if ($mysqli->connect_error) {
    die("Erreur de connexion: " . $mysqli->connect_error);
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
    'Catégorie Ecolivre',
    'Slug',
    'Amazon',
    'Rakuten', 
    'eBay',
    'FNAC',
    'Cdiscount',
    'Leboncoin',
    'Vinted',
    'Facebook'
], ';');

// Mappings par défaut pour les marketplaces
$default_mappings = [
    'amazon' => '283155', // Books category ID
    'rakuten' => 'livres',
    'ebay' => '267', // Books category ID
    'fnac' => 'livre',
    'cdiscount' => 'livres',
    'leboncoin' => '27',
    'vinted' => '1601', // Books category ID
    'facebook' => '287' // Books category ID
];

// Parcourir toutes les catégories
while ($row = $result->fetch_assoc()) {
    $category_name = $row['category_name'];
    $slug = $row['slug'];
    
    // Essayer de mapper intelligemment selon le nom de la catégorie
    $amazon_map = $default_mappings['amazon'];
    $rakuten_map = $default_mappings['rakuten'];
    $ebay_map = $default_mappings['ebay'];
    $fnac_map = $default_mappings['fnac'];
    $cdiscount_map = $default_mappings['cdiscount'];
    $leboncoin_map = $default_mappings['leboncoin'];
    $vinted_map = $default_mappings['vinted'];
    $facebook_map = $default_mappings['facebook'];
    
    // Logique de mapping spécifique selon les mots-clés
    $category_lower = strtolower($category_name);
    
    if (strpos($category_lower, 'roman') !== false || strpos($category_lower, 'littérature') !== false) {
        $rakuten_map = 'Littérature française';
    } elseif (strpos($category_lower, 'polar') !== false || strpos($category_lower, 'thriller') !== false) {
        $rakuten_map = 'Policier';
    } elseif (strpos($category_lower, 'science-fiction') !== false || strpos($category_lower, 'sf') !== false) {
        $rakuten_map = 'Science-fiction';
    } elseif (strpos($category_lower, 'fantasy') !== false || strpos($category_lower, 'fantastique') !== false) {
        $rakuten_map = 'Fantasy';
    } elseif (strpos($category_lower, 'histoire') !== false) {
        $rakuten_map = 'Histoire';
    } elseif (strpos($category_lower, 'art') !== false) {
        $rakuten_map = 'Beaux arts';
    } elseif (strpos($category_lower, 'cuisine') !== false) {
        $rakuten_map = 'Cuisine';
    } elseif (strpos($category_lower, 'voyage') !== false || strpos($category_lower, 'tourisme') !== false) {
        $rakuten_map = 'Tourisme et voyages';
    } elseif (strpos($category_lower, 'jeunesse') !== false || strpos($category_lower, 'enfant') !== false) {
        $rakuten_map = 'Jeunesse';
    } elseif (strpos($category_lower, 'bd') !== false || strpos($category_lower, 'bande dessinée') !== false) {
        $rakuten_map = 'Bande dessinée';
    } elseif (strpos($category_lower, 'manga') !== false) {
        $rakuten_map = 'Manga';
    }
    
    // Écrire la ligne dans le CSV
    fputcsv($fp, [
        $category_name,
        $slug,
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