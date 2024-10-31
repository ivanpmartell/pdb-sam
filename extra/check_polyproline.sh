#!/bin/bash
directory=$1

# Loop through each file in the directory
for file in "$directory"/*.ssfa; do
  if grep -q "P" "$file"; then
    echo "Polyproline was found in $file"
  fi
done