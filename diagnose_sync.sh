#!/bin/bash
clear
echo "=== DIAGNOSTIC SYNCHRONISATION GITHUB ==="
echo "Date : $(date)"
echo ""

# 1. Vérifier le service
echo "1️⃣ STATUS DU SERVICE"
echo "════════════════════"
sudo systemctl status isbn-watch-sync --no-pager | head -20
echo ""

# 2. Vérifier Git
echo "2️⃣ CONFIGURATION GIT"
echo "════════════════════"
cd /var/www/scripts-home-root/isbn/
echo "Remote URL:"
git remote -v
echo ""
echo "Branch actuelle:"
git branch --show-current
echo ""
echo "Status:"
git status --short
echo ""

# 3. Vérifier les logs
echo "3️⃣ DERNIERS LOGS DE SYNC"
echo "════════════════════════"
if [ -f logs/sync_github.log ]; then
    tail -20 logs/sync_github.log
else
    echo "❌ Pas de log de sync trouvé"
fi
echo ""

# 4. Vérifier inotify
echo "4️⃣ INOTIFY-TOOLS"
echo "════════════════"
if command -v inotifywait &> /dev/null; then
    echo "✅ inotify-tools installé"
    echo "Limites inotify:"
    cat /proc/sys/fs/inotify/max_user_watches
else
    echo "❌ inotify-tools NON installé"
fi
echo ""

# 5. Test de connexion GitHub
echo "5️⃣ TEST CONNEXION GITHUB"
echo "════════════════════════"
timeout 5 git ls-remote origin >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Connexion GitHub OK"
else
    echo "❌ Impossible de se connecter à GitHub"
    echo "Erreur:"
    git ls-remote origin 2>&1 | head -5
fi
echo ""

# 6. Différences avec GitHub
echo "6️⃣ DIFFÉRENCES AVEC GITHUB"
echo "═════════════════════════"
git fetch origin >/dev/null 2>&1
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main 2>/dev/null || git rev-parse origin/master 2>/dev/null)

if [ "$LOCAL" = "$REMOTE" ]; then
    echo "✅ Synchronisé avec GitHub"
else
    echo "⚠️  Désynchronisé !"
    echo "Commits locaux non pushés:"
    git log origin/main..HEAD --oneline 2>/dev/null || git log origin/master..HEAD --oneline 2>/dev/null
fi
echo ""

# 7. Fichiers modifiés non synchronisés
echo "7️⃣ FICHIERS MODIFIÉS"
echo "═══════════════════"
CHANGES=$(git status --porcelain)
if [ -z "$CHANGES" ]; then
    echo "✅ Aucun changement local"
else
    echo "⚠️  Changements non commités:"
    echo "$CHANGES"
fi

echo ""
echo "📋 ACTIONS RECOMMANDÉES:"
echo "═════════════════════"

# Recommandations
if ! systemctl is-active --quiet isbn-watch-sync; then
    echo "• Démarrer le service: sudo systemctl start isbn-watch-sync"
fi

if [ -n "$CHANGES" ]; then
    echo "• Synchroniser manuellement: ./sync_to_github.sh 'Sync manuelle'"
fi

if [ "$LOCAL" != "$REMOTE" ]; then
    echo "• Pousser les commits: git push origin main"
fi

echo ""
