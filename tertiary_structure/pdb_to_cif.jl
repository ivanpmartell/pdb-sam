#Use rgn2 conda evn
using ArgParse
using Dates

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.pdb'"
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
    run(`maxit -input $(f_path) -output $(f_out) -o 8`)
end

work_on_files(parsed_args["input"], parsed_args["output"], input_conditions, "", "mmcif", commands)
