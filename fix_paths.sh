#!/bin/bash

for folder in $1/*; do
    if [ -d "$folder" ]; then
        echo "moving folder $folder"
        new_folder=$(echo "$folder" | tr ' ' '_')
        mv "$folder" "$new_folder"
    fi
done
