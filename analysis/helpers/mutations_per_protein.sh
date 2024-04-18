#!/bin/bash
#call with absolute path
cd $1

cluster_count=0
for dir in */; do
    cd $1
    if [ -d "$dir" ]; then
        cd "$1/$dir"
        for file in *.ssfa; do
            if [ -f "$file" ]; then
                pname=${file%.ssfa}
                mut_count=$(grep "$pname" "$1/$dir/mutations.txt" | wc -l)
                if (( $mut_count > 1 )); then
                    echo "$dir $pname: $mut_count"
                    #grep "$pname" "$1/$dir/mutations.txt"
                    cluster_count=$((cluster_count+1))
                fi
            fi
        done
    fi
done
echo $cluster_count