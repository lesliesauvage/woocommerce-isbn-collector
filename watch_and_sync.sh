#!/bin/bash
# watch_and_sync.sh - Surveillance et synchronisation automatique GitHub

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/logs/watch_sync.log"
SYNC_DELAY=5

mkdir -p "$SCRIPT_DIR/logs"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

if ! command -v inotifywait &> /dev/null; then
    log "❌ inotify-tools n'est pas installé"
    log "Installez-le avec : apt-get install inotify-tools"
    exit 1
fi

SYNC_PID=""
LAST_CHANGE_TIME=0

sync_to_github() {
    if [ -n "$SYNC_PID" ]; then
        kill $SYNC_PID 2>/dev/null
    fi
    
    (
        sleep $SYNC_DELAY
        log "🔄 Synchronisation suite aux changements..."
        ./sync_to_github.sh "Auto-sync: changements détectés" >> "$LOG_FILE" 2>&1
        log "✅ Synchronisation terminée"
    ) &
    SYNC_PID=$!
}

cleanup() {
    log "🛑 Arrêt de la surveillance"
    if [ -n "$SYNC_PID" ]; then
        kill $SYNC_PID 2>/dev/null
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

log "👁️  Démarrage de la surveillance du répertoire ISBN"
log "📁 Répertoire surveillé : $SCRIPT_DIR"
log "⏱️  Délai avant sync : ${SYNC_DELAY}s"
log "🚫 Fichiers ignorés : test_*.sh, *.log, .git/"
log "Appuyez sur Ctrl+C pour arrêter"

inotifywait -mr \
    --exclude '(\.git/|logs/|test_.*\.sh|.*\.log|.*\.swp|.*\.tmp)' \
    --event modify,create,delete,move \
    --format '%w%f %e' \
    "$SCRIPT_DIR" | while read file event
do
    if [[ "$file" =~ test_.*\.sh$ ]] || [[ "$file" =~ \.log$ ]] || [[ "$file" =~ \.git/ ]]; then
        continue
    fi
    
    relative_file=${file#$SCRIPT_DIR/}
    
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
    
    sync_to_github
done
