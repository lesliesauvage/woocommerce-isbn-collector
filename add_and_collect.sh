#!/bin/bash
isbn=$1
[ -z "$isbn" ] && read -p "ISBN : " isbn

# Créer le livre
./add_book_minimal.sh $isbn

# Récupérer l'ID
id=$(mysql -h"localhost" -u"wordpress" -p"e96e30c154b7a661211a793bbac6416dcbaf9843ff19fb54" "savoir" -sN -e "SELECT post_id FROM wp_28_postmeta WHERE meta_key='_isbn' AND meta_value='$isbn' LIMIT 1;")

# Collecter les données
./collect_api_data.sh "p.ID = $id"
