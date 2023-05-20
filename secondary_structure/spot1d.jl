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
            spot1d_output_dir = joinpath(parsed_args["spot1d_dir"], "outputs/")
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
            f_out_dir = joinpath(f_out_path, "spot1d/")
            f_out = joinpath(f_out_dir, "$(f_noext).spot1d")
            if !isfile("$(f_out)")
                println("Working on $(f_path)")
                try
                    foreach(rm, filter(endswith(".fasta"), readdir(parsed_args["spot1d_dir"],join=true)))
                    cp(f_path, spot1d_input_file, force=true)
                    run(Cmd(`./run_spot1d.sh`, dir=parsed_args["spot1d_dir"]))
                    #Move files from spot1d outputs to output folder once processed. Clean spot1d directory.
                    mkpath(f_out_dir)
                    mv(joinpath(spot1d_output_dir, "$(f_noext).spot1d"), f_out)
                    rm(spot1d_input_file)
                catch e
                    println("Error on $(f_path)")
                    continue
                end
            end
        end
    end
end