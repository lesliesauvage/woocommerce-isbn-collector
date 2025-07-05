#!/bin/bash
# setup_github.sh - Configuration initiale du dépôt GitHub

echo "=== CONFIGURATION GITHUB ==="
echo ""

# Vérifier si Git est installé
if ! command -v git &> /dev/null; then
    echo "❌ Git n'est pas installé. Installez-le avec : apt-get install git"
    exit 1
fi

# Configuration de base
echo "📝 Configuration Git..."
read -p "Votre nom : " GIT_NAME
read -p "Votre email : " GIT_EMAIL

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"

# Initialiser le dépôt si nécessaire
if [ ! -d ".git" ]; then
    echo "🔧 Initialisation du dépôt Git..."
    git init
    git branch -M main
fi

# Ajouter le remote
echo ""
echo "🔗 Configuration du dépôt distant..."
echo "Format : https://github.com/USERNAME/REPOSITORY.git"
read -p "URL du dépôt GitHub : " REPO_URL

git remote add origin "$REPO_URL" 2>/dev/null || {
    echo "Remote 'origin' existe déjà. Mise à jour..."
    git remote set-url origin "$REPO_URL"
}

# Créer .gitignore
cat > .gitignore << 'GITIGNORE'
# Logs
logs/
*.log

# Temporaires
test_*.sh
*.tmp
*.bak

# Configuration sensible
config/credentials.sh
config/secrets.sh

# Base de données
*.sql
backups/

# Système
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
GITIGNORE

echo ""
echo "✅ Configuration terminée !"
echo ""
echo "📋 Prochaines étapes :"
echo "1. Créez le dépôt sur GitHub : https://github.com/new"
echo "2. Lancez : ./sync_to_github.sh 'Premier commit'"
echo ""
echo "🔐 Pour éviter de taper le mot de passe :"
echo "Utilisez un token : https://github.com/settings/tokens"
echo "git config credential.helper store"
