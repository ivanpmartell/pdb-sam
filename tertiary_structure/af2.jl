#Use af2 conda env
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
        "--af2_dir", "-a"
            help = "Directory containing AlphaFold2 repository"
            required = true
        "--output", "-o"
            help = "Output directory. Ignore to write files in input directory"
        "--use_gpu", "-g"
            help = "Use Nvidia GPU. If not selected, use CPU only"
            action = :store_true

    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
cpu_only = ""
if !parsed_args["use_gpu"]
    cpu_only = "--use_gpu=False"
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
                f_out_dir = joinpath(f_out_path, "af2/")
                f_out = joinpath(f_out_dir, "$(f_noext).pdb")
                if !isfile("$(f_out)")
                    println("$(Dates.format(start_time, "yyyy-mm-dd HH:MM:SS")) Working on $(f_path)")
                    try
                        af2 = joinpath(parsed_args["af2_dir"], "docker/run_docker.py")
                        run(`python $(af2) --fasta_paths=$(f_path) $(cpu_only) --max_template_date=2020-05-14`)
                        #Move output to our destination folder
                        mkpath(f_out_dir)
                        af2_output_dir = joinpath("/tmp/", "af_output/")
                        mkpath(af2_output_dir)
                        mv(joinpath(af2_output_dir, "$(f_noext)/ranked_0.pdb"), f_out)
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