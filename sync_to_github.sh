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

# Fonction de nettoyage préventif
pre_sync_clean() {
    log "🧹 Nettoyage préventif..."
    
    # Supprimer les fichiers sensibles
    find . -name "credentials.sh.bak*" -type f -delete 2>/dev/null
    find . -name "*.bak.*" -type f -delete 2>/dev/null
    
    # Les retirer de l'index Git s'ils y sont
    git rm --cached config/credentials.sh.bak.* 2>/dev/null || true
    git rm --cached config/*.bak.* 2>/dev/null || true
    git rm --cached *secret* 2>/dev/null || true
    
    # Vérifier qu'aucun fichier sensible n'est dans l'index
    local sensitive_files=$(git ls-files | grep -E "(credentials|secret|password|key|\.bak)" || true)
    if [ -n "$sensitive_files" ]; then
        log "⚠️  Fichiers sensibles détectés dans l'index Git:"
        echo "$sensitive_files" | while read f; do
            log "   - $f"
            git rm --cached "$f" 2>/dev/null || true
        done
    fi
}

# Vérifier si on est dans un dépôt Git
if [ ! -d ".git" ]; then
    log "❌ ERREUR : Pas de dépôt Git trouvé dans $SCRIPT_DIR"
    log "Initialiser avec : git init && git remote add origin https://github.com/VOTRE_USER/VOTRE_REPO.git"
    exit 1
fi

# Début de la synchronisation
log "🚀 Début de la synchronisation GitHub"

# Nettoyage préventif
pre_sync_clean

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

# Vérifier la présence de fichiers sensibles dans les changements
if echo "$STATUS" | grep -E "(credentials|secret|password|key|\.bak)" >/dev/null; then
    log "⚠️  ATTENTION : Fichiers potentiellement sensibles détectés"
    log "Exclusion automatique de ces fichiers..."
    
    # Exclure ces fichiers
    echo "$STATUS" | grep -E "(credentials|secret|password|key|\.bak)" | awk '{print $2}' | while read f; do
        git reset HEAD "$f" 2>/dev/null || true
        log "   Exclu : $f"
    done
    
    # Revérifier le status
    STATUS=$(git status --porcelain)
    if [ -z "$STATUS" ]; then
        log "✅ Plus rien à synchroniser après exclusion"
        exit 0
    fi
fi

# Ajouter tous les fichiers SAUF les sensibles
log "📁 Ajout des fichiers..."
git add -A
git reset HEAD config/credentials.sh 2>/dev/null || true
git reset HEAD config/credentials.sh.bak.* 2>/dev/null || true
git reset HEAD config/*.bak 2>/dev/null || true

if [ $? -ne 0 ]; then
    log "❌ ERREUR lors de git add"
    exit 1
fi

# Message de commit
if [ -n "$1" ]; then
    COMMIT_MSG="$1"
else
    # Message automatique avec statistiques
    ADDED=$(echo "$STATUS" | grep -c "^A" || true)
    MODIFIED=$(echo "$STATUS" | grep -c "^M" || true)
    DELETED=$(echo "$STATUS" | grep -c "^D" || true)
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

# Push avec gestion d'erreur améliorée
log "⬆️  Push vers GitHub..."
PUSH_OUTPUT=$(git push origin "$BRANCH" 2>&1)
PUSH_RESULT=$?

if [ $PUSH_RESULT -ne 0 ]; then
    echo "$PUSH_OUTPUT" >> "$LOG_FILE"
    
    # Vérifier si c'est une erreur de secret
    if echo "$PUSH_OUTPUT" | grep -q "secret\|declined"; then
        log "❌ ERREUR : GitHub a détecté des secrets dans l'historique"
        log "🔧 Tentative de nettoyage automatique..."
        
        # Identifier le commit problématique
        PROBLEM_COMMIT=$(echo "$PUSH_OUTPUT" | grep -oE "commit: [a-f0-9]+" | head -1 | cut -d' ' -f2)
        
        if [ -n "$PROBLEM_COMMIT" ]; then
            log "Commit problématique : $PROBLEM_COMMIT"
            
            # Option 1: Essayer de nettoyer avec filter-branch
            log "Nettoyage de l'historique..."
            git filter-branch --force --index-filter \
                'git rm --cached --ignore-unmatch config/credentials.sh.bak.* config/*.bak* *secret*' \
                --prune-empty --tag-name-filter cat -- --all
            
            # Réessayer le push forcé
            log "Tentative de push forcé..."
            git push origin "$BRANCH" --force 2>&1 | tee -a "$LOG_FILE"
            
            if [ ${PIPESTATUS[0]} -eq 0 ]; then
                log "✅ Synchronisation forcée réussie après nettoyage"
            else
                log "❌ Échec du push forcé"
                log "ACTION MANUELLE REQUISE :"
                log "1. Allez sur : https://github.com/lesliesauvage/woocommerce-isbn-collector/security/secret-scanning"
                log "2. Débloquez le secret ou supprimez le commit problématique"
                log "3. Ou utilisez le script fix_git_history.sh"
                exit 1
            fi
        fi
    else
        log "❌ ERREUR lors du push (autre que secret)"
        log "Vérifiez les logs : $LOG_FILE"
        exit 1
    fi
else
    # Push réussi
    echo "$PUSH_OUTPUT" >> "$LOG_FILE"
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