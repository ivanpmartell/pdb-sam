#!/bin/bash
#call with absolute path
cd $1

for dir in */; do
    cd $1
    if [ -d "$dir" ]; then
        cd "$1/$dir"
        for file in *.ssfa; do
            # Check if the file exists and is a regular file
            if [ -f "$file" ]; then
                # Remove the .ssfa extension from the file name and store it in a variable
                name=${file%.ssfa}
                uniprot_file="uniprot_ids.txt"
                # Check for ssfa file
                test=$(grep $name $uniprot_file | wc -l)
                if test $test -eq 0; then
                    echo "$dir - $name"
                fi
            fi
        done
    fi
done