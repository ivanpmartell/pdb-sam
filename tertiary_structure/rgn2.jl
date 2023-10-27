#Use rgn2 conda evn
using ArgParse
using Dates

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
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
                start_time = now()
                f_path = joinpath(root,f)
                f_noext = splitext(f)[1]
                f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
                f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
                f_out_dir = joinpath(f_out_path, "rgn2/")
                f_out = joinpath(f_out_dir, "$(f_noext).pdb")
                if !isfile("$(f_out)")
                    println("$(Dates.format(start_time, "yyyy-mm-dd HH:MM:SS")) Working on $(f_path)")
                    try
                        aminobert = joinpath(parsed_args["rgn2_dir"], "run_aminobert.py")
                        run(Cmd(`python $(aminobert) $(f_path)`, dir=parsed_args["rgn2_dir"]))
                        rgn2 = joinpath(parsed_args["rgn2_dir"], "run_rgn2.py")
                        run(Cmd(`python $(rgn2) $(f_path)`, dir=parsed_args["rgn2_dir"]))
                        #Move output to our destination folder
                        mkpath(f_out_dir)
                        rgn2_output_dir = joinpath(parsed_args["rgn2_dir"], "output/refine_model1/")
                        mv(joinpath(rgn2_output_dir, "$(f_noext)_prediction.pdb"), f_out)
                        end_time = now()
                        time_taken = Dates.value(end_time - start_time) / 60000
                        println("Runtime: $(round(time_taken, digits=3)) minutes")
                    catch e
                        end_time = now()
                        println("$(Dates.format(end_time, "yyyy-mm-dd HH:MM:SS")) Error on $(f_path)")
                        continue
                    end
                end
            end
        end
    end
end