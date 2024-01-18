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
        "--rgn2_dir", "-r"
            help = "Directory containing RGN2 repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--conda_dir", "-c"
            help = "Base directory containing conda or miniconda"
            required = true

    end
    return parse_args(s)
end

parsed_args = parse_commandline()

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"]) && startswith(last(splitdir(in_path)), "Cluster")
end

function commands(f_path, f_noext, f_out)
    run(Cmd(`python run_aminobert.py $(f_path)`, dir=parsed_args["rgn2_dir"]))
    run(Cmd(`python run_rgn2.py $(f_path) $(abspath(parsed_args["conda_dir"]))`, dir=parsed_args["rgn2_dir"]))
    rgn2_output_dir = joinpath(parsed_args["rgn2_dir"], "output/refine_model1/")
    mv(joinpath(rgn2_output_dir, "$(f_noext)_prediction.pdb"), f_out)
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "pdb", commands, parsed_args["skip_error"], "rgn2/")
