#!/bin/bash
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
        log "🔄 Synchronisation suite aux changements..."
        ./sync_to_github.sh "Auto-sync: changements détectés" >> "$LOG_FILE" 2>&1
        log "✅ Synchronisation terminée"
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

log "👁️  Démarrage de la surveillance du répertoire ISBN"
log "📁 Répertoire surveillé : $SCRIPT_DIR"
log "⏱️  Délai avant sync : ${SYNC_DELAY}s"
log "🚫 Fichiers ignorés : test_*.sh, *.log, .git/"
log "Appuyez sur Ctrl+C pour arrêter"

# Surveiller les changements
inotifywait -mr \
    --exclude '(\.git/|logs/|test_.*\.sh|.*\.log|.*\.swp|.*\.tmp)' \
    --event modify,create,delete,move \
    --format '%w%f %e' \
    "$SCRIPT_DIR" | while read file event
do
    # Ignorer certains fichiers
    if [[ "$file" =~ test_.*\.sh$ ]] || [[ "$file" =~ \.log$ ]] || [[ "$file" =~ \.git/ ]]; then
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
