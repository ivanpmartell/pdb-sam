#Use esmfold conda env
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
        "--esmfold_exe", "-s"
            help = "ESMFold executable file. Usually esm-fold"
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
            if startswith(last(splitdir(root)), "Cluster")
                f_path = joinpath(root,f)
                f_noext = splitext(f)[1]
                f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
                f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
                f_out_dir = joinpath(f_out_path, "esmfold/")
                f_out = joinpath(f_out_dir, "$(f_noext).pdb")
                if !isfile("$(f_out)")
                    println("Working on $(f_path)")
                    try
                        mkpath(f_out_dir)
                        run(`$(parsed_args["esmfold_exe"]) -i $(f_path) -o $(f_out_dir) --cpu-offload`)
                        #Rename file output
                        for (root_out, dirs_out, files_out) in walkdir(f_out_dir)
                            for file_out in files_out
                                if startswith(file_out, f_noext)
                                    file_out_path = joinpath(root_out, file_out)
                                    mv(file_out_path, f_out)
                                end
                            end
                        end
                    catch e
                        println("Error on $(f_path)")
                        continue
                    end
                end
            end
        end
    end
end