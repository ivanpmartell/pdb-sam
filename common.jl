using Dates
using ProgressBars

function monitor_process(script_args, commands; input_conditions=default_input_condition, initialize=default_var_procedure, preprocess=default_var_procedure, postprocess=default_var_procedure, finalize=default_var_procedure, var=Dict(), input_type='f', nested=false, skip_error=false, runtime_unit="min")
    start_time = now()
    initialize(script_args, var) #Define abs_input, abs_output, log_file
    print_log(var, "Starting work on $(var["abs_input"])"; time=start_time)
    counter = 0
    error_counter = 0
    input_files = process_input(var["abs_input"], input_type; input_conditions=input_conditions, script_args=script_args, nested=nested)
    print_runtime(var, start_time, "sec", "Found $(length(input_files)) files that satisfy input conditions")
    for input in ProgressBar(input_files)
        iter_start_time = now()
        counter += 1
        var["input_path"] = joinpath(var["abs_input"], input)
        if !isfile(var["input_path"])
            var["input_path"] = input
        end
        var["abs_input_dir"] = dirname(var["input_path"])
        var["input_basename"] = basename(input)
        var["input_noext"] = remove_ext(var["input_basename"])
        preprocess(script_args, var) #Define output_files, error_files, abs_output_dir
        for output_file in var["output_files"]
            var["output_file"] = output_file
            var["error_file"] = var["error_files"][output_file]
            if !isfile(output_file)
                if skip_error && isfile(var["error_file"])
                    print_runtime(var, iter_start_time, runtime_unit, "Skipping $(input)")
                    print_log(var, "INFO: Delete error (.err) file to process skipped file")
                    continue
                end
                print_log(var, "Working on $(input)"; time=iter_start_time)
                try
                    if !isempty(var["output_file"])
                        mkpath(var["abs_output_dir"])
                    end
                    commands(script_args, var)
                    print_runtime(var, iter_start_time, runtime_unit, "Finished on $(input)")
                catch e
                    print_runtime(var, iter_start_time, runtime_unit, "ERROR: Read more at $(var["error_file"])")
                    error_msg = sprint(showerror, e)
                    st = sprint((io,v) -> show(io, "text/plain", v), stacktrace(catch_backtrace()))
                    print_msg = "$(error_msg)\n$(st)"
                    write_file(var["error_file"], print_msg)
                    error_counter += 1
                    continue
                end
            else
                print_log(var, "Output already exists on $(output_file)")
            end
        end
        postprocess(script_args, var)
        clean_variables!(var)
    end
    finalize(script_args, var)
    if counter > 1
        print_runtime(var, start_time, runtime_unit, "Finished on $(var["abs_input"])")
        print_log(var, "$(error_counter) errors found in $(counter) files")
    end
end

function work_on_single(script_args, run_cmds; in_conditions=default_input_condition, initialize=log_initialize!, preprocess=default_var_procedure, postprocess=default_var_procedure, finalize=default_var_procedure, runtime_unit="min")
    default_output_arg!(script_args)
    var = Dict()
    var["abs_input"], var["abs_output"] = get_abspaths(script_args["input"], script_args["output"])
    monitor_process(script_args, run_cmds; input_conditions=in_conditions, initialize=initialize, preprocess=preprocess, postprocess=postprocess, finalize=finalize, var=var, skip_error=script_args["skip_error"], runtime_unit=runtime_unit)
end

function work_on_multiple(script_args, run_cmds, input_type; in_conditions=default_input_condition, initialize=log_initialize!, preprocess=default_var_procedure, postprocess=default_var_procedure, finalize=default_var_procedure, runtime_unit="min", nested=true)
    default_output_arg!(script_args)
    var = Dict()
    var["abs_input"], var["abs_output"] = no_output_equals_input(script_args["input"], script_args["output"])
    if !isdir(var["abs_input"])
        throw(ErrorException("Input is not a directory"))
    end
    monitor_process(script_args, run_cmds; input_conditions=in_conditions, initialize=initialize, preprocess=preprocess, postprocess=postprocess, finalize=finalize, var=var, input_type=input_type, nested=nested, skip_error=script_args["skip_error"], runtime_unit=runtime_unit)
end

function default_output_arg!(parsed_arguments)
    if !haskey(parsed_arguments, "output")
        parsed_arguments["output"] = ""
    end
end

function keep_input_dir_structure(abs_input, abs_output, abs_directory, out_dir)
    abs_directory_no_root_folder = abs_directory[length(rstrip(abs_input,'/'))+2:end]
    f_out_path = joinpath(abs_output, abs_directory_no_root_folder)
    f_out_dir = joinpath(f_out_path, out_dir)
    return f_out_dir
end

