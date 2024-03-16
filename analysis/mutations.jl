using ArgParse
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cluster folders with alignment files required"
            required = true
        "--consensus_sequence", "-c"
            help = "Basename of consensus sequence file"
            default = "consensus_sequence.txt"
        "--output", "-o"
            help = "Output directory. Ignore to use input directory"
        "--extension", "-e"
            help = "Alignment file extension. Default is .fa.ala"
            default = ".fa.ala"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"]) && startswith(parent_dir(f), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "mutations"; fext=".txt")
end

function commands(args, var)
    records = fasta_dict(var["input_path"])
    seqs_length = get_sequences_length(records)
    consensus_file = joinpath(dirname(var["input_path"]), args["consensus_sequence"])
    consensus_seq = rstrip(read(consensus_file, String),'\n')
    if length(consensus_seq) !== seqs_length
        throw(ErrorException("Consensus sequence is wrong"))
    end
    mutation_dict = Dict{String, Vector{String}}()
    for i in 1:seqs_length
        for j in eachindex(records)
            aa = sequence(records[j])[i]
            if aa !== consensus_seq[i]
                if haskey(mutation_dict, "$(consensus_seq[i])$i$aa")
                    push!(mutation_dict["$(consensus_seq[i])$i$aa"], identifier(records[j]))
                else
                    mutation_dict["$(consensus_seq[i])$i$aa"] = [identifier(records[j])]
                end
            end
        end
    end
    msg = ""
    for (key, value) in mutation_dict
        msg *= "$key $value\n"
    end
    write_file(var["output_file"], chop(msg))
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()