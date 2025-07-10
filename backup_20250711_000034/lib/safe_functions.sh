#!/bin/bash
# lib/safe_functions.sh - Fonctions sécurisées pour éviter les bugs courants
# Usage: source lib/safe_functions.sh

# Échapper les apostrophes pour MySQL
# Entrée: Chaîne avec possibles apostrophes
# Sortie: Chaîne échappée pour MySQL
# Exemple: safe_sql "L'étranger" → "L\'étranger"
safe_sql() {
    local input="$1"
    echo "$input" | sed "s/'/\\\\'/g"
}

# Stocker une métadonnée de façon sécurisée
# Params: $1=post_id, $2=meta_key, $3=meta_value
# Retour: 0 si succès, 1 si erreur
safe_store_meta() {
    local post_id="$1"
    local meta_key="$2"
    local meta_value="$3"
    
    # Validations
    [ -z "$post_id" ] && { echo "❌ safe_store_meta: post_id manquant" >&2; return 1; }
    [ -z "$meta_key" ] && { echo "❌ safe_store_meta: meta_key manquante" >&2; return 1; }
    
    # Échapper la valeur
    local escaped_value=$(safe_sql "$meta_value")
    
    # D'abord vérifier si la clé existe
    local existing=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "
        SELECT meta_id FROM wp_${SITE_ID}_postmeta 
        WHERE post_id = '$post_id' AND meta_key = '$meta_key' 
        LIMIT 1" 2>/dev/null)
    
    if [ -n "$existing" ]; then
        # UPDATE si existe
        if mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            UPDATE wp_${SITE_ID}_postmeta 
            SET meta_value = '$escaped_value'
            WHERE post_id = '$post_id' AND meta_key = '$meta_key'" 2>/dev/null; then
            
            [ "$DEBUG" = "1" ] && echo "[DEBUG] Mis à jour: $meta_key = ${meta_value:0:50}..." >&2
            return 0
        else
            echo "❌ Erreur UPDATE: $meta_key" >&2
            return 1
        fi
    else
        # INSERT si n'existe pas
        if mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "
            INSERT INTO wp_${SITE_ID}_postmeta (post_id, meta_key, meta_value)
            VALUES ('$post_id', '$meta_key', '$escaped_value')" 2>/dev/null; then
            
            [ "$DEBUG" = "1" ] && echo "[DEBUG] Inséré: $meta_key = ${meta_value:0:50}..." >&2
            return 0
        else
            echo "❌ Erreur INSERT: $meta_key" >&2
            return 1
        fi
    fi
}

# Exécuter une requête MySQL de façon sécurisée
# Param: $1=requête SQL
# Sortie: Résultat de la requête
# Retour: 0 si succès, 1 si erreur
safe_mysql() {
    local query="$1"
    local result
    
    [ -z "$query" ] && { echo "❌ safe_mysql: requête vide" >&2; return 1; }
    
    result=$(mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -sN -e "$query" 2>/dev/null)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "$result"
        return 0
    else
        [ "$DEBUG" = "1" ] && echo "[DEBUG] Erreur MySQL (code $exit_code): $query" >&2
        return 1
    fi
}

# Valider et nettoyer un ISBN
# Entrée: ISBN avec ou sans tirets/espaces
# Sortie: ISBN nettoyé (10 ou 13 chiffres)
# Retour: 0 si valide, 1 si invalide
validate_isbn() {
    local isbn_input="$1"
    
    # Enlever tout sauf les chiffres
    local isbn_clean="${isbn_input//[^0-9]/}"
    
    # Vérifier longueur (10 ou 13)
    if [[ "$isbn_clean" =~ ^[0-9]{10}$ ]] || [[ "$isbn_clean" =~ ^[0-9]{13}$ ]]; then
        echo "$isbn_clean"
        return 0
    else
        [ "$DEBUG" = "1" ] && echo "[DEBUG] ISBN invalide: $isbn_input → $isbn_clean" >&2
        return 1
    fi
}

