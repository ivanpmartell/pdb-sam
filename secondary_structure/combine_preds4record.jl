#For each record in a cluster, combine all sspfa and ssfa files into one
using ArgParse
using ProgressBars
using FASTX

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--input", "-i"
            help = "Directory with clusters containing normalized 2d structure and predictions"
            required = true
        "--record_extension", "-r"
            help = "Record structure file's extension. Default .mmcif"
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
if isnothing(parsed_args["record_extension"])
    parsed_args["record_extension"] = ".mmcif"
end
if isnothing(parsed_args["dssp_extension"])
    parsed_args["dssp_extension"] = ".ssfa"
end
if isnothing(parsed_args["pred_extension"])
    parsed_args["pred_extension"] = ".sspfa"
end

for (root, dirs, files) in ProgressBar(walkdir(parsed_args["input"]))
    for f in files
        if endswith(f, parsed_args["record_extension"])
            f_path = joinpath(root,f)
            f_noext, f_ext = splitext(f)
            f_path_no_root_folder = lstrip(replace(f_path, Regex("^$(parsed_args["input"])")=>""), '/')
            f_out_dir = dirname(joinpath(parsed_args["output"], f_path_no_root_folder))
            f_out_path = joinpath(f_out_dir, "$(f_noext).recres")
            if !isfile(f_out_path)
                mkpath(f_out_dir)
                for (clstr_root, clstr_dirs, clstr_files) in walkdir(root)
                    for clust_f in clstr_files
                        clust_f_noext, clust_f_ext = splitext(clust_f)
                        if clust_f_noext == f_noext
                            if clust_f_ext in [parsed_args["dssp_extension"], parsed_args["pred_extension"]]
                                clust_f_path = joinpath(clstr_root, clust_f)
                                FASTA.Reader(open(clust_f_path, "r")) do reader
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
end