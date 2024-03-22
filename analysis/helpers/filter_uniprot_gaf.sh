#!/bin/bash
files=$(find $1 -name "uniprot_ids.txt" | xargs grep -v nothing | sed -e 's/^.* \(.*$\)/\1/' | sort -u )
filter=""
for f in $files; do
    bname=$(basename $f)
    name=${bname%.ssfa}
    filter+="'\t'$name\|"
done
filter=${filter::-2}
grep -iP \$'$filter' $2