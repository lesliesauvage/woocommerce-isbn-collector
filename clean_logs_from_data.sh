#!/bin/bash
source config/settings.sh

clean_all_logs() {
    # Enlever tous les timestamps et logs
    echo "$1" | \
    sed 's/\[2025-[0-9-]* [0-9:]*\][^[]*//g' | \
    sed 's/\[DEBUG\][^[]*//g' | \
    sed 's/→ Groq IA[^[]*//g' | \
    sed 's/✓ Groq IA[^[]*//g' | \
    tr '\n\r\t' ' ' | \
    sed 's/  */ /g' | \
    sed 's/^ *//;s/ *$//'
}

# Tester
test_data="[2025-07-07 20:34:44] → Groq IA (génération gratuite)...
[2025-07-07 20:34:45] ✓ Groq IA : description générée
Découvrez le roman inspirant"

echo "AVANT : [$test_data]"
echo ""
echo "APRÈS : [$(clean_all_logs "$test_data")]"
