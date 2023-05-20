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
        "--sspro8_dir", "-s"
            help = "Directory containing SSPro8 repository"
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
            f_out_path = joinpath(f_out_path, "sspro8/$(f_noext)")
            if !isfile("$(f_out_path).ss8")
                println("Working on $(f_path)")
                try
                    mkpath(dirname(f_out_path))
                    sspro8 = joinpath(parsed_args["sspro8_dir"], "bin/run_scratch1d_predictors.sh")
                    run(`$(sspro8) --input_fasta $(f_path) --output_prefix $(f_out_path)`)
                catch e
                    println("Error on $(f_path)")
                    continue
                end
            end
        end
    end
end