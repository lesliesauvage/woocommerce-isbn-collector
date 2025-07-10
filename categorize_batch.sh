#!/bin/bash
echo "[START: categorize_batch.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

clear
source config/settings.sh

echo "=== CATÉGORISATION AUTOMATIQUE DE 10 LIVRES ==="
echo "Date : $(date)"
echo "════════════════════════════════════════════════════"
echo ""

# Livres à catégoriser
livres=(16128 16127 16126 16125 16124 16122 16085 16083 16081 16080)

# Compteurs
success=0
failed=0

# Traiter chaque livre
for id in "${livres[@]}"; do
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📚 Livre $id..."
    
    # Lancer la catégorisation
    ./smart_categorize_dual_ai.sh -id $id
    
    if [ $? -eq 0 ]; then
        ((success++))
    else
        ((failed++))
    fi
    
    # Pause de 3 secondes entre chaque
    sleep 3
done

# Rapport final
echo ""
echo "════════════════════════════════════════════════════"
echo "📊 RAPPORT FINAL :"
echo "   ✅ Réussis : $success"
echo "   ❌ Échoués : $failed"
echo ""
echo "Voir les détails dans : logs/dual_ai_categorize.log"
echo ""

# Afficher les dernières catégorisations
echo "📋 DERNIÈRES CATÉGORISATIONS :"
tail -5 logs/dual_ai_categorize.log 2>/dev/null || echo "Pas de logs"

echo ""

echo "[END: categorize_batch.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
