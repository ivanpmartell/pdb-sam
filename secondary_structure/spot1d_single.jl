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
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa' or '.ala'"
            required = true
        "--spot1d_single_dir", "-s"
            help = "Directory containing SPOT-1D-Single repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--gpu", "-g"
            help = "Use GPU for faster prediction"

    end
    return parse_args(s)
end

function create_filelist(current_file_path, filelist_path)
    abs_file_path = current_file_path
    if !startswith(current_file_path, '/')
        abs_file_path = joinpath(pwd(), current_file_path)
    end
    open(filelist_path, "w") do writer
        println(writer, abs_file_path)
    end
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function initialize!(args, var)
    var["device"] = "cpu"
    if args["gpu"]
        var["device"] = "cuda:0"
    end
end

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"], "csv", "spot1d_single/")
end

function commands(args, var)
    abs_filelist_path = abspath("tmp_s1ds_filelist.txt")
    create_filelist(var["input_path"], abs_filelist_path)
    abs_f_out_dir = abspath(dirname(var["output_file"]))
    run(Cmd(`python spot1d_single.py --file_list $(abs_filelist_path) --save_path $(abs_f_out_dir) --device $(var["device"])`, dir=args["spot1d_single_dir"]))
    rm(abs_filelist_path)
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, initialize=initialize!, preprocess=preprocess!)
    return 0
end

main()