function print_runtime(var, start_time, unit, msg)
    end_time = now()
    runtime_msg = ""
    if unit == "min"
        time_taken = Dates.value(end_time - start_time) / 60000
        runtime_msg = "Runtime: $(round(time_taken, digits=3)) minutes"
    elseif unit == "hour"
        time_taken = Dates.value(end_time - start_time) / 3600000
        runtime_msg = "Runtime: $(round(time_taken, digits=3)) hours"
    elseif unit == "sec"
        time_taken = Dates.value(end_time - start_time) / 1000
        runtime_msg = "Runtime: $(round(time_taken, digits=3)) seconds"
    else
        time_taken = Dates.value(end_time - start_time)
        runtime_msg = "Runtime: $(round(time_taken, digits=3)) ms"
    end
    print_log(var, msg; time=end_time)
    print_log(var, runtime_msg; time=end_time)
end

function print_log(var, msg; time=now())
    if haskey(var, "log_file")
        log_str = "$(Dates.format(time, "yyyy-mm-dd HH:MM:SS")) $(msg)"
        write_file(var["log_file"], log_str)
    end
end

function joinpaths(paths::Union{Tuple{AbstractString}, AbstractVector{AbstractString}})::String
    if length(paths) == 2
        return joinpath(paths[1], paths[2])
    elseif isone(length(paths))
        return first(paths)
    end
    joinpath(joinpaths(paths[1:end-1]), last(paths))
end

function process_input(input, input_type; input_conditions=default_input_condition, script_args=Dict(), nested=false)
    if isfile(input) || isURL(input)
        return process_str_input(input, input_conditions, script_args)
    elseif isdir(input)
        return walk_directory(input_type, input, input_conditions, script_args, nested)
    else
        throw(ErrorException("Input not found"))
    end
    println("Finished input conditions")
end

function process_str_input(input, input_conditions, script_args)
    if input_conditions(script_args, input)
        return [input]
    else
        throw(ErrorException("Input does not meet conditions"))
    end
end

function walk_directory(input_type, input_dir, input_conditions, script_args, nested)
    inputs = Vector{String}()
    for p in ProgressBar(readdir(input_dir))
        path = joinpath(input_dir, p)
        if isdir(path)
            if input_type == 'd'
                if input_conditions(script_args, path)
                    push!(inputs, get_relpath(input_dir, path))
                end
            end
            if nested
                walk_directory!(inputs, path, input_type, input_conditions, script_args, nested, input_dir)
            end
        else
            if input_type == 'f'
                if input_conditions(script_args, path)
                    push!(inputs, get_relpath(input_dir, path))
                end
            end
        end
    end
    return inputs
end

function walk_directory!(inputs, dir_path, input_type, input_conditions, script_args, nested, input_dir)
    for p in readdir(dir_path)
        path = joinpath(dir_path, p)
        if isdir(path)
            if input_type == 'd'
                if input_conditions(script_args, path)
                    push!(directories, get_relpath(input_dir, path))
                end
            end
            walk_directory!(inputs, path, input_type, input_conditions, script_args, nested, input_dir)
        else
            if input_type == 'f'
                if input_conditions(script_args, path)
                    push!(inputs, get_relpath(input_dir, path))
                end
            end
        end
    end
end

function basename_ext(path)
    f = basename(path)
    f_split = split(f, '.', limit=2)
    if isone(length(f_split))
        return first(f_split), ""
    else
        f_name, f_ext = f_split
        return f_name, ".$(f_ext)"
    end
end

function remove_ext(path)
    return joinpath(dirname(path), first(basename_ext(path)))
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
        output_basename *= "$(fext)"
    end
    var["abs_output_dir"] = keep_input_dir_structure(var["abs_input"], var["abs_output"], basedir, cdir)
    output_file = joinpath(var["abs_output_dir"], output_basename)
    if haskey(var, "output_files")
        push!(var["output_files"], output_file)
    else
        var["output_files"] = [output_file]
    end
    if haskey(var, "error_files")
        var["error_files"][output_file] = "$(output_file).err"
    else
        var["error_files"] = Dict(output_file => "$(output_file).err")
    end
end

function file_preprocess!(var; input_only=false)
    if input_only
        var["output_files"] = [""]
        var["abs_output_dir"] = ""
        var["error_files"] = Dict("" => "$(var["input_path"]).err")
    else
        var["output_files"] = [var["abs_output"]]
        var["abs_output_dir"] = dirname(var["abs_output"])
        var["error_files"] = Dict(var["abs_output"] => "$(var["abs_output"]).err")
    end
end

function log_initialize!(script_args, var)
    var["log_file"] = "$(Dates.format(now(), "yyyymmdd-HHMM_SS")).log"
end

function isURL(url)
    return occursin(r"^[a-zA-Z][a-zA-Z\d+\-.]*:", url)
end

function clean_variables!(var)
    delete!(var, "output_files")
    delete!(var, "error_files")
end

function write_file(file, msg; type="a")
    open(file, type) do f
        println(f, msg)
    end
end

default_input_condition(args::Dict{Any, Any}, path::String) = return true
default_input_condition(args::Dict{String, Any}, path::String) = return true
default_var_procedure(args::Dict{Any, Any}, vars::Dict{Any, Any}) = return true
default_var_procedure(args::Dict{String, Any}, vars::Dict{Any, Any}) = return true