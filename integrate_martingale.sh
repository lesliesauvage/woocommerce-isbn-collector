#!/bin/bash
clear
source config/settings.sh

echo "=== INTÉGRATION MARTINGALE COMPLÈTE DANS ISBN_UNIFIED.SH ==="
echo "⚠️  Ce script va :"
echo "   1. Sauvegarder isbn_unified.sh"
echo "   2. Ajouter le source de lib/martingale_complete.sh"
echo "   3. Remplacer apply_complete_martingale_metadata par enrich_metadata_complete"
echo "   4. Ajouter l'affichage complet de la martingale"
echo ""
echo "Tapez 'oui' pour continuer :"
read confirmation
[ "$confirmation" != "oui" ] && { echo "❌ Annulé"; exit 0; }

# Sauvegarder
cp isbn_unified.sh isbn_unified.sh.bak_$(date +%Y%m%d_%H%M%S)
echo "✅ Sauvegarde créée"

# 1. Ajouter le source de martingale_complete.sh après les autres sources
echo "📝 Ajout du source lib/martingale_complete.sh..."
sed -i '/source.*leboncoin.sh/a source "$SCRIPT_DIR/lib/martingale_complete.sh"' isbn_unified.sh

# 2. Remplacer l'appel à apply_complete_martingale_metadata par enrich_metadata_complete
echo "📝 Remplacement de apply_complete_martingale_metadata..."
sed -i 's/apply_complete_martingale_metadata "$id"/enrich_metadata_complete "$id" "$isbn"/g' isbn_unified.sh

# 3. Ajouter l'affichage de la martingale complète après la vérification finale
echo "📝 Ajout de l'affichage martingale complète..."

# Créer un fichier temporaire avec les modifications
cat > temp_modifications.txt << 'MODS_EOF'
    
    # === AFFICHAGE MARTINGALE COMPLÈTE ===
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then
        echo ""
        echo ""
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"
        
        # Appeler la fonction d'affichage complète de lib/martingale_complete.sh
        display_martingale_complete "$id"
    fi
}
MODS_EOF

# Chercher où insérer l'affichage (après la vérification martingale)
# On va l'ajouter juste avant la fin de la fonction process_single_book
sed -i '/^}$/i\
    \
    # === AFFICHAGE MARTINGALE COMPLÈTE ===\
    if [ "$MODE" != "simple" ] && [ "$MODE" != "nostatus" ]; then\
        echo ""\
        echo ""\
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"\
        echo -e "${BOLD}${PURPLE}📊 MARTINGALE COMPLÈTE (156 CHAMPS)${NC}"\
        echo "══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════"\
        \
        # Appeler la fonction d'"'"'affichage complète de lib/martingale_complete.sh\
        display_martingale_complete "$id"\
    fi' isbn_unified.sh

# 4. Commenter l'ancienne fonction apply_complete_martingale_metadata
echo "📝 Commentaire de l'ancienne fonction..."
sed -i '/^apply_complete_martingale_metadata() {/,/^}$/s/^/# /' isbn_unified.sh

# 5. Vérifier les modifications
echo ""
echo "✅ Modifications appliquées !"
echo ""
echo "🔍 Vérifications :"
echo -n "   - Source martingale_complete.sh ajouté : "
grep -q 'source.*martingale_complete.sh' isbn_unified.sh && echo "✅" || echo "❌"

echo -n "   - enrich_metadata_complete utilisé : "
grep -q 'enrich_metadata_complete' isbn_unified.sh && echo "✅" || echo "❌"

echo -n "   - display_martingale_complete ajouté : "
grep -q 'display_martingale_complete' isbn_unified.sh && echo "✅" || echo "❌"

# Nettoyer
rm -f temp_modifications.txt

echo ""
echo "✅ Intégration terminée !"
echo ""
echo "📝 Résumé des changements :"
echo "   1. lib/martingale_complete.sh est maintenant chargé"
echo "   2. enrich_metadata_complete() remplace apply_complete_martingale_metadata()"
echo "   3. display_martingale_complete() affiche les 156 champs"
echo ""
echo "🚀 Testez avec : ./isbn_unified.sh 9782070360024"
