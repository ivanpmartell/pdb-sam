# Protein data bank single amino-acid mutation (PDB-SAM) research

A set of Julia and Python scripts to create and analyze single amino-acid mutations using experimental data from the Protein Data Bank (PDB).
If utilizing Ubuntu 18.04 or 20.04, we have provided a script `setup.sh` that will automate the acquisition of the required software and libraries.

## Required Julia libraries

```
FASTX
BioStructures
BioSequences
LogExpFunctions
Pandas
PyCall
ArgParse
ProgressBars
```

## Required Python libraries
```
logomaker
pandas
numpy
```

## Required software
`MAXIT` from [here](https://sw-tools.rcsb.org/apps/MAXIT)
`DSSP` from [here](https://github.com/PDB-REDO/dssp)
`ssmetrics` from [here](https://github.com/ivanpmartell/SecondaryStructureMetrics) or ```SOV_refine.pl``` from [here](http://dna.cs.miami.edu/SOV) for metrics calculations
`Clustal Omega` from [here](http://www.clustal.org/omega)
`EMBOSS` from [here](http://emboss.open-bio.org/)
`BLAST+` from [here](https://www.ncbi.nlm.nih.gov/books/NBK131777/)
`CD-HIT` from [here](https://github.com/weizhongli/cdhit)

## Protein Structure Prediction Methods

### Secondary Structure Prediction Methods
- SSPro8 from [here](https://scratch.proteomics.ics.uci.edu/explanation.html#SSpro8)
- RaptorX PropertyPredict from [here](https://github.com/realbigws/Predict_Property)
- SPOT1D from [here](https://zhouyq-lab.szbl.ac.cn/download/)
- SPOT1D-Single from [here](https://github.com/jas-preet/SPOT-1D-Single)
- SPOT1D-LM from [here](https://github.com/jas-preet/SPOT-1D-LM)

### Tertiary Structure Prediction Methods
- Alphafold 2 from [here](https://github.com/google-deepmind/alphafold)
- ESMFold from [here](https://github.com/facebookresearch/esm)
- ColabFold from [here](https://github.com/sokrypton/ColabFold)
- RGN2 from [here](https://github.com/aqlaboratory/rgn2)

The setup of these methods are hardware-dependent and as such must be manually installed by following each of their installation procedures.

## Dataset creation

The scripts to create a dataset and extra helper scripts can be found under the `dataset` folder.
One can also use the `dataset.sh` script to create an updated mutational dataset.

## Secondary structure assignment

Assigning secondary structure to the experimental data is done through `DSSP`.
Once DSSP is installed, run the `2dassign.sh` script.

## Acquiring secondary structure predictions

### From secondary structure prediction methods

The scripts for secondary structure prediction methods can be found under the `secondary_structure` folder.
Once the secondary structure prediction methods have been installed (We suggest to install under `/storage/`).
The script `2dpred.sh` can be used to obtain their predictions.

### From tertiary structure prediction methods

The scripts for secondary structure prediction methods can be found under the `tertiary_structure` folder.
Once the tertiary structure prediction methods have been installed (We suggest to install under `/storage/`).
The script `3dpred.sh` can be used to obtain their predictions.

## Mutation analysis

The scripts for secondary structure prediction methods can be found under the `analysis` and `extra` folder.
Once predictions for all the methods have been obtained, run `analysis.sh` script to obtain the mutational results and metrics for each of the prediction methods.

### Help and Citation

For any questions, please submit a post in the `Issues` tab above.

More information can be found in our research article [here] (TBD).

If you found our work useful, please cite:

```
TBD
```