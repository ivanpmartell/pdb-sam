cd alignments
for file in *; do
    mkdir "${file::-7}"
    julia ../create_seqlogo.jl "$file"
done