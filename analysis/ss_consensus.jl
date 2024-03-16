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
            help = "Input directory. Cluster folders with secondary structure assignment files required"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to use input directory"
        "--extension", "-e"
            help = "Secondary structure file extension"
            default = ".ssfa"
    end
    return parse_args(s)
end

input_conditions(a,f) = return startswith(basename(f), "Cluster")

function initialize!(args, var)
    log_initialize!(args, var)
    var["ss_str"] = ss_alphabet_str()
end

function preprocess!(args, var)
    input_dir_out_preprocess!(var, "ss_consensus_sequence"; fext=".txt", cdir=var["input_basename"])
end

function commands(args, var)
    records = ss_fasta_vector(var["input_path"], args["extension"])
    freqs = calculate_ss_frequency_matrix(records, var["ss_str"])
    consensus_seq = calculate_consensus_sequence(freqs, var["ss_str"])
    write_file(var["output_file"], consensus_seq; type="w")
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'd'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!)
    return 0
end

main()