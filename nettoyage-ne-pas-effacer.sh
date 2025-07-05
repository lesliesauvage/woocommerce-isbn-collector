#!/bin/bash
# NETTOYER LE PROJET ISBN - COPIER-COLLER UNIQUE
cd /var/www/scripts-home-root/isbn/

cat > cleanup_project.sh << 'CLEANUP_EOF'
#!/bin/bash
clear
echo "=== NETTOYAGE DU PROJET ISBN ==="
echo "Date : $(date)"
echo ""

# Compter avant nettoyage
before_count=$(find . -type f | wc -l)
before_size=$(du -sh . | cut -f1)

echo "📊 ÉTAT ACTUEL"
echo "─────────────"
echo "Nombre de fichiers : $before_count"
echo "Taille totale : $before_size"
echo ""

echo "🗑️  FICHIERS À SUPPRIMER"
echo "─────────────────────"

# 1. Supprimer les fichiers temporaires test_*.sh
echo -n "Fichiers test_*.sh temporaires : "
test_count=$(find . -name "test_*.sh" -type f | wc -l)
echo "$test_count trouvés"
if [ $test_count -gt 0 ]; then
    find . -name "test_*.sh" -type f -delete
    echo "  ✓ Supprimés"
fi

# 2. Supprimer les backups
echo -n "Fichiers backup (.bak*) : "
bak_count=$(find . -name "*.bak*" -o -name "*.old" | wc -l)
echo "$bak_count trouvés"
if [ $bak_count -gt 0 ]; then
    find . -name "*.bak*" -o -name "*.old" -delete
    echo "  ✓ Supprimés"
fi

# 3. Supprimer les fichiers générés
echo -n "Fichiers générés (generer_*) : "
gen_count=$(find . -name "generer_*" -type f | wc -l)
echo "$gen_count trouvés"
if [ $gen_count -gt 0 ]; then
    # Garder les exports récents
    find . -name "generer_*" -type f -mtime +7 -delete
    echo "  ✓ Supprimés (> 7 jours)"
fi

# 4. Nettoyer les logs anciens
echo -n "Logs anciens (> 30 jours) : "
if [ -d "logs" ]; then
    old_logs=$(find logs/ -name "*.log" -mtime +30 | wc -l)
    echo "$old_logs trouvés"
    if [ $old_logs -gt 0 ]; then
        find logs/ -name "*.log" -mtime +30 -delete
        echo "  ✓ Supprimés"
    fi
fi

# 5. Supprimer les fichiers vides
echo -n "Fichiers vides : "
empty_count=$(find . -type f -empty | wc -l)
echo "$empty_count trouvés"
if [ $empty_count -gt 0 ]; then
    find . -type f -empty -delete
    echo "  ✓ Supprimés"
fi

# 6. Nettoyer le dossier counters s'il existe
if [ -d "counters" ]; then
    echo "Dossier counters : supprimé"
    rm -rf counters/
fi

# 7. Supprimer les scripts obsolètes connus
obsolete_scripts=(
    "collect_single_book.sh"
    "fix_v2.sh"
    "patch.sh"
    "collect_temp.sh"
    "migrate_data.sh"
    "test_apis.sh"
    "test_groq.sh"
)

echo ""
echo "Scripts obsolètes :"
for script in "${obsolete_scripts[@]}"; do
    if [ -f "$script" ]; then
        rm -f "$script"
        echo "  ✓ $script supprimé"
    fi
done

# 8. Nettoyer exports/output des fichiers anciens
if [ -d "exports/output" ]; then
    echo ""
    echo -n "Fichiers export anciens (> 30 jours) : "
    old_exports=$(find exports/output/ -name "generer_*.csv" -mtime +30 | wc -l)
    echo "$old_exports trouvés"
    if [ $old_exports -gt 0 ]; then
        find exports/output/ -name "generer_*.csv" -mtime +30 -delete
        echo "  ✓ Supprimés"
    fi
fi

# Résultat final
echo ""
echo "📊 RÉSULTAT DU NETTOYAGE"
echo "───────────────────────"
after_count=$(find . -type f | wc -l)
after_size=$(du -sh . | cut -f1)

echo "Avant : $before_count fichiers ($before_size)"
echo "Après : $after_count fichiers ($after_size)"
echo "Fichiers supprimés : $((before_count - after_count))"

# Afficher la structure finale
echo ""
echo "📁 STRUCTURE FINALE DU PROJET"
echo "────────────────────────────"
tree -d -L 2 2>/dev/null || find . -type d -maxdepth 2 | sort

echo ""
echo "✅ NETTOYAGE TERMINÉ"

# Proposer de créer un backup du projet nettoyé
echo ""
echo "💾 Créer un backup du projet nettoyé ? (recommandé)"
echo "Le backup sera créé dans : /var/www/scripts-home-root/isbn_backup_$(date +%Y%m%d).tar.gz"
echo ""
echo "Tapez 'oui' pour créer le backup :"
read response

if [ "$response" = "oui" ]; then
    cd ..
    tar -czf "isbn_backup_$(date +%Y%m%d).tar.gz" isbn/
    echo "✅ Backup créé : isbn_backup_$(date +%Y%m%d).tar.gz"
fi
CLEANUP_EOF

chmod +x cleanup_project.sh
./cleanup_project.sh
rm -f cleanup_project.sh
