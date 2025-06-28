#!/bin/bash

echo "=== NETTOYAGE DU RÉPERTOIRE ISBN ==="
echo ""
echo "Ce script va supprimer tous les fichiers temporaires et obsolètes"
echo "en gardant seulement la version finale fonctionnelle."
echo ""

# Demander confirmation
read -p "Êtes-vous sûr de vouloir nettoyer le répertoire ? (o/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Oo]$ ]]; then
    echo "Annulé."
    exit 1
fi

echo ""
echo "Suppression des fichiers obsolètes..."

# 1. Supprimer les anciennes versions du script principal
echo "  - Anciennes versions du script principal..."
rm -f collect_api_data_old.sh
rm -f collect_api_data.sh
rm -f collect_api_data_v2.sh
rm -f collect_api_data_v3.sh
rm -f collect_api_data_debug.sh
rm -f collect_api_data_final.sh
rm -f collect_api_data_working.sh

# 2. Supprimer les scripts de correction
echo "  - Scripts de correction temporaires..."
rm -f fix_paths.sh
rm -f fix_all_paths.sh
rm -f fix_counters.sh
rm -f fix_counters_final.sh
rm -f final_fix.sh
rm -f create_modular_structure.sh

# 3. Supprimer les scripts de test temporaires
echo "  - Scripts de test temporaires..."
rm -f test_api.sh
rm -f test_api_direct.sh
rm -f test_simple.sh
rm -f test_simple_collect.sh
rm -f test_counters.sh

# 4. Supprimer les anciennes versions de martingale
echo "  - Anciennes versions de martingale..."
rm -f martingale.sh
rm -f martingale_complete.sh

# 5. Supprimer les scripts temporaires
echo "  - Scripts temporaires..."
rm -f check_data.sh
rm -f show_all_variables.sh
rm -f clean_and_show.sh

# 6. Supprimer les fichiers JSON temporaires (garder seulement les complete)
echo "  - Fichiers JSON temporaires..."
rm -f book_2040120815.json
rm -f book_2850760854.json
rm -f book_2901821030.json

# 7. Renommer les fichiers finaux pour plus de clarté
echo ""
echo "Renommage des fichiers finaux..."
mv -f collect_api_data_final_v2.sh collect_api_data.sh 2>/dev/null || true
mv -f martingale_fixed.sh martingale.sh 2>/dev/null || true

# 8. Créer un script de lancement principal
echo ""
echo "Création du script de lancement principal..."
cat > run.sh << 'EOF'
#!/bin/bash
# Script de lancement principal pour la collecte ISBN

echo "=== COLLECTE DE DONNÉES ISBN ==="
echo ""
echo "Que voulez-vous faire ?"
echo "1) Lancer la collecte automatique"
echo "2) Créer des fiches complètes (martingale)"
echo "3) Générer un rapport"
echo "4) Tester les APIs"
echo "5) Tester Groq IA"
echo ""
read -p "Votre choix (1-5) : " choice

case $choice in
    1)
        echo "Lancement de la collecte..."
        ./collect_api_data.sh
        ;;
    2)
        echo "Création des fiches complètes..."
        ./martingale.sh
        ;;
    3)
        echo "Génération du rapport..."
        ./generate_report.sh
        ;;
    4)
        echo "Test des APIs..."
        ./test_apis.sh
        ;;
    5)
        echo "Test de Groq IA..."
        ./test_groq.sh
        ;;
    *)
        echo "Choix invalide"
        exit 1
        ;;
esac
EOF
chmod +x run.sh

# 9. Mettre à jour le README
echo ""
echo "Mise à jour du README..."
cat > README.md << 'EOF'
# Système de collecte de données ISBN

## Version finale modulaire

