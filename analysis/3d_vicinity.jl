using ArgParse
using DelimitedFiles, DataFrames
using BioStructures
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
        "--angstrom_range", "-a"
            help = "3D range for vicinity. Default 13"
            default = 13
    end
    return parse_args(s)
end

function three_dim_vicinity(args, mutations, protein_structure)
    mutations_vicinity = Dict{String, Vector{Int}}()
    full_vicinity = Set{Int}()
    calphas = collectatoms(protein_structure, calphaselector)
    for mut in mutations
        mut_str = "$(mut.from)$(mut.position)$(mut.to)"
        vicinity = Set{Int}()
        for i in eachindex(calphas)
            distance_to_mut = distance(calphas[mut.position], calphas[i])
            if distance_to_mut <= args["angstrom_range"]
                push!(vicinity, i)
            end
        end
        sorted_vicinity = sort(collect(vicinity))
        mutations_vicinity[mut_str] = sorted_vicinity
        for i in sorted_vicinity
            push!(full_vicinity, i)
        end
    end
    non_vicinity = collect(1:length(calphas))
    sorted_full_vicinity = sort(collect(full_vicinity))
    deleteat!(non_vicinity, sorted_full_vicinity)
    return mutations_vicinity, sorted_full_vicinity, non_vicinity
end

input_conditions(a,f) = return basename(f) == a["consensus"]
protein_conditions(a,f) = return '_' in basename(f) && has_extension(f, ".cif") && startswith(parent_dir(f), "Cluster")

function initialize!(args, var)
    var["fext"] = ".3dv"
    var["pext"] = ".cif"
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
    protein_structure = read(protein_file, MMCIFFormat)
    mutations_vicinity, full_vicinity, non_vicinity = three_dim_vicinity(args, mutations, protein_structure)
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
