#!/bin/bash
#call with absolute path
cd $1

cluster_count=0
for dir in */; do
    cd $1
    if [ -d "$dir" ]; then
        cd "$1/$dir"
        filter=""
        for file in *.fa; do
            if [ -f "$file" ]; then
                name=${file%.fa}
                if [ $3 = "nochains" ]; then
                    filter+="${name%_*}\|"
                else
                    filter+="${name//_}\|"
                fi
            fi
        done
        filter=${filter::-2}
        count=$(grep -i "$filter" $2 | wc -l)
        if (( count > 0 )); then
            cluster_count=$((cluster_count+1))
        fi
    fi
done
echo $cluster_count