#Use af2 conda env
using ArgParse
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory"
            required = true
        "--extension", "-e"
            help = "Extension for input files. Usually '.fa' or '.ala'"
            required = true
        "--af2_output", "-t"
            help = "Temporary output directory. Usually somewhere outside your output directory"
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
    af2_output = joinpath(parsed_args["af2_output"], "$(f_noext)/ranked_0.pdb")
    if isfile(af2_output)
        println("Moving $(f_noext) into the output directory")
        mv(af2_output, f_out)
    end
end

work_on_files(parsed_args["input"], parsed_args["output"], input_conditions, "af2/", "pdb", commands)
