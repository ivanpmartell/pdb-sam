using ArgParse
using Glob
using ProgressBars
using BioSequences
using DataFrames
using FASTX
using Statistics

ACCURACY_STR = "Accuracy"
SOV99_STR = "SOV_99"
SOVREF_STR = "SOV_refine"

struct ClassScore
    class::String
    score::Float32
end

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Input directory. Cluster folders with summary files required"
            required = true
        "--output", "-o"
            help = "Output directory. Benchmark file for each cluster will be saved here. Ignore to use input directory"
        "--extension", "-e"
            help = "Alignment file extension. Default is .metrics"
            default = ".metrics"
        "--type", "-t"
            help = "Type of benchmark to summarize. Options [local, global]"
            required = true
    end
    return parse_args(s)
end

function read_metrics!(tool_dict, current_tool, f_path)
    open(f_path, "r") do reader
        while !eof(reader)
            line = readline(reader)
            line_split = split(line, '\t')
            if length(line_split) > 2
                try
                    push!(tool_dict[current_tool][line_split[1]], ClassScore(line_split[2], parse(Float32, line_split[3])))
                catch e
                    try
                        tool_dict[current_tool][line_split[1]] = [ClassScore(line_split[2], parse(Float32, line_split[3]))]
                    catch err
                        tool_dict[current_tool] = Dict(line_split[1] => [ClassScore(line_split[2], parse(Float32, line_split[3]))])
                    end
                end
            else
                try
                    push!(tool_dict[current_tool][line_split[1]], parse(Float32, line_split[2]))
                catch e
                    try
                        tool_dict[current_tool][line_split[1]] = [parse(Float32, line_split[2])]
                    catch err
                        tool_dict[current_tool] = Dict(line_split[1] => [parse(Float32, line_split[2])])
                    end
                end
            end
        end
    end
end

function agglomerate_metrics!(overall_dict, cluster_dict)
    metrics = [ACCURACY_STR, SOV99_STR, SOVREF_STR]
    for (tool, result) in cluster_dict
        for metric in metrics
            try
                current_value = overall_dict[tool][metric]
                overall_dict[tool][metric] = mean(append!(result[metric], [current_value]))
            catch e
                try
                    overall_dict[tool][metric] = mean(result[metric])
                catch err
                    overall_dict[tool] = Dict(metric => mean(result[metric]))
                end
            end
        end
    end
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
if !(parsed_args["type"] in Set(["local", "global"]))
    throw(ErrorException("Incorrect benchmark type"))
end

tool_metrics = Dict{String, Dict{String, Float32}}()
for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for dir in dirs
        if dir == "$(parsed_args["type"])_benchmark"
            cluster_dir = last(split(root, '/'))
            benchmark_dir = joinpath(root, dir)
            f_path_no_root_folder = lstrip(replace(benchmark_dir, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_dir = joinpath(parsed_args["output"], f_path_no_root_folder)
            f_out_path = joinpath(f_out_dir, "$(cluster_dir).bmk")
            cluster_tool_metrics = Dict{String, Dict{String, Vector{Any}}}()
            for f in glob("*$(parsed_args["extension"])", benchmark_dir)
                f_name = basename(f)
                tool = first(split(f_name, '-'))
                #Average all outputs into bmk file for cluster
                read_metrics!(cluster_tool_metrics, tool, f)
                agglomerate_metrics!(tool_metrics, cluster_tool_metrics)
            end
            open(f_out_path, "w") do writer
                println(writer, "tool\t$(ACCURACY_STR)\t$(SOV99_STR)\t$(SOVREF_STR)")
                for (tool, result) in cluster_tool_metrics
                    println(writer, "$(tool)\t$(mean(result[ACCURACY_STR]))\t$(mean(result[SOV99_STR]))\t$(mean(result[SOVREF_STR]))")
                end
            end
        end
    end
end
#All clusters (per tool aggregate) local benchmark f_out_path for everything
all_out_path = joinpath(parsed_args["input"], "Clusters-$(parsed_args["type"]).bmk")
open(all_out_path, "w") do writer
    for (tool, results) in tool_metrics
        for metric in keys(results)
            println(writer, "$(metric) for $(tool): $(results[metric])")
        end
    end
end