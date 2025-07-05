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

# Test sync Sat Jul  5 21:11:38 CEST 2025
