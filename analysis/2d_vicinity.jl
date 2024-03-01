using ArgParse
using DelimitedFiles, DataFrames
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cluster folders with protein fasta files required"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to use input directory"
        "--consensus", "-c"
            help = "Consensus file basename"
            required = true
        "--designation", "-d"
            help = "Vicinity designation type ('cluster', 'protein')."
            default = "cluster"
        "--mutation_file", "-m"
            help = "Mutation file basename"
            default = "nogap_cif_sequences.fa.mut"
        "--max_range", "-x"
            help = "Maximum number of amino acids in vicinity. Default 15"
            default = 15
        "--min_range", "-n"
            help = "Minimum number of amino acids in vicnity. Default 5"
            default = 5
    end
    return parse_args(s)
end

function read_consensus(f)
    data = readdlm(f, ' ')
    con_mut_df = DataFrame(data, ["protein", "seq_type"])
    return con_mut_df[con_mut_df.seq_type .== "consensus"].protein
end

function one_dim_vicinity(prot_file, mut_file)
    
end

input_conditions(a,f) = return basename(f) == a["consensus"]
protein_conditions(a,f) = return has_extension(f, ".fa") && startswith(last(splitdir(dirname(f))), "Cluster")

function preprocess!(args, var)
    fext = ".1dv"
    if args["designation"] == "cluster"
        input_dir_out_preprocess!(var, "cluster"; fext=fext)
    elseif args["designation"] == "protein"
        for f in process_input(dirname(var["input_path"]), 'f'; input_conditions=protein_conditions)
            input_dir_out_preprocess!(var, remove_ext(basename(f)); fext=fext)
        end
    else
        throw(ArgumentError("Argument 'designation' has wrong value. Please use: 'cluster' or 'protein'"))
    end
end

function commands(args, var)
    mutation_file = joinpath(var["abs_output_dir"], args["mutation_file"])
    if !isfile(mutation_file)
        throw(ErrorException("Mutation file not found: $mutation_file"))
    end
    protein_file  = ""
    if remove_ext(basename(var["output_file"])) == "cluster"
        consensus_protein = read_consensus(var["input_path"])
        protein_file = joinpath(var["abs_output_dir"], "$consensus_protein.fa")
    else
        protein_file = joinpath(var["abs_output_dir"], "$(remove_ext(basename(var["output_file"]))).fa")
    end
    if !isfile(protein_file)
        throw(ErrorException("Protein sequence file not found: $protein_file"))
    end
    vicinity = one_dim_vicinity(protein_file, mutation_file)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()