#!/bin/bash
#Create the dataset
julia dataset/download.jl -o data/pdb_seqres.fa
julia dataset/filter_data.jl -i data/pdb_seqres.fa -o data/pdb_filtered.fa > data/filter.log
julia dataset/cluster_data.jl -i data/pdb_filtered.fa -o data/pdb_clustered.fa
julia dataset/clean_clusters.jl -i data/pdb_clustered.fa.clstr -o data/pdb_clean_clustered.fa.clstr -d clusters -f data/pdb_seqres.fa > data/clean_cluster.log
julia dataset/align_fasta.jl -i clusters/ -o alignments
julia dataset/clean_alignments.jl -i alignments/ -o cleaned_alignments > alignments/clean_alignments.log
julia dataset/download_cifs.jl -i cleaned_alignments/ -o mmcifs -p pdb_downloads -s
dataset/helpers/fix_paths.sh mmcifs
cp -r mmcifs ungapped_mmcifs
julia dataset/gap_to_x.jl -i mmcifs/ -o ungapped_mmcifs -p nogap_
julia dataset/align_fasta.jl -i ungapped_mmcifs
#If the first copy command was forgotten, use: cp -r mmcifs/* ungapped_mmcifs/
julia dataset/clean_cifs.jl -i ungapped_mmcifs/ -o cleaned_ungapped_mmcifs
julia dataset/pristine_cifs.jl -i cleaned_ungapped_mmcifs/ -o pristine_mmcifs -e .ala -n