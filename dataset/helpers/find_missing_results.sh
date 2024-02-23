#!/bin/bash
mkdir missing_$2
missing_dir="$(pwd)/missing_$2"
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
                # Declare an array of subdirectory names to search
                subdirs=("af2" "rgn2" "colabfold" "esmfold" "raptorx" "spot1d" "spot1d_lm" "spot1d_single" "sspro8")
                # Loop through the array of subdirectory names
                for subdir in "${subdirs[@]}"; do
                    # Find all the files with the same name in the subdirectory
                    # If no results are found, print the subdirectory name
                    test=$(find "$path" -type f -name "$name.*" -path "*/$subdir/*" -print -quit | wc -l)
                    if test $test -eq 0; then
                        echo "$subdir: $dir - $name"
                        if [ $subdir == "$2" ]; then
                            cp $file $missing_dir/
                            echo "$name" >> $missing_dir/protlist.txt
                        fi
                    fi
                done
            fi
        done
    fi
done