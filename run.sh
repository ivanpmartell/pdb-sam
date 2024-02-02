julia download.jl -o data/pdb_seqres.fa
julia filter_data.jl -i data/pdb_seqres.fa -o data/pdb_filtered.fa > data/filter.log
julia cluster_data.jl -i data/pdb_filtered.fa -o data/pdb_clustered.fa
julia clean_clusters.jl -i data/pdb_clustered.fa.clstr -o data/pdb_clean_clustered.fa.clstr -d clusters -f data/pdb_seqres.fa
julia align_fasta.jl -i clusters/ -o alignments
julia clean_alignments.jl -i alignments/ -o cleaned_alignments > alignments/clean_alignments.log
julia download_cifs.jl -i cleaned_alignments/ -o mmcifs -s
./fix_paths.sh mmcifs
cp mmcifs ungapped_mmcifs
julia gap_to_x.jl -i mmcifs/ -o ungapped_mmcifs -p nogap_
julia align_fasta.jl -i ungapped_mmcifs
#If the first copy command was forgotten, use: cp -r mmcifs/* ungapped_mmcifs/
julia clean_cifs.jl -i ungapped_mmcifs/ -o cleaned_ungapped_mmcifs
julia pristine_cifs.jl -i cleaned_ungapped_mmcifs/ -o pristine_mmcifs -e .ala -n
#Secondary structure assignment (DSSP)
julia download_cifs.jl -i pristine_mmcifs/ -d -n #CHANGE TO DSSP.jl
#Secondary structure prediction on pristine mmcifs
julia secondary_structure/raptorx.jl -i pristine_mmcifs/ -e .fa -r /storage/ssp-tools/2dstruc/Predict_Property/
julia secondary_structure/sspro8.jl -i pristine_mmcifs -e .fa -s /storage/ssp-tools/2dstruc/SCRATCH-1D_2.0/
julia secondary_structure/spot1d.jl -i pristine_mmcifs/ -e .fa -s /storage/ssp-tools/2dstruc/SPOT-1D-local/
julia secondary_structure/spot1d_single.jl -i pristine_mmcifs/ -e .fa -s /storage/ssp-tools/2dstruc/spot_1d_single/SPOT-1D-Single/
julia secondary_structure/spot1d_lm.jl -i pristine_mmcifs/ -e .fa -s /storage/ssp-tools/2dstruc/spot_1d_lm/SPOT-1D-LM/
#julia secondary_structure/s4pred.jl -i pristine_mmcifs/ -e .fa -s /storage/ssp-tools/2dstruc/s4pred/
#Normalize predictions to fasta output (s4pred is 3-class)
julia secondary_structure/raptorx_out2fa.jl -i pristine_mmcifs/
julia secondary_structure/spot1d_out2fa.jl -i pristine_mmcifs/
julia secondary_structure/spot1d_lm_out2fa.jl -i pristine_mmcifs/
julia secondary_structure/spot1d_single_out2fa.jl -i pristine_mmcifs/
julia secondary_structure/sspro8_out2fa.jl -i pristine_mmcifs/
#Normalize DSSP structure assignment
julia secondary_structure/dssp_out2fa.jl -i pristine_mmcifs/
#Agglomerate normalized predictions
julia secondary_structure/combine_preds.jl -i pristine_mmcifs/
julia secondary_structure/combine_preds4record.jl -i pristine_mmcifs/
julia secondary_structure/combine_preds4tool.jl -i pristine_mmcifs/
#Create results file
julia clusters_mutations.jl -i pristine_mmcifs/
julia summarize_clusters.jl -i pristine_mmcifs/
#(Local)Benchmark of tools (change SOV_refine path)
julia local_benchmark.jl -i pristine_mmcifs/ -s /storage/sov_refine/SOV_refine.pl -m
julia summarize_metrics.jl -i pristine_mmcifs/ -t local
#(Global)Benchmark of tools (change SOV_refine path)
julia global_benchmark.jl -i pristine_mmcifs/ -s /storage/sov_refine/SOV_refine.pl
julia summarize_metrics.jl -i pristine_mmcifs/ -t global
#Tertiary structure prediction on pristine mmcifs
julia tertiary_structure/af2.jl -i pristine_mmcifs/ -e .fa -a /storage/alphafold/ -g
julia tertiary_structure/esmfold.jl -i pristine_mmcifs/ -e .fa -m esm-fold
julia tertiary_structure/rgn2.jl -i pristine_mmcifs/ -e .fa -r /storage/rgn2/ -c /storage/conda/
julia tertiary_structure/colabfold.jl -i pristine_mmcifs/ -e .fa -c colabfold_batch -t /storage/colabfold_output
