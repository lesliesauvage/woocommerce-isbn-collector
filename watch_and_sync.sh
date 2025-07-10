#!/bin/bash
echo "[START: watch_and_sync.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# watch_and_sync.sh - Surveillance et synchronisation automatique GitHub
# Lance une sync dès qu'un fichier est modifié

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/watch_sync.log"
SYNC_DELAY=5  # Attendre 5 secondes après le dernier changement

# Créer le dossier logs si nécessaire
mkdir -p "$SCRIPT_DIR/logs"

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Fonction de nettoyage des fichiers sensibles
clean_sensitive_files() {
    # Supprimer tous les backups de credentials
    find "$SCRIPT_DIR" -name "credentials.sh.bak*" -type f -delete 2>/dev/null
    find "$SCRIPT_DIR" -name "*.bak.*" -type f -delete 2>/dev/null
    find "$SCRIPT_DIR" -name "*secret*" -type f -not -path "*/.git/*" -delete 2>/dev/null
    
    # Supprimer de l'index git si présent
    cd "$SCRIPT_DIR"
    git rm --cached config/credentials.sh.bak.* 2>/dev/null || true
    git rm --cached config/*.bak 2>/dev/null || true
}

# Vérifier si inotify-tools est installé
if ! command -v inotifywait &> /dev/null; then
    log "❌ inotify-tools n'est pas installé"
    log "Installez-le avec : apt-get install inotify-tools"
    exit 1
fi

# PID du processus de synchronisation en cours
SYNC_PID=""
LAST_CHANGE_TIME=0

# Fonction de synchronisation
sync_to_github() {
    # Annuler la sync précédente si elle est en attente
    if [ -n "$SYNC_PID" ]; then
        kill $SYNC_PID 2>/dev/null
    fi
    
    # Lancer la sync après un délai
    (
        sleep $SYNC_DELAY
        log "🧹 Nettoyage des fichiers sensibles..."
        clean_sensitive_files
        
        log "🔄 Synchronisation suite aux changements..."
        cd "$SCRIPT_DIR"
        ./sync_to_github.sh "Auto-sync: changements détectés" >> "$LOG_FILE" 2>&1
        SYNC_RESULT=$?
        
        if [ $SYNC_RESULT -eq 0 ]; then
            log "✅ Synchronisation terminée avec succès"
        else
            log "❌ Erreur lors de la synchronisation (code: $SYNC_RESULT)"
            log "Tentative de résolution automatique..."
            
            # Si erreur de push à cause de secrets
            if grep -q "secret" "$LOG_FILE" || grep -q "declined" "$LOG_FILE"; then
                log "🔧 Détection de secrets, nettoyage de l'historique Git..."
                cd "$SCRIPT_DIR"
                
                # Nettoyer l'historique
                git filter-branch --force --index-filter \
                    "git rm --cached --ignore-unmatch config/credentials.sh.bak.* config/*.bak" \
                    --prune-empty --tag-name-filter cat -- --all 2>/dev/null
                
                # Forcer le push
                git push origin main --force 2>&1 | tee -a "$LOG_FILE"
                
                if [ ${PIPESTATUS[0]} -eq 0 ]; then
                    log "✅ Historique nettoyé et synchronisé"
                else
                    log "❌ Impossible de nettoyer l'historique automatiquement"
                    log "Action manuelle requise : voir $LOG_FILE"
                fi
            fi
        fi
    ) &
    SYNC_PID=$!
}

# Fonction pour nettoyer à la sortie
cleanup() {
    log "🛑 Arrêt de la surveillance"
    if [ -n "$SYNC_PID" ]; then
        kill $SYNC_PID 2>/dev/null
    fi
    exit 0
}

# Capturer les signaux pour un arrêt propre
trap cleanup SIGINT SIGTERM

# Nettoyage initial
log "🧹 Nettoyage initial des fichiers sensibles..."
clean_sensitive_files

log "👁️  Démarrage de la surveillance du répertoire ISBN"
log "📁 Répertoire surveillé : $SCRIPT_DIR"
log "⏱️  Délai avant sync : ${SYNC_DELAY}s"
log "🚫 Fichiers ignorés : test_*.sh, *.log, .git/, *.bak*, credentials.sh"
log "Appuyez sur Ctrl+C pour arrêter"

# Surveiller les changements avec exclusions améliorées
inotifywait -mr \
    --exclude '(\.git/|logs/|test_.*\.sh|.*\.log|.*\.swp|.*\.tmp|.*\.bak.*|credentials\.sh|.*secret.*)' \
    --event modify,create,delete,move \
    --format '%w%f %e' \
    "$SCRIPT_DIR" | while read file event
do
    # Ignorer certains fichiers (double vérification)
    if [[ "$file" =~ test_.*\.sh$ ]] || \
       [[ "$file" =~ \.log$ ]] || \
       [[ "$file" =~ \.git/ ]] || \
       [[ "$file" =~ \.bak ]] || \
       [[ "$file" =~ credentials\.sh ]] || \
       [[ "$file" =~ secret ]]; then
        continue
    fi
    
    # Extraire le nom du fichier relatif
    relative_file=${file#$SCRIPT_DIR/}
    
    # Logger le changement
    case $event in
        CREATE*)
            log "➕ Créé : $relative_file"
            ;;
        MODIFY*)
            log "✏️  Modifié : $relative_file"
            ;;
        DELETE*)
            log "🗑️  Supprimé : $relative_file"
            ;;
        MOVED*)
            log "📋 Déplacé : $relative_file"
            ;;
    esac
    
    # Déclencher la synchronisation
    sync_to_github
done
echo "[END: watch_and_sync.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
