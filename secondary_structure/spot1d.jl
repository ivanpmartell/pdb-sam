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
        "--spot1d_dir", "-s"
            help = "Directory containing SPOT-1D repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"

    end
    return parse_args(s)
end

parsed_args = parse_commandline()
out_ext = "spot1d"

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"])
end

function commands(f_path, f_noext, f_out)
    input_ext = "fasta"
    spot1d_input_dir = joinpath(parsed_args["spot1d_dir"], "inputs/")
    spot1d_input_file = joinpath(spot1d_input_dir, "$(f_noext).$(input_ext)")
    spot1d_output_dir = joinpath(parsed_args["spot1d_dir"], "outputs/")
    #Clean input directory to prevent processing of previous inputs
    foreach(rm, filter(endswith(".$(input_ext)"), readdir(spot1d_input_dir,join=true)))
    cp(f_path, spot1d_input_file, force=true)
    run(Cmd(`./run_spot1d.sh`, dir=parsed_args["spot1d_dir"]))
    #Move files from spot1d outputs to output folder once processed. Clean spot1d directory.
    cp(joinpath(spot1d_output_dir, "$(f_noext).$(out_ext)"), f_out)
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, out_ext, commands, parsed_args["skip_error"], "spot1d/")