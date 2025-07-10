#!/bin/bash
echo "[START: restaurer.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2

echo "Restauration en cours..."
cd "$(dirname "$0")"
cp -r . ../
echo "Termine!"

echo "[END: restaurer.sh] $(date +%Y-%m-%d\ %H:%M:%S)" >&2
