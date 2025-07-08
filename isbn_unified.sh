

# Affichage avant analyse pour vérifier l'état
show_pre_analysis_check() {
    local product_id=$1
    local isbn=$2
    
    # Récupérer les données actuelles
    local score=$(safe_get_meta "$product_id" "_export_score")
    local max_score=$(safe_get_meta "$product_id" "_export_max_score")
    local last_date=$(safe_get_meta "$product_id" "_last_analyze_date")
    local missing=$(safe_get_meta "$product_id" "_missing_data")
    
    if [ -n "$score" ] && [ -n "$max_score" ]; then
        echo ""
        echo "📊 État actuel du livre :"
        echo "─────────────────────────"
        echo "Score : $score/$max_score points"
        
        if [ -n "$last_date" ]; then
            echo "Dernière analyse : $last_date"
        fi
        
        if [ "$score" -eq "$max_score" ]; then
            echo "✅ Ce livre a déjà toutes les données nécessaires"
            echo ""
            read -p "Réanalyser quand même ? (o/N) " choice
            [ "$choice" != "o" ] && [ "$choice" != "O" ] && return 1
        else
            echo "❌ Données incomplètes : $missing"
            echo ""
            read -p "Lancer l'analyse ? (O/n) " choice
            [ "$choice" = "n" ] || [ "$choice" = "N" ] && return 1
        fi
    fi
    
    return 0
}

show_batch_summary() {
    local processed=$1
    local successful=$2
    local errors=$3
    local incomplete_before=$4
    local incomplete_after=$5
    local duration=$6
    
    echo ""
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "📊 RÉSUMÉ DU TRAITEMENT PAR LOT"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
    echo "📚 Livres traités      : $processed"
    echo "✅ Réussis            : $successful"
    echo "❌ Erreurs            : $errors"
    echo ""
    echo "📈 Progression        : $incomplete_before → $incomplete_after incomplets"
    echo "⏱️  Durée totale      : ${duration}s"
    echo ""
    
    if [ $incomplete_after -gt 0 ]; then
        echo "💡 Relancez avec -p$processed pour continuer"
    else
        echo "🎉 Tous les livres sont maintenant complets !"
    fi
}
