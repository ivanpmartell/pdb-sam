using ArgParse
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory"
            required = true
        "--in_extension", "-e"
            help = "Extension for result files. Usually .fa"
            required = true
        "--results", "-r"
            help = "Results directory"
            required = true
        "--res_extension", "-x"
            help = "Extension for result files"
            required = true
        "--output_dir", "-d"
            help = "Relative output directory inside input directory"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to use input directory"
    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["in_extension"]) && startswith(parent_dir(f), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=args["res_extension"], cdir=args["output_dir"])
end

function commands(args, var)
    results_file = joinpath(args["results"], "$(var["input_noext"])$(args["res_extension"])")
    if isfile(results_file)
        cp(results_file, var["output_file"])
    else
        println("Skipping $(var["input_noext"])...")
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()