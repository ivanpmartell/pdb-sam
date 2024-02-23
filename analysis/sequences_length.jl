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
            help = "Input directory. Cluster folders with fasta files required"
            required = true
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, ".fa") && startswith(last(splitdir(dirname(f))), "Cluster")

function preprocess!(args, var)
    file_preprocess!(var; input_only=true)
end

function commands(args, var)
    len = get_sequences_length(var["input_path"])
    println("$(last(splitdir(dirname(var["input_path"])))) $(var["input_noext"]) $len")
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()