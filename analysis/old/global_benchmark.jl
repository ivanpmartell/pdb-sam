using ArgParse
using ProgressBars
using BioSequences
using DataFrames
using FASTX

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Input directory. Cluster folders with summary files required"
            required = true
        "--output", "-o"
            help = "Output directory. Benchmark file for each cluster will be saved here. Ignore to use input directory"
        "--extension", "-e"
            help = "Alignment file extension. Default is .toolres"
            default = ".toolres"
        "--sov_refine", "-s"
            help = "Path to SOV_refine perl script to produce metrics. Usually called SOV_refine.pl"
            required = true
        "--clean", "-c"
            help = "Delete SOV_refine input files after benchmark is done"
            action = :store_true
    end
    return parse_args(s)
end

function into_tool_dict!(d, t, id, rec)
    if haskey(d, t)
        d[t][id] = rec
    else
        d[t] = Dict(id => rec)
    end
end

function read_tool_results(dir_path)
    tool_results = Dict{String, Dict{String, FASTA.Record}}()
    ids_done = Set()
    for res_path in glob("*.toolres", dir_path)
        tool = first(splitext(basename(res_path)))
        FASTA.Reader(open(res_path)) do reader
            for record in reader
                id, chain, current_tool = split(identifier(record), '_', limit=3)
                current_id = "$(id)_$(chain)"
                if current_tool == "dssp"
                    if !(current_id in ids_done)
                        into_tool_dict!(tool_results, current_tool, current_id, record)
                        push!(ids_done, current_id)
                    end
                end
                into_tool_dict!(tool_results, tool, current_id, record)
            end
        end
    end
    return tool_results
end

function create_benchmark_files(tool_res, out_dir)
    #Separate into dssp and non-dssp records (make sure order is maintained)
    #Make them into pred and ref .fa files
    ids = collect(keys(tool_res["dssp"]))
    mkpath(out_dir)
    for tool in keys(tool_res)
        tool_out = joinpath(out_dir, "$(tool).pred.fa")
        if tool == "dssp"
            tool_out = joinpath(out_dir, "$(tool).ref.fa")
        end
        if !isfile(tool_out)
            for id in ids
                FASTA.Writer(open(tool_out, "a")) do writer
                    write(writer, tool_res[tool][id])
                end
            end
        end
    end
end

function calculate_metrics(bmk_dir)
    #Find .pred.fa files inside benchmark folder (assume .ref.fa with same name after -)
    ref_path = joinpath(bmk_dir, "dssp.ref.fa")
    for pred_path in glob("*.pred.fa", bmk_dir)
        f_basename = first(split(basename(pred_path), '.'))
        #Run sov_refine to obtain metrics
        out_file = joinpath(bmk_dir, "$(f_basename).metrics")
        if !isfile(out_file)
            try
                write(out_file, read(`$(parsed_args["sov_refine"]) $(ref_path) $(pred_path)`))
            catch e
                if isa(e, LoadError)
                    println("Error getting metrics for $(basename(root))")
                    continue
                end
            end
        end
        #Clean SOV_refine input files
        if parsed_args["clean"]
            rm(pred_path)
        end
    end
    if parsed_args["clean"]
        rm(ref_path)
    end
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    all_out_path = joinpath(root, "Clusters.bmk")
    for dir in dirs
        if startswith(dir, "Cluster")
            cluster_dir = joinpath(root, dir)
            f_path_no_root_folder = lstrip(replace(cluster_dir, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_dir = joinpath(parsed_args["output"], f_path_no_root_folder)
            f_out_path = joinpath(f_out_dir, "$(dir).bmk")
            bmk_out_dir = joinpath(f_out_dir, "global_benchmark")
            tool_res = read_tool_results(cluster_dir)
            #Make files for input to sov_refine inside benchmark folder
            try
                create_benchmark_files(tool_res, bmk_out_dir)
            catch e
                println("Error on $(dir).")
                continue
            end
            ##Per tool and mutation global benchmark inside benchmark folder
            calculate_metrics(bmk_out_dir)
        end
    end
end