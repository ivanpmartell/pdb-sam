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
            help = "Extension for input files. Usually '.pdb.cif'"
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
    run(`mkdssp $(f_path) $(f_out)`)
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "pdb.mmcif", commands, parsed_args["skip_error"])
