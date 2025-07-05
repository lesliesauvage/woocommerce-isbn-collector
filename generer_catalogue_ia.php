<?php
// generer_catalogue_ia.php - Génère un fichier TXT/CSV avec toutes les infos des livres pour l'IA

// Configuration base de données
$config = [
   'host' => 'localhost',
   'user' => 'debian-sys-maint',
   'pass' => 'aFzkKFPTsryKaTIg',
   'db' => 'savoir'
];

// Connexion MySQL
$mysqli = new mysqli($config['host'], $config['user'], $config['pass'], $config['db']);
if ($mysqli->connect_error) {
   die("Erreur connexion: " . $mysqli->connect_error);
}
$mysqli->set_charset("utf8mb4");

// Format de sortie
$format = isset($argv[1]) ? $argv[1] : 'txt';
echo "=== GÉNÉRATION CATALOGUE POUR IA (format: $format) ===\n";

// Récupération de tous les livres avec leurs métadonnées
$query = "
SELECT 
   p.ID as id,
   p.post_title as titre,
   p.post_content as description_complete,
   p.post_excerpt as resume,
   p.post_status as statut,
   p.post_date as date_ajout,
   
   -- Prix
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_price' LIMIT 1) as prix,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_regular_price' LIMIT 1) as prix_normal,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_sale_price' LIMIT 1) as prix_promo,
   
   -- ISBN et identifiants
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_sku' LIMIT 1) as isbn,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_isbn10' LIMIT 1) as isbn10,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_isbn13' LIMIT 1) as isbn13,
   
   -- Infos livre
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_g_title' LIMIT 1) as titre_google,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_g_authors' LIMIT 1) as auteurs,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_g_publisher' LIMIT 1) as editeur,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_g_publishedDate' LIMIT 1) as date_publication,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_g_categories' LIMIT 1) as categories,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_g_language' LIMIT 1) as langue,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_g_pageCount' LIMIT 1) as nb_pages,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_g_description' LIMIT 1) as description_google,
   
   -- Stock et état
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_stock' LIMIT 1) as stock,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_stock_status' LIMIT 1) as statut_stock,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_product_condition' LIMIT 1) as etat_livre,
   
   -- Dimensions et poids
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_weight' LIMIT 1) as poids,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_length' LIMIT 1) as longueur,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_width' LIMIT 1) as largeur,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_height' LIMIT 1) as hauteur,
   
   -- Infos supplémentaires
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_i_subjects' LIMIT 1) as sujets,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_o_subjects' LIMIT 1) as sujets_openlibrary,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_calculated_genre' LIMIT 1) as genre,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_calculated_target_age' LIMIT 1) as age_cible,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_g_maturityRating' LIMIT 1) as classification,
   
   -- Bullets points
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_calculated_bullet1' LIMIT 1) as point1,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_calculated_bullet2' LIMIT 1) as point2,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_calculated_bullet3' LIMIT 1) as point3,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_calculated_bullet4' LIMIT 1) as point4,
   (SELECT meta_value FROM wp_28_postmeta WHERE post_id = p.ID AND meta_key = '_calculated_bullet5' LIMIT 1) as point5
   
FROM wp_28_posts p
WHERE p.post_type = 'product' 
AND p.post_status IN ('publish', 'draft')
ORDER BY p.ID DESC
";

$result = $mysqli->query($query);
if (!$result) {
   die("Erreur requête: " . $mysqli->error);
}

// Nom du fichier de sortie
$filename = "generer_catalogue_ia_" . date('Y-m-d_H-i-s') . ".$format";

// Fonction pour nettoyer le texte
function cleanText($text) {
   // Supprimer les retours à la ligne et tabulations
   $text = str_replace(["\r\n", "\r", "\n", "\t"], ' ', $text);
   // Supprimer les espaces multiples
   $text = preg_replace('/\s+/', ' ', $text);
   // Supprimer les guillemets qui pourraient casser le CSV
   $text = str_replace('"', '""', $text);
   return trim($text);
}

