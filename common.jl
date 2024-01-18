using Dates

function work_on_io_files(input, output, in_conditions, out_ext, run_cmds, skip_error=false, out_dir="", runtime_unit="min")
    start_time = now()
    if isnothing(output)
        output = input
    end
    abs_input = abspath(input)
    abs_output = abspath(output)
    counter = 0
    error_counter = 0
    print_log(start_time, "Working on $(abs_input)")
    for (root, dirs, files) in walkdir(abs_input)
        for f in files
            if in_conditions(f, root)
                iter_start_time = now()
                counter += 1
                f_path = joinpath(root, f)
                f_noext = first(split(f, "."))
                f_out = calculate_output_dir(abs_input, abs_output, f_path, "$(f_noext).$(out_ext)", out_dir)
                error_path = "$(f_out).err"
                if !isfile(f_out)
                    if skip_error && isfile(error_path)
                        print_runtime(iter_start_time, runtime_unit, "Skipping $(f_path)")
                        println("INFO: Delete error (.err) file to process the file at")
                        println(error_path)
                        continue
                    end
                    print_log(start_time, "Working on $(f_path)")
                    try
                        mkpath(dirname(f_out))
                        run_cmds(f_path, f_noext, f_out)
                        print_runtime(iter_start_time, runtime_unit, "Finished on $(f_path)")
                    catch e
                        print_runtime(iter_start_time, runtime_unit, "ERROR: Read more at $(error_path)")
                        open(error_path, "a") do error_file
                            println(error_file, e)
                        end
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

function work_at_base_path(input, output, in_conditions, out_dir, out_filename, out_ext, run_cmds, skip_error=false, runtime_unit="min")
    start_time = now()
    if isnothing(output)
        output = input
    end
    abs_input = abspath(input)
    abs_output = abspath(output)
    print_log(start_time, "Working on $(abs_input)")
    counter = 0
    error_counter = 0
    for (root, dirs, files) in walkdir(abs_input)
        for f in files
            if in_conditions(f, root)
                iter_start_time = now()
                counter += 1
                error_path = "$(f_path).err"
                if skip_error && isfile(error_path)
                    print_runtime(iter_start_time, runtime_unit, "Skipping $(f_path)")
                    println("INFO: Delete error (.err) file to process the file at")
                    println(error_path)
                    continue
                end
                f_path = joinpath(root, f)
                print_log(start_time, "Working on $(f_path)")

                f_path_split = splitpath(f_path)
                f_name = last(f_path_split)
                f_noext = first(split(f_name, "."))
                cluster_dir_index = findlast(x -> startswith(x, out_dir), f_path_split)
                cluster_dir_name = f_path_split[cluster_dir_index]
                cluster_path = joinpaths(f_path_split[1:cluster_dir_index])
                cluster_path_dummy = joinpath(cluster_path, "dummy.file")
                f_out = ""
                if out_filename == "input_filename"
                    f_out = calculate_output_dir(abs_input, abs_output, cluster_path_dummy, "$(f_noext).$(out_ext)")
                elseif out_filename == "directory_name"
                    f_out = calculate_output_dir(abs_input, abs_output, cluster_path_dummy, "$(cluster_dir_name).$(out_ext)")
                else
                    throw(ArgumentError("Output filename had an incorrect format"))
                end
                try
                    run_cmds(f_path, f_out)
                    print_runtime(iter_start_time, runtime_unit, "Finished on $(f_path)")
                catch e
                    print_runtime(iter_start_time, runtime_unit, "Error on $(f_path)")
                    open(error_path, "w") do error_file
                        println(error_file, e)
                    end
                    error_counter += 1
                    continue
                end
            end
        end
    end
    print_runtime(start_time, runtime_unit, "Finished on $(abs_input)")
    println("$(error_counter) errors found in $(counter) files")
end

function work_on_input_files(input, in_conditions, run_cmds, skip_error=false, runtime_unit="min")
    start_time = now()
    abs_input = abspath(input)
    print_log(start_time, "Working on $(abs_input)")
    counter = 0
    error_counter = 0
    for (root, dirs, files) in walkdir(abs_input)
        for f in files
            if in_conditions(f, root)
                iter_start_time = now()
                counter += 1
                f_path = joinpath(root, f)
                error_path = "$(f_path).err"
                if skip_error && isfile(error_path)
                    print_runtime(iter_start_time, runtime_unit, "Skipping $(f_path)")
                    println("INFO: Delete error (.err) file to process the file at")
                    println(error_path)
                    continue
                end
                print_log(start_time, "Working on $(f_path)")
                try
                    run_cmds(f_path)
                    print_runtime(iter_start_time, runtime_unit, "Finished on $(f_path)")
                catch e
                    print_runtime(iter_start_time, runtime_unit, "Error on $(f_path)")
                    open(error_path, "w") do error_file
                        println(error_file, e)
                    end
                    error_counter += 1
                    continue
                end
            end
        end
    end
    print_runtime(start_time, runtime_unit, "Finished on $(abs_input)")
    println("$(error_counter) errors found in $(counter) files")
end

function calculate_output_dir(abs_input, abs_output, f_path, f_out_name, out_dir="")
    f_path_no_root_folder = f_path[length(rstrip(abs_input,'/'))+2:end]
    f_out_path = dirname(joinpath(abs_output, f_path_no_root_folder))
    f_out_dir = joinpath(f_out_path, out_dir)
    return joinpath(f_out_dir, f_out_name)
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
    print_log(end_time, msg)
end

function print_log(time, msg)
    println("$(Dates.format(time, "yyyy-mm-dd HH:MM:SS")) $(msg)")
end

function joinpaths(paths::Union{Tuple{AbstractString}, AbstractVector{AbstractString}})::String
    if length(paths) == 2
        return joinpath(paths[1], paths[2])
    elseif length(paths) == 1
        return first(paths)
    end
    joinpath(joinpaths(paths[1:end-1]), last(paths))
end