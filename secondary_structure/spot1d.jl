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
        "--spot1d_dir", "-s"
            help = "Directory containing SPOT-1D repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"

    end
    return parse_args(s)
end

input_conditions(a,f) = return has_extension(f, a["extension"])

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext=".spot1d", cdir="spot1d/")
end

function commands(args, var)
    input_ext = "fasta"
    spot1d_input_dir = joinpath(args["spot1d_dir"], "inputs/")
    spot1d_input_file = joinpath(spot1d_input_dir, "$(var["input_noext"]).$(input_ext)")
    spot1d_output_dir = joinpath(args["spot1d_dir"], "outputs/")
    #Clean input directory to prevent processing of previous inputs
    foreach(rm, filter(has_extension(".$(input_ext)"), readdir(spot1d_input_dir,join=true)))
    cp(var["input_path"], spot1d_input_file, force=true)
    run(Cmd(`./run_spot1d.sh`, dir=args["spot1d_dir"]))
    #Move files from spot1d outputs to output folder once processed. Clean spot1d directory.
    cp(joinpath(spot1d_output_dir, "$(var["input_noext"]).spot1d"), var["output_file"])
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()