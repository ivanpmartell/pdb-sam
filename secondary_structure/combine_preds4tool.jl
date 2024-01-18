#For each tool prediction in a cluster, combine all sspfa and ssfa files into one
#TODO
using ArgParse
using ProgressBars
using FASTX

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Directory with clusters containing normalized 2d structure and predictions"
            required = true
        "--dssp_extension", "-d"
            help = "DSSP normalized output files' extension. Default .ssfa"
            default = ".ssfa"
        "--pred_extension", "-p"
            help = "SSP normalized output files' extension. Default .sspfa"
            default = ".sspfa"
        "--output", "-o"
            help = "Output directory where the agglomerated fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for dir in dirs
        if startswith(dir, "Cluster")
            cluster_dir = joinpath(root, dir)
            dssp_res_files = Set{String}()
            pred_res_files = Dict{String, Set{String}}()
            cluster_tool_dirs = Dict{String, String}()
            for (clstr_root, clstr_dirs, clstr_files) in walkdir(cluster_dir)
                for f in clstr_files
                    f_noext, f_ext = splitext(f)
                    if f_ext == parsed_args["dssp_extension"]
                        f_path = joinpath(clstr_root, f)
                        push!(dssp_res_files, f_path)
                    elseif f_ext == parsed_args["pred_extension"]
                        f_path = joinpath(clstr_root, f)
                        tool = last(splitdir(clstr_root))
                        try
                            push!(pred_res_files[tool], f_path)
                        catch e
                            if isa(e, KeyError)
                                pred_res_files[tool] = Set([f_path])
                            else
                                print("Unexpected error occured: $e")
                                exit(1)
                            end
                        end
                        
                    end
                end
                for clstr_dir in clstr_dirs
                    cluster_tool_dirs[clstr_dir] = joinpath(clstr_root, clstr_dir)
                end
            end
            for (tool, tool_dir) in cluster_tool_dirs
                if tool in keys(pred_res_files)
                    f_path_no_root_folder = lstrip(replace(cluster_dir, Regex("^$(parsed_args["input"])")=>""), '/')
                    f_out_dir = joinpath(parsed_args["output"], f_path_no_root_folder)
                    f_out_path = joinpath(f_out_dir, "$(tool).toolres")
                    if !isfile(f_out_path)
                        mkpath(f_out_dir)
                        for f_path in dssp_res_files
                            FASTA.Reader(open(f_path, "r")) do reader
                                records = collect(reader)
                                for rec in records
                                    FASTA.Writer(open(f_out_path, "a")) do writer
                                        write(writer, rec)
                                    end
                                end
                            end
                        end
                        for f_path in pred_res_files[tool]
                            FASTA.Reader(open(f_path, "r")) do reader
                                records = collect(reader)
                                for rec in records
                                    FASTA.Writer(open(f_out_path, "a")) do writer
                                        write(writer, rec)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
