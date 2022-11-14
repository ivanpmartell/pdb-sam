mkdir alignments
cd clusters
for file in *; do
    clustalo --outfmt fasta --force -i "$file" -o "../alignments/$file.ala"
done