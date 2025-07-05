#!/bin/bash
# sync_to_github.sh - Synchronisation automatique vers GitHub
# Usage: ./sync_to_github.sh [message_commit_optionnel]

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/sync_github.log"
BRANCH="main"  # ou "master" selon votre configuration

# Créer le dossier logs si nécessaire
mkdir -p "$SCRIPT_DIR/logs"

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérifier si on est dans un dépôt Git
if [ ! -d ".git" ]; then
    log "❌ ERREUR : Pas de dépôt Git trouvé dans $SCRIPT_DIR"
    log "Initialiser avec : git init && git remote add origin https://github.com/VOTRE_USER/VOTRE_REPO.git"
    exit 1
fi

# Début de la synchronisation
log "🚀 Début de la synchronisation GitHub"

# Récupérer le status
STATUS=$(git status --porcelain)
if [ -z "$STATUS" ]; then
    log "✅ Aucun changement à synchroniser"
    exit 0
fi

# Afficher les changements
log "📋 Changements détectés :"
echo "$STATUS" | while read line; do
    log "   $line"
done

# Ajouter tous les fichiers
log "📁 Ajout des fichiers..."
git add -A
if [ $? -ne 0 ]; then
    log "❌ ERREUR lors de git add"
    exit 1
fi

# Message de commit
if [ -n "$1" ]; then
    COMMIT_MSG="$1"
else
    # Message automatique avec statistiques
    ADDED=$(echo "$STATUS" | grep -c "^A")
    MODIFIED=$(echo "$STATUS" | grep -c "^M")
    DELETED=$(echo "$STATUS" | grep -c "^D")
    COMMIT_MSG="Sync auto: +$ADDED fichiers, ~$MODIFIED modifiés, -$DELETED supprimés"
fi

# Commit
log "💾 Commit : $COMMIT_MSG"
git commit -m "$COMMIT_MSG" >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    log "❌ ERREUR lors du commit"
    exit 1
fi

# Pull avant push pour éviter les conflits
log "⬇️  Pull des changements distants..."
git pull origin "$BRANCH" --rebase >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    log "⚠️  Conflits détectés lors du pull"
    log "Résolvez les conflits puis relancez le script"
    exit 1
fi

# Push
log "⬆️  Push vers GitHub..."
git push origin "$BRANCH" >> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then
    log "❌ ERREUR lors du push"
    log "Vérifiez votre connexion et vos credentials GitHub"
    exit 1
fi

# Résumé final
COMMIT_HASH=$(git rev-parse --short HEAD)
log "✅ Synchronisation réussie ! Commit: $COMMIT_HASH"

# Afficher les derniers commits
log "📊 Derniers commits :"
git log --oneline -5 | while read line; do
    log "   $line"
done

# Nettoyer les vieux logs (garder 30 jours)
find "$SCRIPT_DIR/logs" -name "sync_github.log*" -mtime +30 -delete 2>/dev/null

log "🏁 Fin de la synchronisation"
echo ""
