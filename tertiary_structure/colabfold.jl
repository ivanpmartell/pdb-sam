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
        "--colabfold_exe", "-c"
            help = "ColabFold executable file. Usually colabfold_batch"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--temp_output", "-t"
            help = "Temporary output directory. Usually somewhere outside your output directory"

    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
mkpath(parsed_args["temp_output"])
for (root, dirs, files) in walkdir(parsed_args["input"])
    for f in files
        if endswith(f, parsed_args["extension"])
            if startswith(last(splitdir(root)), "Cluster")
                start_time = now()
                f_path = joinpath(root,f)
                f_noext = splitext(f)[1]
                f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
                f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
                f_out_dir = joinpath(f_out_path, "colabfold/")
                f_out = joinpath(f_out_dir, "$(f_noext).pdb")
                if !isfile("$(f_out)")
                    println("$(Dates.format(start_time, "yyyy-mm-dd HH:MM:SS")) Working on $(f_path)")
                    try
                        mkpath(f_out_dir)
                        run(`$(parsed_args["colabfold_exe"]) --templates --amber --use-gpu-relax $(f_path) $(parsed_args["temp_output"])`)
                        #Rename file output
                        for (root_out, dirs_out, files_out) in walkdir(parsed_args["temp_output"])
                            for file_out in files_out
                                if startswith(file_out, f_noext)
                                    if occursin("relaxed_rank_001", file_out)
                                        file_out_path = joinpath(root_out, file_out)
                                        mv(file_out_path, f_out)
                                        break
                                    end
                                end
                            end
                        end
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