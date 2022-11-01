mkdir alignments
cd clusters
for file in *; do
    clustalo --outfmt clustal --force -i "$file" -o "../alignments/$file.clu"
done
