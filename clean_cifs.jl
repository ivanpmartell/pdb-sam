#TODO: Remove clusters without variants in pdb file sequences by alignment
using ArgParse

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cluster folders with cif files and sequences should be here"
            required = true
        "--output", "-o"
            help = "Output directory. Cleaned alignment files (fasta format) for each cluster will be saved here. Ignore to write files in input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()

for (root, dirs, files) in walkdir(parsed_args["input"])
    for f in files
        if f == "cif_sequences.fa"
            f_path = joinpath(root,f)
            print(f_path)
            #for i in 
        end
    end
end

#for i =/= j
# check sequences are all different
# - Align fasta file of cluster DONE
# - Use entropy formula to get mutations
# - check all mutations to see which sequences are unique
# remove non-unique sequences

