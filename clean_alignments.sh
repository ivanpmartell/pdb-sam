cd alignments
for file in *; do
    sed '/^[^>]/ s/X/-/g' "$file" > "${file%?}"
    mv "${file%?}" "${file}"
done