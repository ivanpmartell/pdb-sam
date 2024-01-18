using ArgParse
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-s"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa' or '.ala'"
            required = true
        "--esmfold_exe", "-m"
            help = "ESMFold executable file. Usually esm-fold"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"

    end
    return parse_args(s)
end

parsed_args = parse_commandline()

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"]) && startswith(last(splitdir(in_path)), "Cluster")
end

function commands(f_path, f_noext, f_out)
    f_out_dir = dirname(f_out)
    run(`$(parsed_args["esmfold_exe"]) -i $(f_path) -o $(f_out_dir) --cpu-offload`)
    for (root_out, dirs_out, files_out) in walkdir(f_out_dir)
        for file_out in files_out
            if startswith(file_out, f_noext)
                file_out_path = joinpath(root_out, file_out)
                mv(file_out_path, f_out)
                break
            end
        end
    end
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "pdb", commands, parsed_args["skip_error"], "esmfold/")
