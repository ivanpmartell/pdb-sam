# Obtain Single Aminoacid Mutation (SAM) data

Download sequence data from PDB at https://www.rcsb.org/downloads/fasta

Current url as of 2022-10-04: https://ftp.wwpdb.org/pub/pdb/derived_data/pdb_seqres.txt.gz

# Remove malformed sequences

>7ooo_B mol:na length:11  DNA (5'-D(*CP*TP*(RWQ)P*TP*CP*TP*TP*TP*G)-3')
CT05ATCTTTG
>7ooo_E mol:na length:11  DNA (5'-D(*CP*TP*(RWQ)P*TP*CP*TP*TP*TP*G)-3')
CT05ATCTTTG
>7oos_B mol:na length:11  DNA (5'-D(*CP*TP*(RWT)P*TP*CP*TP*TP*TP*G)-3')
CT05KTCTTTG
>7ozz_B mol:na length:11  DNA (5'-D(*CP*TP*(RWR)P*TP*CP*TP*TP*TP*G)-3')
CT05HTCTTTG

# Remove redundancy

Remove 100% identity sequences leaving earliest and longest sequences (WT)

# Separate SAMs by protein

Use CD-HIT to cluster for 99% sequence identity

Clean the clusters by removing singletons

Separate clusters into ```.fa``` files

Use Multiple Sequence Alignment on each cluster file

Recover SAM from MSA results

Obtain protein IDs for each cluster

Download protein structures (pdb) files for each ID

Filter out structure files that do not contain SAM in its structure (might not be necessary)
