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
        "--raptorx_dir", "-r"
            help = "Directory containing RaptorX Predict Property repository"
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
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
            f_out_dir = joinpath(f_out_path, "raptorx/")
            if !isfile(joinpath(f_out_dir, "$(f_noext).ss8"))
                println("Working on $(f_path)")
                try
                    mkpath(f_out_dir)
                    raptorx = joinpath(parsed_args["raptorx_dir"], "Predict_Property.sh")
                    run(`$(raptorx) -i $(f_path) -o $(f_out_dir)`)
                catch e
                    println("Error on $(f_path)")
                    continue
                end
            end
        end
    end
end