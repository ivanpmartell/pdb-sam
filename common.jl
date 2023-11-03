using Dates

function work_on_files(input, output, in_conditions, out_dir, out_ext, run_cmds)
    if isnothing(output)
        output = input
    end
    abs_input = abspath(input)
    abs_output = abspath(output)
    for (root, dirs, files) in walkdir(abs_input)
        for f in files
            if in_conditions(f, root)
                start_time = now()
                f_path = joinpath(root, f)
                f_noext = first(splitext(f))
                f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(abs_input)")=>""), '/')
                f_out_path = dirname(joinpath(abs_output, f_path_no_root_folder))
                f_out_dir = joinpath(f_out_path, out_dir)
                f_out = joinpath(f_out_dir, "$(f_noext).$(out_ext)")
                if !isfile("$(f_out)")
                    println("$(Dates.format(start_time, "yyyy-mm-dd HH:MM:SS")) Working on $(f_path)")
                    try
                        mkpath(f_out_dir)
                        run_cmds(f_path, f_noext, f_out)
                        end_time = now()
                        time_taken = Dates.value(end_time - start_time) / 60000
                        println("Runtime: $(round(time_taken, digits=3)) minutes")
                        println("$(Dates.format(end_time, "yyyy-mm-dd HH:MM:SS")) Finished $(f_path)")
                    catch e
                        end_time = now()
                        println("$(Dates.format(end_time, "yyyy-mm-dd HH:MM:SS")) Error on $(f_path)")
                        println(e)
                        continue
                    end
                end
            end
        end
    end
end

function look_at_files(input, in_conditions, run_cmds)
    start_time = now()
    abs_input = abspath(input)
    println("$(Dates.format(start_time, "yyyy-mm-dd HH:MM:SS")) Working on $(abs_input)")
    counter = 0
    error_counter = 0
    for (root, dirs, files) in walkdir(abs_input)
        for f in files
            if in_conditions(f, root)
                f_path = joinpath(root, f)
                counter += 1
                try
                    run_cmds(f_path)
                catch e
                    error_time = now()
                    println("$(Dates.format(error_time, "yyyy-mm-dd HH:MM:SS")) Error on $(f_path)")
                    println(e)
                    error_counter += 1
                    continue
                end
            end
        end
    end
    end_time = now()
    time_taken = Dates.value(end_time - start_time) / 60000
    println("Runtime: $(round(time_taken, digits=3)) minutes")
    println("$(Dates.format(end_time, "yyyy-mm-dd HH:MM:SS")) Finished $(abs_input)")
    println("$(error_counter) errors found in $(counter) files")
end
