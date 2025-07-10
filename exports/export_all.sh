#!/bin/bash
echo "[START: export_all.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

# Export vers TOUTES les marketplaces

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== EXPORT VERS TOUTES LES MARKETPLACES ==="
echo ""

for marketplace in amazon vinted rakuten fnac cdiscount; do
    echo "🔄 Export $marketplace..."
    "$SCRIPT_DIR/export_${marketplace}.sh"
    echo ""
done

echo "✅ TOUS LES EXPORTS TERMINÉS"
echo ""
echo "📁 Fichiers dans exports/output/ :"
ls -la "$SCRIPT_DIR/output/"

echo "[END: export_all.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
