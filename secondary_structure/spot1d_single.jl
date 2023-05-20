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
        "--spot1d_single_dir", "-s"
            help = "Directory containing SPOT-1D-Single repository"
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
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
            f_out_dir = joinpath(f_out_path, "spot1d_single/")
            if !isfile(joinpath(f_out_dir, "$(f_noext).csv"))
                println("Working on $(f_path)")
                try
                    filelist_path = "tmp_s1ds_filelist.txt"
                    abs_filelist_path = joinpath(pwd(), filelist_path)
                    create_filelist(f_path, filelist_path)
                    mkpath(f_out_dir)
                    abs_f_out_dir = f_out_dir
                    if !startswith(f_out_dir, '/')
                        abs_f_out_dir = joinpath(pwd(), f_out_dir)
                    end
                    run(Cmd(`python spot1d_single.py --file_list $(abs_filelist_path) --save_path $(abs_f_out_dir) --device cpu`, dir=parsed_args["spot1d_single_dir"]))
                    rm(abs_filelist_path)
                catch e
                    println("Error on $(f_path)")
                    continue
                end
            end
        end
    end
end