### Structure
```
isbn/
├── run.sh                    # Script principal de lancement
├── collect_api_data.sh       # Collecte automatique des données
├── martingale.sh            # Création de fiches complètes
├── generate_report.sh       # Génération de rapports
├── test_apis.sh            # Test des APIs
├── test_groq.sh            # Test de Groq IA
├── migrate_data.sh         # Migration des données
├── config/                 # Configuration
│   └── settings.sh         # Paramètres globaux
├── lib/                    # Bibliothèques
│   ├── utils.sh           # Fonctions utilitaires
│   ├── database.sh        # Fonctions base de données
│   ├── enrichment.sh      # Calculs et enrichissements
│   └── best_data.sh       # Sélection des meilleures données
├── apis/                   # APIs disponibles
│   ├── google_books.sh    # Google Books API
│   ├── isbndb.sh          # ISBNdb API
│   ├── open_library.sh    # Open Library API
│   ├── gallica.sh         # Gallica API
│   ├── other_apis.sh      # WorldCat, Archive.org, etc.
│   ├── marketplace_apis.sh # Amazon, Fnac, Decitre, etc.
│   └── groq_ai.sh         # Groq IA
└── logs/                   # Fichiers de logs

```

### Utilisation

#### Lancement rapide
```bash
./run.sh
```

#### Collecte automatique
```bash
./collect_api_data.sh
```

#### Création de fiches complètes
```bash
./martingale.sh
```

#### Test des APIs
```bash
./test_apis.sh
```

### APIs disponibles

1. **APIs principales** (avec données structurées)
   - Google Books
   - ISBNdb (clé API requise)
   - Open Library
   - Gallica

2. **APIs secondaires**
   - WorldCat
   - Archive.org
   - Library of Congress
   - British Library

3. **Marketplaces** (scraping)
   - Amazon
   - Fnac
   - Decitre
   - Babelio
   - Goodreads

4. **IA**
   - Groq (génération de descriptions)

### Fonctionnalités

- ✅ Collecte automatique depuis 20+ sources
- ✅ Martingale de données (chaque API complète les autres)
- ✅ Catégories Vinted automatiques
- ✅ Calcul du poids et dimensions
- ✅ Sélection des meilleures données
- ✅ Export JSON complet
- ✅ Rapports détaillés
- ✅ Logs complets

### Configuration

Éditer `config/settings.sh` pour :
- Clés API (ISBNdb, Groq)
- Base de données MySQL
- Paramètres de collecte

### Données collectées

Pour chaque livre :
- Identifiants : ISBN-10, ISBN-13, OCLC, LCCN
- Bibliographie : titre, auteurs, éditeur, date
- Physique : pages, reliure, dimensions, poids
- Commercial : prix, disponibilité, catégorie Vinted
- Contenu : description, résumé, extraits
- Images : toutes les tailles disponibles
- Classifications : Dewey, BISAC, catégories

EOF

# 10. Nettoyer les anciens logs (garder seulement les 10 derniers)
echo ""
echo "Nettoyage des anciens logs..."
cd logs/
ls -t collect_*.log 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
ls -t report_*.txt 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
cd ..

# 11. Afficher le résumé
echo ""
echo "=== NETTOYAGE TERMINÉ ==="
echo ""
echo "Fichiers conservés :"
echo "  ✓ run.sh                  - Script principal"
echo "  ✓ collect_api_data.sh     - Collecte automatique"
echo "  ✓ martingale.sh          - Fiches complètes"
echo "  ✓ generate_report.sh     - Rapports"
echo "  ✓ test_apis.sh           - Test APIs"
echo "  ✓ test_groq.sh           - Test Groq"
echo "  ✓ migrate_data.sh        - Migration"
echo "  ✓ README.md              - Documentation"
echo "  ✓ config/                - Configuration"
echo "  ✓ lib/                   - Bibliothèques"
echo "  ✓ apis/                  - APIs"
echo "  ✓ logs/                  - Logs récents"
echo "  ✓ book_*_complete.json   - Fiches JSON"
echo ""
echo "Fichiers supprimés : tous les fichiers temporaires et obsolètes"
echo ""
echo "Pour commencer, lancez : ./run.sh"
echo ""
