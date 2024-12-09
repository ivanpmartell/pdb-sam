#!/bin/bash
# Analysis
#OLD: Create results file
#julia clusters_mutations.jl -i pristine_mmcifs/
#julia summarize_clusters.jl -i pristine_mmcifs/
#OLD: (Local)Benchmark of tools
#julia local_benchmark.jl -i pristine_mmcifs/ -s /storage/sov_refine/SOV_refine.pl -m
#julia summarize_metrics.jl -i pristine_mmcifs/ -t local
#OLD: (Global)Benchmark of tools
#julia global_benchmark.jl -i pristine_mmcifs/ -s /storage/sov_refine/SOV_refine.pl
#julia summarize_metrics.jl -i pristine_mmcifs/ -t global
#Obtain local and non-local vicinity
julia analysis/1d_vicinity.jl -i pristine_mmcifs/
#julia analysis/1d_vicinity.jl -i pristine_mmcifs/ -d protein
julia analysis/2d_vicinity.jl -i pristine_mmcifs/
#julia analysis/2d_vicinity.jl -i pristine_mmcifs/ -d protein
julia analysis/3d_vicinity.jl -i pristine_mmcifs/
#julia analysis/3d_vicinity.jl -i pristine_mmcifs/ -d protein
julia analysis/contact_vicinity.jl -i pristine_mmcifs/
#julia analysis/contact_vicinity.jl -i pristine_mmcifs/ -d protein
#Get metrics for cluster (local, non-local, global)
julia analysis/ss_metrics.jl -i pristine_mmcifs/
#Get mutational metrics
julia extra/mutational_accuracy.jl -i pristine_mmcifs/ -m af2+colabfold+esmfold+raptorx+rgn2+spot1d+spot1d_lm+spot1d_single+sspro8
julia extra/mutational_consistency.jl -i pristine_mmcifs/ -m af2+colabfold+esmfold+raptorx+rgn2+spot1d+spot1d_lm+spot1d_single+sspro8
julia extra/mutational_precision.jl -i pristine_mmcifs -m af2+colabfold+esmfold+raptorx+rgn2+spot1d+spot1d_lm+spot1d_single+sspro8 -t ~/SOV_refine/SOV_refine.pl