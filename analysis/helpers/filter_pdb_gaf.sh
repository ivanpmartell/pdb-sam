#!/bin/bash
files=$(find $1 -name "*.ssfa")
filter=""
for f in $files; do
    bname=$(basename $f)
    name=${bname%.ssfa}
    filter+="$name\|"
done
filter=${filter::-2}
grep -i "$filter" $2 #| grep -i uniprot