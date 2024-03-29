#!/bin/bash
#call with absolute path
cd $1

for dir in */; do
    cd $1
    if [ -d "$dir" ]; then
        cd "$1/$dir"
        for file in *.fa; do
            # Check if the file exists and is a regular file
            if [ -f "$file" ]; then
                # Remove the .ssfa extension from the file name and store it in a variable
                name=${file%.fa}
                echo "${name//_}"
            fi
        done
    fi
done