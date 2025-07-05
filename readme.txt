📚 DOCUMENTATION DES FICHIERS DU PROJET ISBN
🎯 SCRIPTS PRINCIPAUX
run.sh - Menu principal du système
Point d'entrée principal avec menu interactif offrant 11 options :

Test avec 3 livres de référence (16091, 16089, 16087)
Collecter TOUS les livres sans données
Collecter UN livre spécifique (par ID ou ISBN)
AJOUTER un nouveau livre par ISBN
Créer des fiches complètes (appelle martingale.sh)
Générer un rapport des données
Afficher les données d'un livre
Tester toutes les APIs
Tester Groq IA
Nettoyer les doublons dans la base
Effacer les données d'un livre

collect_api_data.sh - Collecte automatique des données
Script principal de collecte qui :

Interroge Google Books, ISBNdb et Open Library
Enrichit avec Gallica et Groq IA si nécessaire
Calcule poids et dimensions
Génère les bullet points Amazon
Stocke les meilleures données dans _best_*
Crée des logs détaillés dans logs/

martingale.sh - Analyse complète et export
Système d'analyse avancée qui :

Affiche TOUTES les données collectées par API
Montre les images disponibles (toutes tailles)
Détermine la catégorie Vinted automatiquement
Génère un fichier JSON complet (generer_book_*_complete.json)
Analyse les données manquantes
Options : 3 livres test / livre spécifique / recollecte

add_and_collect.sh - Ajout rapide d'un livre
Script simplifié pour :

Créer un livre avec juste l'ISBN
Lancer automatiquement la collecte
Usage : ./add_and_collect.sh 9782070368228

add_book_minimal.sh - Ajout minimal d'un livre
Version ultra-légère qui :

Crée le produit WordPress
Ajoute les métadonnées minimales
Ne lance PAS la collecte automatiquement

generate_report.sh - Rapport détaillé
Génère des statistiques sur :

Nombre de produits enrichis
Efficacité par API
Sources des meilleures données
Produits problématiques

📁 STRUCTURE DES DOSSIERS
config/ - Configuration

settings.sh : Configuration globale (DB, clés API, chemins)

lib/ - Bibliothèques de fonctions

safe_functions.sh : Fonctions sécurisées (OBLIGATOIRE dans tous les scripts)

safe_sql() : Échappe les apostrophes
safe_store_meta() : Stockage sécurisé
validate_isbn() : Validation ISBN
check_environment() : Vérification environnement


utils.sh : Utilitaires (log, JSON, parsing)
database.sh : Fonctions MySQL
enrichment.sh : Calculs (poids, dimensions, bullet points)
best_data.sh : Sélection des meilleures données
analyze_functions.sh : Analyse et tableaux formatés

lib/marketplace/ - Requirements par marketplace

amazon.sh : Tableau des requirements Amazon
rakuten.sh : Requirements Rakuten/PriceMinister
vinted.sh : Requirements Vinted avec catégories
fnac.sh : Requirements Fnac
cdiscount.sh : Requirements Cdiscount
leboncoin.sh : Requirements Leboncoin

apis/ - Connecteurs API

google_books.sh : API Google Books (avec TOUTES les tailles d'images)
isbndb.sh : API ISBNdb (reliure, prix)
open_library.sh : API Open Library
groq_ai.sh : Groq IA pour générer des descriptions
other_apis.sh : Gallica, WorldCat, Archive.org

exports/ - Scripts d'export

export_all.sh : Lance tous les exports
export_amazon.sh : Export CSV Amazon
export_vinted.sh : Export CSV Vinted
export_rakuten.sh : Export CSV Rakuten
export_fnac.sh : Export CSV Fnac
export_cdiscount.sh : Export CSV Cdiscount
export_template.sh : Template pour nouveaux exports

logs/ - Fichiers de logs

collect_*.log : Logs de collecte horodatés
errors_*.log : Logs d'erreurs

exports/output/ - Fichiers générés

generer_*.csv : Fichiers d'export pour les marketplaces
generer_book_*_complete.json : Données complètes en JSON

🔧 FICHIERS OBSOLÈTES (à ignorer)

*.old : Anciennes versions
*.bak* : Sauvegardes
test_*.sh : Scripts temporaires (supprimés après usage)
collect_single_book.sh : Généré temporairement par run.sh

💡 WORKFLOW TYPIQUE

Ajouter un livre : ./add_and_collect.sh 9782070368228
Vérifier les données : ./martingale.sh → option 2
Exporter : ./exports/export_all.sh
Rapport global : ./generate_report.sh

🎯 COMMANDES UTILES
bash# Ajouter et collecter un livre
./add_and_collect.sh 9782070368228

# Voir tous les livres
./run.sh → option 7

# Analyser un livre complet
./martingale.sh → option 2

# Recollecte en masse
./collect_api_data.sh

# Export vers toutes les marketplaces
./exports/export_all.sh
⚠️ RÈGLES IMPORTANTES

TOUJOURS sourcer lib/safe_functions.sh dans chaque script
Les fichiers générés commencent par generer_
Ne pas modifier directement la base, utiliser les fonctions safe_*
Les logs sont dans logs/ avec horodatage
