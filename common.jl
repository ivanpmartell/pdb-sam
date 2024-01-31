using Dates

function monitor_process(script_args, commands; input_conditions=default_input_condition, initialize=default_var_procedure, preprocess=default_var_procedure, finalize=default_var_procedure, var=Dict(), input_type='f', nested=false, skip_error=false, runtime_unit="min")
    start_time = now()
    initialize(script_args, var) #Define abs_input, abs_output
    print_log(start_time, "Starting work on $(var["abs_input"])")
    counter = 0
    error_counter = 0
    for input in process_input(var["abs_input"], input_type, input_conditions, script_args, nested)
        iter_start_time = now()
        counter += 1
        if length(var["abs_input"]) == 1
            var["input_path"] = input
        else
            var["input_path"] = joinpath(var["abs_input"], input)
        end
        var["input_basename"] = basename(input)
        var["input_noext"] = first(split(var["input_basename"], "."))
        preprocess(script_args, var) #Define output_file, abs_output_dir, error_file
        if !isfile(var["output_file"])
            if skip_error && isfile(var["error_file"])
                print_runtime(iter_start_time, runtime_unit, "Skipping $(input)")
                println("INFO: Delete error (.err) file to process skipped file")
                continue
            end
            print_log(start_time, "Working on $(input)")
            try
                mkpath(var["abs_output_dir"])
                commands(script_args, var)
                print_runtime(iter_start_time, runtime_unit, "Finished on $(input)")
            catch e
                print_runtime(iter_start_time, runtime_unit, "ERROR: Read more at $(var["error_file"])")
                open(var["error_file"], "a") do error_file
                    println(error_file, e)
                end
                error_counter += 1
                continue
            end
        end
    end
    finalize(script_args, var)
    if counter > 1
        print_runtime(start_time, runtime_unit, "Finished on $(var["abs_input"])")
        println("$(error_counter) errors found in $(counter) files")
    end
end

function work_on_single(script_args, run_cmds; in_conditions=default_input_condition, initialize=default_var_procedure, preprocess=default_var_procedure, finalize=default_var_procedure, runtime_unit="min")
    default_output_arg!(script_args)
    var = Dict()
    var["abs_input"], var["abs_output"] = get_abspaths(script_args["input"], script_args["output"])
    var["output_file"] = var["abs_output"]
    var["abs_output_dir"] = dirname(var["abs_output"])
    monitor_process(script_args, run_cmds; input_conditions=in_conditions, initialize=initialize, preprocess=preprocess, finalize=finalize, var=var, skip_error=script_args["skip_error"], runtime_unit=runtime_unit)
end

function work_on_multiple(script_args, run_cmds, input_type; in_conditions=default_input_condition, initialize=default_var_procedure, preprocess=default_var_procedure, finalize=default_var_procedure, runtime_unit="min", nested=true)
    default_output_arg!(script_args)
    var = Dict()
    var["abs_input"], var["abs_output"] = no_output_equals_input(script_args["input"], script_args["output"])
    if !isdir(var["abs_input"])
        throw(ErrorException("Input is not a directory"))
    end
    monitor_process(script_args, run_cmds; input_conditions=in_conditions, initialize=initialize, preprocess=preprocess, finalize=finalize, var=var, input_type=input_type, nested=nested, skip_error=script_args["skip_error"], runtime_unit=runtime_unit)
end

function default_output_arg!(parsed_arguments)
    try
        parsed_arguments["output"]
    catch KeyError
        parsed_arguments["output"] = ""
    end
end

function keep_input_dir_structure(abs_input, abs_output, abs_directory, out_dir)
    abs_directory_no_root_folder = abs_directory[length(rstrip(abs_input,'/'))+2:end]
    f_out_path = joinpath(abs_output, abs_directory_no_root_folder)
    f_out_dir = joinpath(f_out_path, out_dir)
    return f_out_dir
end

function print_runtime(start_time, unit, msg)
    end_time = now()
    if unit == "min"
        time_taken = Dates.value(end_time - start_time) / 60000
        println("Runtime: $(round(time_taken, digits=3)) minutes")
    elseif unit == "hour"
        time_taken = Dates.value(end_time - start_time) / 3600000
        println("Runtime: $(round(time_taken, digits=3)) hours")
    elseif unit == "sec"
        time_taken = Dates.value(end_time - start_time) / 1000
        println("Runtime: $(round(time_taken, digits=3)) seconds")
    else
        time_taken = Dates.value(end_time - start_time)
        println("Runtime: $(round(time_taken, digits=3)) ms")
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

