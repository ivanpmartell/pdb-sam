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
        "--spot1d_lm_dir", "-s"
            help = "Directory containing SPOT-1D-LM repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"

    end
    return parse_args(s)
end

function create_filelist(current_file_path, filelist_path)
    abs_file_path = current_file_path
    if !startswith(current_file_path, '/')
        abs_file_path = joinpath(pwd(), current_file_path)
    end
    open(filelist_path, "w") do writer
        println(writer, abs_file_path)
    end
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
            spot1d_lm_output_dir = joinpath(parsed_args["spot1d_lm_dir"], "results/")
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
            f_out_dir = joinpath(f_out_path, "spot1d_lm/")
            f_out = joinpath(f_out_dir, "$(f_noext).csv")
            if !isfile("$(f_out)")
                println("Working on $(f_path)")
                try
                    filelist_path = "tmp_s1dlm_filelist.txt"
                    abs_filelist_path = joinpath(pwd(), filelist_path)
                    create_filelist(f_path, filelist_path)
                    run(Cmd(`./run_SPOT-1D-LM.sh $(abs_filelist_path) cpu cpu cpu`, dir=parsed_args["spot1d_lm_dir"]))
                    #Move files from spot1d outputs to output folder once processed. Clean spot1d directory.
                    mkpath(f_out_dir)
                    mv(joinpath(spot1d_lm_output_dir, "$(f_noext).csv"), f_out)
                catch e
                    println("Error on $(f_path)")
                    continue
                end
            end
        end
    end
end