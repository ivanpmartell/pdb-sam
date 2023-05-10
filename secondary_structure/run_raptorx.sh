#!/bin/bash

PDBSAM_LOCATION="/storage/pdb-sam"
RAPTORX_LOCATION="/storage/2dstruc/Predict_Property"

for folder in $PDBSAM_LOCATION/cleaned_mmcifs/*; do
    if [ -d "$folder" ]; then
        if [ -d $folder ]; then
            if [ -f $folder/cif_sequences.fa ]; then
                echo "Running RaptorX on $folder"
                $RAPTORX_LOCATION/Predict_Property.sh -i $folder/cif_sequences.fa -o $folder/raptorx/
            fi
        else
            echo "Folder contains spaces. Use fix_paths.sh script on parent folder."
        fi
    fi
done
