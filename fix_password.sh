#!/bin/bash

echo "=== Fix MySQL - Version Simple ==="
echo ""

# Charger la config
source /var/www/scripts-home-root/isbn/config/settings.sh

echo "Test du mot de passe actuel..."

# Tester la connexion
mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1;" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "❌ Le mot de passe dans config/settings.sh ne fonctionne pas !"
    echo ""
    echo "Vérification du mot de passe WordPress..."
    
    # Récupérer le mot de passe depuis wp-config.php
    WP_PASS=$(grep "DB_PASSWORD" /var/www/html/wp-config.php | cut -d "'" -f 4)
    
    if [ ! -z "$WP_PASS" ]; then
        echo "Mot de passe trouvé dans WordPress : $WP_PASS"
        echo ""
        echo "Mise à jour de la configuration..."
        
        # Mettre à jour le fichier de config
        sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=\"$WP_PASS\"/" /var/www/scripts-home-root/isbn/config/settings.sh
        
        echo "✓ Configuration mise à jour !"
    else
        echo "Impossible de trouver le mot de passe WordPress."
        echo "Entrez le mot de passe MySQL manuellement :"
        read -s mysql_password
        
        # Mettre à jour le fichier
        sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=\"$mysql_password\"/" /var/www/scripts-home-root/isbn/config/settings.sh
        
        echo "✓ Mot de passe sauvegardé !"
    fi
else
    echo "✓ Le mot de passe fonctionne déjà !"
fi

echo ""
echo "=== Configuration terminée ==="
echo ""
echo "Lancez maintenant : ./run.sh"
