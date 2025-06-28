#!/bin/bash

echo "=== Configuration MySQL sans demande de mot de passe ==="
echo ""

# 1. Récupérer les infos de config actuelles
source /var/www/scripts-home-root/isbn/config/settings.sh

echo "Configuration actuelle :"
echo "  - Utilisateur : $DB_USER"
echo "  - Base : $DB_NAME"
echo ""

# 2. Créer le fichier .my.cnf pour l'utilisateur root
echo "Création du fichier de configuration MySQL..."
cat > ~/.my.cnf << EOF
[client]
host=$DB_HOST
user=$DB_USER
password=$DB_PASSWORD
database=$DB_NAME

[mysql]
host=$DB_HOST
user=$DB_USER
password=$DB_PASSWORD
database=$DB_NAME
EOF

# 3. Sécuriser le fichier
chmod 600 ~/.my.cnf

echo "✓ Fichier ~/.my.cnf créé"

# 4. Mettre à jour tous les scripts pour ne plus utiliser -p"$DB_PASSWORD"
echo ""
echo "Mise à jour des scripts..."

# Fonction pour nettoyer un fichier
clean_mysql_commands() {
    local file=$1
    if [ -f "$file" ]; then
        # Remplacer les commandes mysql avec mot de passe par des commandes sans
        sed -i 's/mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME"/mysql/g' "$file"
        sed -i 's/mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" $DB_NAME/mysql/g' "$file"
        sed -i "s/mysql -h\"\$DB_HOST\" -u\"\$DB_USER\" -p\"\$DB_PASSWORD\" \"\$DB_NAME\"/mysql/g" "$file"
        echo "  ✓ $file"
    fi
}

# Nettoyer tous les fichiers
cd /var/www/scripts-home-root/isbn

# Scripts principaux
clean_mysql_commands "run.sh"
clean_mysql_commands "collect_api_data.sh"
clean_mysql_commands "martingale.sh"
clean_mysql_commands "generate_report.sh"
clean_mysql_commands "migrate_data.sh"

# Librairies
clean_mysql_commands "lib/database.sh"
clean_mysql_commands "lib/enrichment.sh"
clean_mysql_commands "lib/best_data.sh"

# APIs
for api_file in apis/*.sh; do
    clean_mysql_commands "$api_file"
done

echo ""
echo "=== Configuration terminée ! ==="
echo ""
echo "MySQL ne demandera plus le mot de passe !"
echo ""
echo "Test de connexion..."
mysql -e "SELECT 'Connexion OK' as Test;" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✓ Connexion MySQL OK sans mot de passe !"
else
    echo "✗ Erreur de connexion. Vérifiez le fichier ~/.my.cnf"
fi
