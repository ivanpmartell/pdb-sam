julia download.jl data/pdb_seqres.fa
julia filter_data.jl -i data/pdb_seqres.fa -o data/pdb_filtered.fa > data/filter.log
julia cluster_data.jl -i data/pdb_filtered.fa -o data/pdb_clustered.fa
julia clean_clusters.jl -i data/pdb_clustered.fa.clstr -o data/pdb_clean_clustered.fa.clstr -d clusters -f data/pdb_seqres.fa
julia align_fasta.jl -i clusters/ -o alignments
julia clean_alignments.jl -i alignments/ -o cleaned_alignments > data/clean_alignments.log
julia download_cifs.jl -i cleaned_alignments/ -o mmcifs
./fix_paths.sh mmcifs
cp mmcifs ungapped_mmcifs
julia gap_to_x.jl -i mmcifs/ -o ungapped_mmcifs -p nogap_
julia align_fasta.jl -i ungapped_mmcifs
#If the first copy command was forgotten, use: cp -r mmcifs/* ungapped_mmcifs/
julia clean_cifs.jl -i ungapped_mmcifs/ -o cleaned_ungapped_mmcifs
julia count_seqlen.jl -i cleaned_ungapped_mmcifs/ -o pristine_mmcifs -e .ala -n