using Dates

function work_on_files(input, output, in_conditions, out_dir, out_ext, run_cmds, runtime_unit)
    if isnothing(output)
        output = input
    end
    abs_input = abspath(input)
    abs_output = abspath(output)
    start_time = now()
    counter = 0
    error_counter = 0
    for (root, dirs, files) in walkdir(abs_input)
        for f in files
            if in_conditions(f, root)
                iter_start_time = now()
                counter += 1
                f_path = joinpath(root, f)
                f_noext = first(split(f, "."))
                f_path_no_root_folder = f_path[length(rstrip(abs_input,'/'))+2:end]
                f_out_path = dirname(joinpath(abs_output, f_path_no_root_folder))
                f_out_dir = joinpath(f_out_path, out_dir)
                f_out = joinpath(f_out_dir, "$(f_noext).$(out_ext)")
                if !isfile("$(f_out)")
                    print_log(start_time, "Working on $(f_path)")
                    try
                        mkpath(f_out_dir)
                        run_cmds(f_path, f_noext, f_out)
                        print_runtime(iter_start_time, runtime_unit, "Finished on $(f_path)")
                    catch e
                        print_runtime(iter_start_time, runtime_unit, "Error on $(f_path)")
                        println(e)
                        error_counter += 1
                        continue
                    end
                end
            end
        end
    end
    print_runtime(start_time, runtime_unit, "Finished on $(abs_input)")
    println("$(error_counter) errors found in $(counter) files")
end

function look_at_files(input, in_conditions, run_cmds, runtime_unit)
    start_time = now()
    abs_input = abspath(input)
    print_log(start_time, "Working on $(abs_input)")
    counter = 0
    error_counter = 0
    for (root, dirs, files) in walkdir(abs_input)
        for f in files
            if in_conditions(f, root)
                iter_start_time = now()
                f_path = joinpath(root, f)
                counter += 1
                try
                    run_cmds(f_path)
                    print_runtime(iter_start_time, runtime_unit, "Finished on $(f_path)")
                catch e
                    print_runtime(iter_start_time, runtime_unit, "Error on $(f_path)")
                    println(e)
                    error_counter += 1
                    continue
                end
            end
        end
    end
    print_runtime(start_time, runtime_unit, "Finished on $(abs_input)")
    println("$(error_counter) errors found in $(counter) files")
end

function print_runtime(start_time, unit, msg)
    end_time = now()
    if unit == "min"
        time_taken = Dates.value(end_time - start_time) / 60000
        println("Runtime: $(round(time_taken, digits=3)) minutes")
    elseif unit == "sec"
        time_taken = Dates.value(end_time - start_time) / 1000
        println("Runtime: $(round(time_taken, digits=3)) seconds")
    else
        time_taken = Dates.value(end_time - start_time) / 3600000
        println("Runtime: $(round(time_taken, digits=3)) hours")
    end
    print_log(iter_end_time, msg)
end

function print_log(time, msg)
    println("$(Dates.format(time, "yyyy-mm-dd HH:MM:SS")) $(msg)")
end

function create_command(executable::AbstractString, args::Vector{AbstractString})
    args = filter(!isempty, args)
    return `$(executable) $(join(args," "))`
end