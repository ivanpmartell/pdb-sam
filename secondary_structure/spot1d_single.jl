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

parsed_args = parse_commandline()
device = "cpu"
if parsed_args["gpu"]
    device = "cuda:0"
end

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"])
end

function commands(f_path, f_noext, f_out)
    abs_filelist_path = abspath("tmp_s1ds_filelist.txt")
    create_filelist(f_path, abs_filelist_path)
    abs_f_out_dir = abspath(dirname(f_out))
    run(Cmd(`python spot1d_single.py --file_list $(abs_filelist_path) --save_path $(abs_f_out_dir) --device $(device)`, dir=parsed_args["spot1d_single_dir"]))
    rm(abs_filelist_path)
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "csv", commands, parsed_args["skip_error"], "spot1d_single/")