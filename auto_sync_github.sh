#!/bin/bash
# auto_sync_github.sh - Synchronisation automatique silencieuse

cd /var/www/scripts-home-root/isbn/
./sync_to_github.sh "Sync automatique $(date '+%Y-%m-%d %H:%M')" > /dev/null 2>&1