// Génération selon le format
if ($format == 'csv') {
   // Format CSV
   $fp = fopen($filename, 'w');
   
   // En-têtes
   $headers = [
       'ID', 'Titre', 'Auteurs', 'ISBN', 'ISBN10', 'ISBN13', 'Editeur', 
       'Date_Publication', 'Prix', 'Stock', 'Etat', 'Categories', 'Sujets',
       'Genre', 'Age_Cible', 'Langue', 'Pages', 'Poids_g', 'Dimensions_cm',
       'Description', 'Resume', 'Point1', 'Point2', 'Point3', 'Point4', 'Point5'
   ];
   fputcsv($fp, $headers);
   
   $count = 0;
   while ($row = $result->fetch_assoc()) {
       // Calculer les dimensions
       $dimensions = '';
       if ($row['longueur'] && $row['largeur'] && $row['hauteur']) {
           $dimensions = round($row['longueur'],1) . 'x' . round($row['largeur'],1) . 'x' . round($row['hauteur'],1);
       }
       
       // Préparer la ligne CSV
       $csv_row = [
           $row['id'],
           cleanText($row['titre'] ?: $row['titre_google'] ?: ''),
           cleanText($row['auteurs'] ?: ''),
           $row['isbn'] ?: '',
           $row['isbn10'] ?: '',
           $row['isbn13'] ?: '',
           cleanText($row['editeur'] ?: ''),
           $row['date_publication'] ?: '',
           $row['prix'] ?: '0',
           $row['stock'] ?: '0',
           cleanText($row['etat_livre'] ?: ''),
           cleanText($row['categories'] ?: ''),
           cleanText($row['sujets'] ?: $row['sujets_openlibrary'] ?: ''),
           cleanText($row['genre'] ?: ''),
           $row['age_cible'] ?: '',
           $row['langue'] ?: 'fr',
           $row['nb_pages'] ?: '',
           $row['poids'] ? round($row['poids'] * 1000) : '', // Convertir en grammes
           $dimensions,
           cleanText($row['description_google'] ?: $row['description_complete'] ?: ''),
           cleanText($row['resume'] ?: ''),
           cleanText($row['point1'] ?: ''),
           cleanText($row['point2'] ?: ''),
           cleanText($row['point3'] ?: ''),
           cleanText($row['point4'] ?: ''),
           cleanText($row['point5'] ?: '')
       ];
       
       fputcsv($fp, $csv_row);
       $count++;
   }
   
   fclose($fp);
   
} else {
   // Format TXT (plus détaillé et lisible)
   $fp = fopen($filename, 'w');
   
   $count = 0;
   while ($row = $result->fetch_assoc()) {
       $count++;
       
       // Titre principal
       $titre = $row['titre'] ?: $row['titre_google'] ?: 'Sans titre';
       fwrite($fp, "═══════════════════════════════════════════════════════════════\n");
       fwrite($fp, "LIVRE #" . $row['id'] . " - " . cleanText($titre) . "\n");
       fwrite($fp, "═══════════════════════════════════════════════════════════════\n\n");
       
       // Identifiants
       fwrite($fp, "📚 IDENTIFIANTS:\n");
       if ($row['isbn']) fwrite($fp, "   ISBN: " . $row['isbn'] . "\n");
       if ($row['isbn10']) fwrite($fp, "   ISBN-10: " . $row['isbn10'] . "\n");
       if ($row['isbn13']) fwrite($fp, "   ISBN-13: " . $row['isbn13'] . "\n");
       fwrite($fp, "\n");
       
       // Infos principales
       fwrite($fp, "📖 INFORMATIONS PRINCIPALES:\n");
       if ($row['auteurs']) fwrite($fp, "   Auteur(s): " . cleanText($row['auteurs']) . "\n");
       if ($row['editeur']) fwrite($fp, "   Éditeur: " . cleanText($row['editeur']) . "\n");
       if ($row['date_publication']) fwrite($fp, "   Date publication: " . $row['date_publication'] . "\n");
       if ($row['langue']) fwrite($fp, "   Langue: " . $row['langue'] . "\n");
       if ($row['nb_pages']) fwrite($fp, "   Pages: " . $row['nb_pages'] . "\n");
       fwrite($fp, "\n");
       
       // Catégorisation
       fwrite($fp, "🏷️ CATÉGORISATION:\n");
       if ($row['categories']) fwrite($fp, "   Catégories: " . cleanText($row['categories']) . "\n");
       if ($row['sujets'] || $row['sujets_openlibrary']) {
           $sujets = $row['sujets'] ?: $row['sujets_openlibrary'];
           fwrite($fp, "   Sujets: " . cleanText($sujets) . "\n");
       }
       if ($row['genre']) fwrite($fp, "   Genre: " . cleanText($row['genre']) . "\n");
       if ($row['age_cible']) fwrite($fp, "   Âge cible: " . $row['age_cible'] . "\n");
       if ($row['classification']) fwrite($fp, "   Classification: " . $row['classification'] . "\n");
       fwrite($fp, "\n");
       
       // Commercial
       fwrite($fp, "💰 INFORMATIONS COMMERCIALES:\n");
       fwrite($fp, "   Prix: " . ($row['prix'] ?: '0') . "€\n");
       if ($row['prix_promo']) fwrite($fp, "   Prix promo: " . $row['prix_promo'] . "€\n");
       fwrite($fp, "   Stock: " . ($row['stock'] ?: '0') . "\n");
       if ($row['etat_livre']) fwrite($fp, "   État: " . cleanText($row['etat_livre']) . "\n");
       fwrite($fp, "\n");
       
       // Physique
       if ($row['poids'] || $row['longueur']) {
           fwrite($fp, "📏 CARACTÉRISTIQUES PHYSIQUES:\n");
           if ($row['poids']) fwrite($fp, "   Poids: " . round($row['poids'] * 1000) . "g\n");
           if ($row['longueur'] && $row['largeur'] && $row['hauteur']) {
               fwrite($fp, "   Dimensions: " . round($row['longueur'],1) . " x " . 
                      round($row['largeur'],1) . " x " . round($row['hauteur'],1) . " cm\n");
           }
           fwrite($fp, "\n");
       }
       
       // Description
       $description = $row['description_google'] ?: $row['description_complete'] ?: $row['resume'];
       if ($description) {
           fwrite($fp, "📄 DESCRIPTION:\n");
           fwrite($fp, "   " . cleanText($description) . "\n\n");
       }
       
       // Points clés
       $has_bullets = false;
       for ($i = 1; $i <= 5; $i++) {
           if ($row["point$i"]) {
               if (!$has_bullets) {
                   fwrite($fp, "🔸 POINTS CLÉS:\n");
                   $has_bullets = true;
               }
               fwrite($fp, "   • " . cleanText($row["point$i"]) . "\n");
           }
       }
       if ($has_bullets) fwrite($fp, "\n");
       
       fwrite($fp, "\n\n");
   }
   
   fclose($fp);
}

