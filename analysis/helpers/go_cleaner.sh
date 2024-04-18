#!/bin/bash
sed 's/^.*\t\(.*\); \(GO:[0-9]*\)\(.*\)$/NEW"\2"\t\1; \3/' go.txt | grep 'NEW"GO' | sed 's/NEW"GO/"GO/' | sed 's/; ;/;/'| sed 's/; "/"/' > go_syn_new0.txt
cleaned_count=$(wc -l < go_syn_new0.txt)
i=1
while (( $cleaned_count > 0 )); do
    if (( $i > 20 )); then
        break
    fi
    sed 's/^.*\t\(.*\); \(GO:[0-9]*\)\(.*\)$/NEW"\2"\t\1; \3/' go_syn_new$((i-1)).txt | grep 'NEW"GO' | sed 's/NEW"GO/"GO/' | sed 's/; ;/;/'| sed 's/; "/"/' > go_syn_new$i.txt
    sed 's/; GO:[0-9]*//g' go_syn_new$((i-1)).txt > go_syn_clean.txt
    mv go_syn_clean.txt go_syn_new$((i-1)).txt
    cleaned_count=$(wc -l < go_syn_new$i.txt)
    i=$((i+1))
done
rm go_syn_new$((i-1)).txt
sed 's/; GO:[0-9]*//g' go.txt > go_clean.txt
mv go.txt go.txt.old
cat *.txt > cleaned_go.res
awk '!a[$0]++' cleaned_go.res > cleaned_go.txt
rm cleaned_go.res 
mv go.txt.old go.txt