#!/bin/bash
# lib/ai_common.sh - Fonctions communes pour les IA

# Couleurs pour affichage
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
BOLD="\033[1m"
NC="\033[0m" # No Color

# Fonction pour afficher les messages de debug
debug_echo() {
    if [ "$VERBOSE" = "1" ]; then
        echo "$@" >&2
    fi
}

# Fonction pour extraire le texte des réponses JSON des IA
extract_text_from_json() {
    local json="$1"
    local api_type="$2"  # "gemini" ou "claude"
    
    debug_echo "[DEBUG] Extraction pour $api_type..."
    debug_echo "[DEBUG] JSON length: ${#json}"
    
    # Essayer Python en premier
    local result
    if [ "$api_type" = "gemini" ]; then
        result=$(echo "$json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    text = data['candidates'][0]['content']['parts'][0]['text']
    print(text.strip())
except Exception as e:
    print(f'ERREUR: {e}', file=sys.stderr)
" 2>/dev/null)
    else  # claude
        result=$(echo "$json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    text = data['content'][0]['text']
    print(text.strip())
except Exception as e:
    print(f'ERREUR: {e}', file=sys.stderr)
" 2>/dev/null)
    fi
    
    debug_echo "[DEBUG] Result before cleaning: '$result'"
    debug_echo "[DEBUG] Result length: ${#result}"
    
    # Nettoyer le résultat - garder uniquement les chiffres
    result=$(echo "$result" | tr -d '\n\r' | grep -o '[0-9]\+' | head -1)
    
    debug_echo "[DEBUG] Résultat extrait et nettoyé : '$result'"
    debug_echo "[DEBUG] Final length: ${#result}"
    
    echo "$result"
}

# Fonction pour analyser les erreurs API
analyze_api_error() {
    local response="$1"
    local api_name="$2"
    
    # TOUJOURS afficher les erreurs, même en mode -noverbose
    
    # Vérifier quota dépassé
    if echo "$response" | grep -q "quota\|RESOURCE_EXHAUSTED\|exceeded"; then
        echo -e "${RED}❌ ERREUR : Quota $api_name dépassé !${NC}"
        if echo "$response" | grep -q "quotaValue"; then
            local quota=$(echo "$response" | grep -o '"quotaValue":[^,}]*' | cut -d'"' -f4)
            echo -e "${YELLOW}   Limite : $quota requêtes/jour${NC}"
        fi
        # Afficher le message d'erreur complet pour Claude
        if [ "$api_name" = "Claude" ] && echo "$response" | grep -q '"message"'; then
            local error_msg=$(echo "$response" | grep -o '"message":"[^"]*"' | cut -d':' -f2- | tr -d '"')
            echo -e "${YELLOW}   Message : $error_msg${NC}"
        fi
        return 1
    fi
    
    # Vérifier rate limit
    if echo "$response" | grep -q "rate_limit\|too_many_requests"; then
        echo -e "${YELLOW}⚠️  ERREUR : Rate limit $api_name atteint${NC}"
        if echo "$response" | grep -q "retryDelay"; then
            local delay=$(echo "$response" | grep -o '"retryDelay":[^,}]*' | cut -d'"' -f4)
            echo -e "${YELLOW}   Attendre : $delay${NC}"
        fi
        # Message spécifique pour Claude avec détection du rate limit de tokens
        if [ "$api_name" = "Claude" ]; then
            local error_detail=$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null)
            [ -n "$error_detail" ] && echo -e "${YELLOW}   Détail : $error_detail${NC}"
            
            # Si c'est un rate limit de tokens, attendre 60 secondes
            if echo "$response" | grep -q "50,000 input tokens per minute"; then
                echo -e "${YELLOW}⏳ Pause automatique de 60 secondes pour respecter la limite...${NC}"
                for i in {60..1}; do
                    printf "\r${YELLOW}   Reprise dans : %02d secondes${NC}" $i
                    sleep 1
                done
                echo -e "\r${GREEN}✅ Reprise !                                        ${NC}"
                # Retourner un code spécial pour réessayer
                return 2
            fi
        fi
        return 1
    fi
    
    # Vérifier clé invalide
    if echo "$response" | grep -q "invalid_api_key\|authentication_error"; then
        echo -e "${RED}❌ ERREUR : Clé API $api_name invalide !${NC}"
        return 1
    fi
    
    # Vérifier crédit insuffisant
    if echo "$response" | grep -q "insufficient_credits"; then
        echo -e "${RED}❌ ERREUR : Crédits $api_name insuffisants !${NC}"
        echo -e "${YELLOW}   Vérifier : https://console.anthropic.com/billing${NC}"
        return 1
    fi
    
    # Autres erreurs - TOUJOURS afficher pour comprendre
    if echo "$response" | grep -q '"error"'; then
        echo -e "${RED}❌ ERREUR $api_name :${NC}"
        # Extraire et afficher le message d'erreur
        local error_msg=$(echo "$response" | python3 -c "
import json,sys
try:
    d=json.load(sys.stdin)
    if 'error' in d:
        print(d['error'].get('message', str(d['error'])))
except:
    print('Erreur inconnue')
" 2>/dev/null || echo "$response" | grep -o '"message":"[^"]*"' | head -1)
        echo -e "${YELLOW}   $error_msg${NC}"
        
        # En mode verbose, afficher plus de détails
        debug_echo "[DEBUG] Réponse complète : $response"
        return 1
    fi
    
    # Si aucune erreur détectée mais pas de contenu valide
    if ! echo "$response" | grep -q '"content"\|"candidates"'; then
        echo -e "${RED}❌ ERREUR $api_name : Réponse invalide${NC}"
        echo -e "${YELLOW}   Réponse: ${response:0:200}...${NC}"
        return 1
    fi
    
    return 0
}