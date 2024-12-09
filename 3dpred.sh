#!/bin/bash
#Tertiary structure prediction on pristine mmcifs
julia tertiary_structure/af2.jl -i pristine_mmcifs/ -e .fa -a /storage/alphafold/ -g
julia tertiary_structure/esmfold.jl -i pristine_mmcifs/ -e .fa -m esm-fold
julia tertiary_structure/rgn2.jl -i pristine_mmcifs/ -e .fa -r /storage/rgn2/ -c /storage/conda/
julia tertiary_structure/colabfold.jl -i pristine_mmcifs/ -e .fa -c colabfold_batch -t /storage/colabfold_output
#Obtain secondary structure results from tertiary structure predictions
julia tertiary_structure/pdb_to_cif.jl -i pristine_mmcifs/
julia tertiary_structure/dssp_2d_transform.jl -i pristine_mmcifs/
julia secondary_structure/dssp_out2fa.jl -i pristine_mmcifs/ -e .pdb.mmcif -x .sspfa -f -p