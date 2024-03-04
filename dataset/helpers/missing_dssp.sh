#!/bin/bash
cd $1

for dir in */; do
    cd $1
    if [ -d "$dir" ]; then
        cd "$1/$dir"
        for file in *.fa; do
            # Check if the file exists and is a regular file
            if [ -f "$file" ]; then
                # Remove the .fa extension from the file name and store it in a variable
                name=${file%.fa}
                path=$(dirname "$file")
                # Check for ssfa file
                test=$(find "$path" -type f -name "$name.ssfa" -print -quit | wc -l)
                if test $test -eq 0; then
                    echo "$dir - $name"
                fi
            fi
        done
    fi
done