using ArgParse
using BioSequences
include("../common.jl")
include("../seq_common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Default '.fa'"
            default = ".fa"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    file_preprocess!(var; input_only=true)
end

function commands(args, var)
    protein_length = get_sequences_length(var["input_path"])
    if (protein_length < 30)
        throw(ErrorException("Minimum sequence length not met"))
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!, runtime_unit="sec")
    return 0
end

main()