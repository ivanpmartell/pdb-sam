using ArgParse
using ProgressBars
using FASTX

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Directory with clusters containing normalized 2d structure and predictions"
            required = true
        "--dssp_extension", "-d"
            help = "DSSP normalized output files' extension. Default .ssfa"
        "--pred_extension", "-p"
            help = "SSP normalized output files' extension. Default .sspfa"
        "--output", "-o"
            help = "Output directory where the agglomerated fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()
if isnothing(parsed_args["output"])
    parsed_args["output"] = parsed_args["input"]
end
if isnothing(parsed_args["dssp_extension"])
    parsed_args["dssp_extension"] = ".ssfa"
end
if isnothing(parsed_args["pred_extension"])
    parsed_args["pred_extension"] = ".sspfa"
end

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for dir in dirs
        if startswith(dir, "Cluster")
            cluster_dir = joinpath(root, dir)
            f_path_no_root_folder = lstrip(replace(cluster_dir, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_dir = joinpath(parsed_args["output"], f_path_no_root_folder)
            f_out_path = joinpath(f_out_dir, "$(dir).res")
            if !isfile(f_out_path)
                mkpath(f_out_dir)
                for (clstr_root, clstr_dirs, clstr_files) in walkdir(cluster_dir)
                    for f in clstr_files
                        f_noext, f_ext = splitext(f)
                        if f_ext in [parsed_args["dssp_extension"], parsed_args["pred_extension"]]
                            f_path = joinpath(clstr_root, f)
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