function process_input(input, input_type, input_conditions, script_args, nested)
    if isfile(input) || isURL(input)
        return process_str_input(input, input_conditions, script_args)
    elseif isdir(input)
        if input_type == 'f'
            return process_files(input, input_conditions, script_args, nested)
        elseif input_type == 'd'
            return process_directories(input, input_conditions, script_args, nested)
        end
    else
        throw(ErrorException("Input not found"))
    end
end

function process_str_input(input, input_conditions, script_args)
    if input_conditions(script_args, input)
        return [input]
    else
        throw(ErrorException("Input does not meet conditions"))
    end
end

function process_files(input_dir, input_conditions, script_args, nested)
    files = Vector{String}()
    if nested
        for (root, dirs, fls) in walkdir(input_dir)
            for f in fls
                f_path = joinpath(root, f)
                if input_conditions(script_args, f_path)
                    push!(files, get_relpath(input_dir, f_path))
                end
            end
        end
    else
        for f in readdir(input_dir)
            f_path = joinpath(input_dir, f)
            if isfile(f_path)
                if input_conditions(script_args, f_path)
                    push!(files, get_relpath(input_dir, f_path))
                end
            end
        end
    end
    return files
end

function process_directories(input_dir, input_conditions, script_args, nested)
    directories = Vector{String}()
    if nested
        for (root, dirs, files) in walkdir(input_dir)
            for dir in dirs
                dir_path = joinpath(root, dir)
                if input_conditions(script_args, dir_path)
                    push!(directories, get_relpath(input_dir, dir_path))
                end
            end
        end
    else
        for dir in readdir(input_dir)
            dir_path = joinpath(input_dir, dir)
            if isdir(dir_path)
                if input_conditions(script_args, dir_path)
                    push!(directories, get_relpath(input_dir, dir_path))
                end
            end
        end
    end
    return directories
end

function basename_ext(path)
    f = basename(path)
    f_name, f_ext= split(f, '.', limit=2)
    return f_name, ".$(f_ext)"
end

function remove_ext(path)
    return first(split(f, '.', limit=2))
end

function has_extension(f::AbstractString, ext::AbstractString)
    f_name, f_ext = basename_ext(f)
    return f_ext == ext
end

function has_extension(f::AbstractString, ext::Vector{AbstractString})
    f_name, f_ext = basename_ext(f)
    return f_ext in ext
end

function modify(vec, cmd, args)
    vec2 = typeof(vec)(undef, length(vec))
    for i in eachindex(vec)
        vec2[i] = cmd(vec[i], args)
    end
    return vec2
end

function modify!(vec, cmd, args)
    for i in eachindex(vec)
        vec[i] = cmd(vec[i], args)
    end
end

function ensure_new_file(f)
    if !(isfile(f))
        mkpath(dirname(f))
        touch(f)
    else
        rm(f)
        ensure_new_file(f)
    end
end

function get_abspaths(input, output)
    abs_input = get_abspath(input)
    abs_output = get_abspath(output)
    return abs_input, abs_output
end

function get_abspath(path)
    if isURL(path)
        return path
    end
    abs_input = ""
    if !isnothing(path) && !isempty(path)
        abs_input = abspath(path)
    end
    return abs_input
end

function get_relpath(dir, path)
    return lstrip(path[length(dir)+1:end], '/')
end

function no_output_equals_input(input, output)
    if isnothing(output)
        output = input
    end
    return get_abspaths(input, output)
end

function input_dir_out_preprocess!(var, fname; fext="", cdir="", basedir="")
    if isempty(basedir)
        basedir = dirname(var["input_path"])
    end
    output_basename = "$(fname)"
    if !isempty(fext)
        output_basename = "$(fname).$(fext)"
    end
    var["abs_output_dir"] = keep_input_dir_structure(var["abs_input"], var["abs_output"], basedir, cdir)
    var["output_file"] = joinpath(var["abs_output_dir"], output_basename)
    var["error_file"] = "$(var["output_file"]).err"
end

function isURL(url)
    return occursin(r"^[a-zA-Z][a-zA-Z\d+\-.]*:", url)
end

default_input_condition(args::Dict{Any, Any}, path::String) = return true
default_input_condition(args::Dict{String, Any}, path::String) = return true
default_var_procedure(args::Dict{Any, Any}, vars::Dict{Any, Any}) = return true
default_var_procedure(args::Dict{String, Any}, vars::Dict{Any, Any}) = return true