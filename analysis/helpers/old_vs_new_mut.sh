#!/bin/bash

for f1 in $(find $1 -name "mutations.txt"); do 
 dname=$(dirname $f1)
 f2=$dname/nogap_cif_sequences.fa.mut
 if [ "$(wc -l < $f1)" -eq "$(wc -l < $f2)" ]; then continue; else echo "No match on $f1"; fi
done