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
            help = "Extension for input files. Usually '.pdb'"
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
            start_time = now()
            f_path = joinpath(root,f)
            f_noext = splitext(f)[1]
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_path = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
            f_out = joinpath(f_out_path, "$(f_noext).dssp")
            if !isfile("$(f_out)")
                println("$(Dates.format(start_time, "yyyy-mm-dd HH:MM:SS")) Working on $(f_path)")
                try
                    mkpath(f_out_path)
                    run(`mkdssp $(f_path) $(f_out)`)
                    end_time = now()
                    time_taken = Dates.value(end_time - start_time) / 1000
                    println("Runtime: $(round(time_taken, digits=3)) seconds")
                catch e
                    end_time = now()
                    println("$(Dates.format(end_time, "yyyy-mm-dd HH:MM:SS")) Error on $(f_path)")
                    continue
                end
            end
        end
    end
end