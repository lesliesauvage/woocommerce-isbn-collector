#!/bin/bash
echo "Restauration en cours..."
cd "$(dirname "$0")"
cp -r . ../
echo "Termine!"
