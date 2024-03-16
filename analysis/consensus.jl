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
        "--output", "-o"
            help = "Output directory. Ignore to use input directory"
        "--extension", "-e"
            help = "Alignment file extension. Default is .fa.ala"
            default = ".fa.ala"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"]) && startswith(parent_dir(f), "Cluster")

function initialize!(args, var)
    log_initialize!(args, var)
    var["aa_str"] = aa_alphabet_str()
end

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "consensus"; fext=".txt")
end

function commands(args, var)
    records = fasta_vector(var["input_path"])
    freqs = calculate_frequency_matrix(records, var["aa_str"])
    consensus_seq = calculate_consensus_sequence(freqs, var["aa_str"])
    consensus_seq_file = joinpath(var["abs_output_dir"], "consensus_sequence.txt")
    write_file(consensus_seq_file, consensus_seq; type="w")
    consensus = match_consensus(records, consensus_seq)
    msg = ""
    for record in records
        if identifier(record) == identifier(consensus)
            msg *= "$(identifier(record)) consensus\n"
        else
            msg *= "$(identifier(record)) mutated\n"
        end
    end
    write_file(var["output_file"], chop(msg))
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!)
    return 0
end

main()