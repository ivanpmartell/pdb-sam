using ArgParse

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
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
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
for (root, dirs, files) in walkdir(parsed_args["input"])
    for f in files
        if endswith(f, parsed_args["extension"])
            f_path = joinpath(root,f)
            f_noext = splitext(f)[1]
            spot1d_input_dir = joinpath(parsed_args["spot1d_dir"], "inputs/")
            spot1d_input_file = joinpath(spot1d_input_dir, "$(f_noext).fasta")
            cp(f_path, spot1d_input_file)
            run(Cmd(`./run_spot1d.sh`, dir=parsed_args["spot1d_dir"]))
            #Move files from spot1d outputs to output folder once processed. Clean spot1d directory.
            spot1d_output_dir = joinpath(parsed_args["spot1d_dir"], "outputs/")
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
            f_out_path = joinpath(f_out_path, "spot1d/")
            mkpath(f_out_path)
            mv(joinpath(spot1d_output_dir, "$(f_noext).spot1d"), f_out_path)
            rm(spot1d_input_file)
        end
    end
end