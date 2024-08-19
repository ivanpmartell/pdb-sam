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
            help = "Secondary structure consensus file basename"
            default = "ss_consensus_sequence.txt"
        "--mutation_file", "-m"
            help = "Mutation file basename"
            default = "mutations.txt"
    end
    return parse_args(s)
end

function position_changes(seq1, seq2)
    #Use for global
    pos_change = Dict{Int, Vector{Tuple{Char, Char}}}() # position => (from, to)
    for (i, (c1, c2)) in enumerate(zip(seq1, seq2))
        if c1 != c2
            if haskey(pos_change, i)
                push!(pos_change[i], (c1, c2))
            else
                pos_change[i] = [(c1, c2)]
            end
        end
    end
    return pos_change
end

function sequence_difference(indices, position_change)
    #Use for vicinity (local, non_local)
    differences = Dict{Char, Dict{Char, Int}}() # from => to => count
    for i in indices
        if haskey(position_change, i)
            for change in position_change[i]
                c1 = first(change)
                c2 = last(change)
                if haskey(differences, c1)
                    if haskey(differences[c1], c2)
                        differences[c1][c2] += 1
                    else
                        differences[c1][c2] = 1
                    end
                else
                    differences[c1] = Dict(c2 => 1)
                end
            end
        end
    end
    return differences
end

function write_differences(differences, out_file, cluster, protein, mut, tool, type, vicinity)
    for from in keys(differences)
        for to in keys(differences[from])
            count = differences[from][to]
            write_file(out_file, "$cluster $protein $mut $tool $type $vicinity $from $to $count")
        end
    end
end

input_conditions(a,f) = return basename(f) == a["consensus"]

function preprocess!(args, var) 
    input_dir_out_preprocess!(var, "mutation_change"; fext=".res")
end

function commands(args, var)
    change_occurance_out_file = joinpath(var["abs_output_dir"], "mutation_change_occurance.res")
    ss_consensus_seq = rstrip(read(var["input_path"], String),'\n')
    full_idxs = collect(1:length(ss_consensus_seq))
    mutation_file = joinpath(var["abs_input_dir"], args["mutation_file"])
    if !isfile(mutation_file)
        throw(ErrorException("Mutation file not found: $mutation_file"))
    end
    mutations = read_mutations(mutation_file)
    protein_pos_changes = Dict{String, Dict{String, Dict{Int, Vector{Tuple{Char, Char}}}}}() # protein => tool => pos_changes
    tools = get_prediction_methods()
    for protein in proteins_from_mutations(mutations)
        protein_ss_file = joinpath(var["abs_input_dir"], "$protein.ssfa")
        protein_ss_seq = sequence(read_fasta(protein_ss_file))
        protein_pos_changes[protein] = Dict("pdb" => position_changes(ss_consensus_seq, protein_ss_seq))
        for tool in tools
            pred_ss_file = joinpath(var["abs_input_dir"], tool, "$protein.sspfa")
            pred_ss_seq = sequence(read_fasta(pred_ss_file))
            protein_pos_changes[protein][tool] = position_changes(ss_consensus_seq, pred_ss_seq)
        end
    end
    methods = ["pdb"]
    append!(methods, get_prediction_methods())
    for type in ["1d", "2d", "3d", "contact"]
        mutations_vicinity_file = joinpath(var["abs_input_dir"], get_vicinity_type_filename("cluster", type))
        mut_vic_indices = read_mutations_vicinity_file(mutations_vicinity_file)
        non_local_file = joinpath(var["abs_input_dir"], get_vicinity_type_filename("non_local", type))
        nl_indices = read_vicinity_file(non_local_file)
        for mutation in mutations
            mut = "$(mutation.from)$(mutation.position)$(mutation.to)"
            mut_indices = mut_vic_indices[mut]
            for protein in mutation.proteins
                for tool in methods
                    changes = Dict{String, Bool}() # vicinity => change_occurs
                    global_diffs = sequence_difference(full_idxs, protein_pos_changes[protein][tool])
                    changes["global"] = !(isempty(global_diffs))
                    write_differences(global_diffs, var["output_file"], basename(var["abs_input_dir"]), protein, mut, tool, type, "global")
                    for vicinity in ["local", "non_local"]
                        if vicinity == "local"
                            vic_indices = mut_indices
                        else
                            vic_indices = nl_indices
                        end
                        vic_diffs = sequence_difference(vic_indices, protein_pos_changes[protein][tool])
                        changes[vicinity] = !(isempty(vic_diffs))
                        write_differences(vic_diffs, var["output_file"], basename(var["abs_input_dir"]), protein, mut, tool, type, vicinity)
                    end
                    write_file(change_occurance_out_file, "$(basename(var["abs_input_dir"])) $protein $mut $tool $type $(changes["local"]) $(changes["non_local"]) $(changes["global"])")
                end
            end
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()