// Résumé
echo "\n✅ Fichier généré: $filename\n";
echo "📊 Nombre de livres exportés: $count\n";
echo "📏 Taille du fichier: " . number_format(filesize($filename) / 1024, 2) . " KB\n";

// Statistiques
$stats = $mysqli->query("
   SELECT 
       COUNT(DISTINCT post_id) as avec_isbn,
       COUNT(DISTINCT CASE WHEN meta_value != '' THEN post_id END) as avec_donnees
   FROM wp_28_postmeta 
   WHERE meta_key = '_sku'
")->fetch_assoc();

echo "\n📈 STATISTIQUES:\n";
echo "   Livres avec ISBN: " . $stats['avec_isbn'] . "\n";
echo "   Livres avec données: " . $stats['avec_donnees'] . "\n";

// Catégories principales
echo "\n🏷️ TOP 10 CATÉGORIES:\n";
$cats = $mysqli->query("
   SELECT meta_value, COUNT(*) as nb 
   FROM wp_28_postmeta 
   WHERE meta_key = '_g_categories' 
   AND meta_value != '' 
   GROUP BY meta_value 
   ORDER BY nb DESC 
   LIMIT 10
");
while ($cat = $cats->fetch_assoc()) {
   echo "   • " . cleanText($cat['meta_value']) . " (" . $cat['nb'] . " livres)\n";
}

echo "\n💡 UTILISATION POUR L'IA:\n";
echo "   Ce fichier contient toutes les informations nécessaires pour que l'IA puisse:\n";
echo "   • Comprendre votre catalogue complet\n";
echo "   • Identifier les relations entre les livres\n";
echo "   • Proposer des recommandations pertinentes\n";
echo "   • Analyser les tendances et préférences\n";

$mysqli->close();
?>
