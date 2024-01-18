using ArgParse

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
        "--s4pred_dir", "-s"
            help = "Directory containing SSPro8 repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"

    end
    return parse_args(s)
end

parsed_args = parse_commandline()

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"])
end

function commands(f_path, f_noext, f_out)
    s4pred = joinpath(parsed_args["s4pred_dir"], "run_model.py")
    write("$(f_out)", read(`python $(s4pred) $(f_path)`))
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "ss2", commands, parsed_args["skip_error"], "s4pred/")