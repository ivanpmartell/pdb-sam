using ArgParse
include("./common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input file (fasta format)"
            required = true
        "--output", "-o"
            help = "Output file (fasta format)"
            required = true
    end
    return parse_args(s)
end

function preprocess!(args, var)
    var["error_file"] = "$(var["output_file"]).err"
end

#TODO: Add mmseqs2 option
function commands(args, var)
    run(`cd-hit -i $(var["input_path"]) -o $(var["output_file"]) -c 0.99 -s 0.9`)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_single(parsed_args, commands; preprocess=preprocess!)
    return 0
end

main()