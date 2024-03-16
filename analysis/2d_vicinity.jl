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
            default = "consensus.txt"
        "--designation", "-d"
            help = "Vicinity designation type ('cluster', 'protein')."
            default = "cluster"
        "--mutation_file", "-m"
            help = "Mutation file basename"
            default = "mutations.txt"
        "--max_range", "-x"
            help = "Maximum number of amino acids in vicinity"
            default = 30
        "--min_range", "-n"
            help = "Minimum number of amino acids in vicnity"
            default = 10
    end
    return parse_args(s)
end

function cap_to_range(args, mut_pos, pos, length, side)
    capped_pos = pos
    if side == 'l'
        if mut_pos - pos < args["min_range"]
            capped_pos = mut_pos - args["min_range"]
        elseif mut_pos - pos > args["max_range"]
            capped_pos = mut_pos - args["max_range"]
        end
        if capped_pos < 1
            capped_pos = 1
        end
    elseif side == 'r'
        if pos - mut_pos < args["min_range"]
            capped_pos = mut_pos + args["min_range"]
        elseif pos - mut_pos > args["max_range"]
            capped_pos = mut_pos + args["max_range"]
        end
        if capped_pos > length
            capped_pos = length
        end
    end
    return capped_pos
end

function two_dim_vicinity(args, mutations, protein_ss)
    mutations_vicinity = Dict{String, Vector{Int}}()
    full_vicinity = Set{Int}()
    protein_ss_seq = sequence(protein_ss)
    protein_ss_length = length(protein_ss_seq)
    for mut in mutations
        mut_str = "$(mut.from)$(mut.position)$(mut.to)"
        vicinity = Set{Int}()
        lrange = get_neighbor_ss(protein_ss_seq, mut.position, 'l', 2)
        lrange = cap_to_range(args, mut.position, lrange, protein_ss_length, 'l')
        rrange = get_neighbor_ss(protein_ss_seq, mut.position, 'r', 2)
        rrange = cap_to_range(args, mut.position, rrange, protein_ss_length, 'r')
        for i in lrange:rrange
            push!(vicinity, i)
        end
        sorted_vicinity = sort(collect(vicinity))
        mutations_vicinity[mut_str] = sorted_vicinity
        for i in sorted_vicinity
            push!(full_vicinity, i)
        end
    end
    non_vicinity = collect(1:protein_ss_length)
    deleteat!(non_vicinity, sort(collect(full_vicinity)))
    return mutations_vicinity, sort(collect(full_vicinity)), non_vicinity
end

input_conditions(a,f) = return basename(f) == a["consensus"]
protein_conditions(a,f) = return has_extension(f, ".ssfa") && startswith(parent_dir(f), "Cluster")

function initialize!(args, var)
    var["fext"] = ".2dv"
    var["pext"] = ".ssfa"
    log_initialize!(args,var)
end

function preprocess!(args, var) 
    if args["designation"] == "cluster"
        input_dir_out_preprocess!(var, "cluster"; fext=var["fext"])
    elseif args["designation"] == "protein"
        for f in process_input(dirname(var["input_path"]), 'f'; input_conditions=protein_conditions)
            input_dir_out_preprocess!(var, remove_ext(basename(f)); fext=var["fext"])
        end
    else
        throw(ArgumentError("Argument 'designation' has wrong value. Please use: 'cluster' or 'protein'"))
    end
end

function commands(args, var)
    mutation_file = joinpath(var["abs_input_dir"], args["mutation_file"])
    if !isfile(mutation_file)
        throw(ErrorException("Mutation file not found: $mutation_file"))
    end
    mutations = read_mutations(mutation_file)
    protein_file  = ""
    if args["designation"] == "cluster"
        consensus_df = read_consensus(var["input_path"])
        consensus_protein = get_consensus(consensus_df)
        protein_file = joinpath(var["abs_input_dir"], "$consensus_protein$(var["pext"])")
    elseif args["designation"] == "protein"
        protein = remove_ext(basename(var["output_file"]))
        filtered_mutations = mutations_in_protein(mutations, protein)
        if length(filtered_mutations) !== 0
            mutations = filtered_mutations
        end
        protein_file = joinpath(var["abs_input_dir"], "$protein$(var["pext"])")
    end
    if !isfile(protein_file)
        throw(ErrorException("Protein sequence file not found: $protein_file"))
    end
    protein = read_fasta(protein_file)
    mutations_vicinity, full_vicinity, non_vicinity = two_dim_vicinity(args, mutations, protein)
    if args["designation"] == "cluster"
        local_file = joinpath(var["abs_output_dir"], "local$(var["fext"])")
        write_file(local_file, join(full_vicinity,','))
        non_local_file = joinpath(var["abs_output_dir"], "non_local$(var["fext"])")
        write_file(non_local_file, join(non_vicinity,','))
    elseif args["designation"] == "protein"
        local_file = joinpath(var["abs_output_dir"], "proteins_local$(var["fext"])")
        write_file(local_file, "$(remove_ext(basename(protein_file))) $(join(full_vicinity,','))")
        non_local_file = joinpath(var["abs_output_dir"], "proteins_non_local$(var["fext"])")
        write_file(non_local_file, "$(remove_ext(basename(protein_file))) $(join(non_vicinity,','))")
    end
    for (mut, vicinity) in mutations_vicinity
        write_file(var["output_file"], "$mut $vicinity")
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!)
    return 0
end

main()
