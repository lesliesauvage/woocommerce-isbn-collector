#!/bin/bash
# Fonctions utilitaires communes

# Fonction de log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Échapper pour SQL - Version UTF-8 safe
escape_sql() {
    local input="$1"
    input=$(printf '%s' "$input" | sed "s/'/\\\\'/g")
    input="${input//$'\n'/ }"
    input="${input//$'\r'/ }"
    echo "${input:0:4000}"
}

# Fonction pour extraire proprement depuis JSON avec UTF-8
extract_json_value() {
    local json="$1"
    local path="$2"
    local default="${3:-}"
    
    local result=$(echo "$json" | jq -r "$path" 2>/dev/null)
    
    if [ -z "$result" ] || [ "$result" = "null" ]; then
        echo "$default"
    else
        echo "$result"
    fi
}

# Fonction pour extraire un tableau JSON en string
extract_json_array() {
    local json="$1"
    local path="$2"
    local separator="${3:-,}"
    
    local result=$(echo "$json" | jq -r "$path" 2>/dev/null | \
                   grep -v "^$" | \
                   grep -v "^null$" | \
                   tr '\n' "$separator" | \
                   sed "s/${separator}$//" || echo "")
    
    if [ -z "$result" ] || [ "$result" = "null" ]; then
        echo ""
    else
        echo "$result"
    fi
}

# Parser les données retournées par les APIs
parse_api_data() {
    local data="$1"
    local field="$2"
    
    echo "$data" | grep -o "${field}:[^|]*" | cut -d: -f2-
}
