#!/bin/bash
#Secondary structure prediction on pristine mmcifs
julia secondary_structure/raptorx.jl -i pristine_mmcifs/ -e .fa -r /storage/ssp-tools/2dstruc/Predict_Property/
julia secondary_structure/sspro8.jl -i pristine_mmcifs -e .fa -s /storage/ssp-tools/2dstruc/SCRATCH-1D_2.0/
julia secondary_structure/spot1d.jl -i pristine_mmcifs/ -e .fa -s /storage/ssp-tools/2dstruc/SPOT-1D-local/
julia secondary_structure/spot1d_single.jl -i pristine_mmcifs/ -e .fa -s /storage/ssp-tools/2dstruc/spot_1d_single/SPOT-1D-Single/
julia secondary_structure/spot1d_lm.jl -i pristine_mmcifs/ -e .fa -s /storage/ssp-tools/2dstruc/spot_1d_lm/SPOT-1D-LM/
#julia secondary_structure/s4pred.jl -i pristine_mmcifs/ -e .fa -s /storage/ssp-tools/2dstruc/s4pred/ (s4pred is only 3-class)
#Normalize predictions to fasta output
julia secondary_structure/raptorx_out2fa.jl -i pristine_mmcifs/
julia secondary_structure/spot1d_out2fa.jl -i pristine_mmcifs/
julia secondary_structure/spot1d_lm_out2fa.jl -i pristine_mmcifs/
julia secondary_structure/spot1d_single_out2fa.jl -i pristine_mmcifs/
julia secondary_structure/sspro8_out2fa.jl -i pristine_mmcifs/
#Normalize DSSP structure assignment
julia secondary_structure/dssp_out2fa.jl -i pristine_mmcifs/
#OLD: Agglomerate normalized predictions
julia secondary_structure/combine_preds.jl -i pristine_mmcifs/
julia secondary_structure/combine_preds4record.jl -i pristine_mmcifs/
julia secondary_structure/combine_preds4tool.jl -i pristine_mmcifs/