# Vérifier l'environnement au démarrage
# Retour: 0 si OK, nombre d'erreurs sinon
check_environment() {
    local errors=0
    
    # Vérifier les variables essentielles
    for var in DB_HOST DB_USER DB_PASSWORD DB_NAME SITE_ID SCRIPT_DIR; do
        if [ -z "${!var}" ]; then
            echo "❌ Variable manquante: $var" >&2
            ((errors++))
        fi
    done
    
    # Vérifier la connexion MySQL
    if [ $errors -eq 0 ]; then
        if ! mysql -h"$DB_HOST" -u"$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1" >/dev/null 2>&1; then
            echo "❌ Connexion MySQL impossible" >&2
            ((errors++))
        fi
    fi
    
    # Créer le dossier logs si nécessaire
    if [ ! -d "$SCRIPT_DIR/logs" ]; then
        mkdir -p "$SCRIPT_DIR/logs" 2>/dev/null || echo "⚠️  Impossible de créer logs/" >&2
    fi
    
    [ "$DEBUG" = "1" ] && [ $errors -gt 0 ] && echo "[DEBUG] check_environment: $errors erreur(s)" >&2
    
    return $errors
}

# Logger une action (pour traçabilité)
# Params: $1=action, $2=message
log_action() {
    local action="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local log_file="$SCRIPT_DIR/logs/isbn_$(date '+%Y%m%d').log"
    
    # Créer le dossier si nécessaire
    [ ! -d "$SCRIPT_DIR/logs" ] && mkdir -p "$SCRIPT_DIR/logs" 2>/dev/null
    
    # Logger dans le fichier
    echo "[$timestamp] [$action] $message" >> "$log_file" 2>/dev/null
    
    # Afficher aussi en mode DEBUG
    [ "$DEBUG" = "1" ] && echo "[LOG] $action: $message" >&2
}

# Récupérer une métadonnée de façon sécurisée
# Params: $1=post_id, $2=meta_key
# Sortie: La valeur de la métadonnée
safe_get_meta() {
    local post_id="$1"
    local meta_key="$2"
    
    [ -z "$post_id" ] || [ -z "$meta_key" ] && return 1
    
    safe_mysql "SELECT meta_value FROM wp_${SITE_ID}_postmeta 
                WHERE post_id='$post_id' AND meta_key='$meta_key' LIMIT 1"
}

# Vérifier si un livre existe déjà
# Param: $1=ISBN
# Sortie: post_id si existe, vide sinon
check_book_exists() {
    local isbn="$1"
    
    isbn=$(validate_isbn "$isbn") || return 1
    
    safe_mysql "SELECT post_id FROM wp_${SITE_ID}_postmeta 
                WHERE meta_key='_isbn' AND meta_value='$isbn' LIMIT 1"
}

# === AUTO-TEST ===
# Lancer avec: ./lib/safe_functions.sh --test
if [ "${1:-}" = "--test" ]; then
    echo "=== TEST lib/safe_functions.sh ==="
    echo ""
    
    # Charger les settings pour les tests
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [ -f "$SCRIPT_DIR/config/settings.sh" ]; then
        source "$SCRIPT_DIR/config/settings.sh"
    else
        echo "⚠️  config/settings.sh non trouvé, certains tests seront skippés"
    fi
    
    # Test 1: safe_sql
    echo -n "Test safe_sql avec apostrophe... "
    result=$(safe_sql "L'étranger de Camus")
    expected="L\\'étranger de Camus"
    [ "$result" = "$expected" ] && echo "✓ PASS" || echo "❌ FAIL (obtenu: $result)"
    
    # Test 2: validate_isbn
    echo -n "Test validate_isbn ISBN-13... "
    result=$(validate_isbn "978-2-07-036822-8")
    [ "$result" = "9782070368228" ] && echo "✓ PASS" || echo "❌ FAIL"
    
    echo -n "Test validate_isbn ISBN-10... "
    result=$(validate_isbn "2-901821-03-0")
    [ "$result" = "2901821030" ] && echo "✓ PASS" || echo "❌ FAIL"
    
    echo -n "Test validate_isbn invalide... "
    validate_isbn "123" >/dev/null 2>&1
    [ $? -ne 0 ] && echo "✓ PASS" || echo "❌ FAIL"
    
    # Test 3: check_environment (si settings chargé)
    if [ -n "${DB_HOST:-}" ]; then
        echo -n "Test check_environment... "
        check_environment >/dev/null 2>&1
        [ $? -eq 0 ] && echo "✓ PASS" || echo "❌ FAIL"
        
        # Test 4: safe_mysql
        echo -n "Test safe_mysql... "
        result=$(safe_mysql "SELECT 1")
        [ "$result" = "1" ] && echo "✓ PASS" || echo "❌ FAIL"
    else
        echo "⚠️  Tests MySQL skippés (pas de config)"
    fi
    
    echo ""
    echo "=== FIN DES TESTS ==="
    exit 0
fi