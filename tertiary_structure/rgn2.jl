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

input_conditions(a,f) = return has_extension(f, a["extension"]) && startswith(last(splitdir(dirname(f))), "Cluster")

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".pdb", cdir="rgn2/")
end

function commands(args, var)
    run(Cmd(`python run_aminobert.py $(var["input_path"])`, dir=args["rgn2_dir"]))
    run(Cmd(`python run_rgn2.py $(var["input_path"]) $(abspath(args["conda_dir"]))`, dir=args["rgn2_dir"]))
    rgn2_output_dir = joinpath(args["rgn2_dir"], "output/refine_model1/")
    mv(joinpath(rgn2_output_dir, "$(var["input_noext"])_prediction.pdb"), var["output_file"])
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()