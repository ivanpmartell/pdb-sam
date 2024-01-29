#For each record in a cluster, combine all sspfa and ssfa files into one
using ArgParse
using FASTX
include("../common.jl")

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

input_conditions(a,f) = has_extension(f, a["dssp_extension"]) || has_extension(f, a["pred_extension"])

function preprocess!(args, var)
    f_path_split = splitpath(var["input_path"])
    cluster_dir_index = findlast(x -> startswith(x, "Cluster"), f_path_split)
    cluster_path = joinpaths(f_path_split[1:cluster_dir_index])
    var["output_basename"] = f_path_split[cluster_dir_index]
    input_dir_out_preprocess!(var, var["input_noext"], "rec.res"; basedir=cluster_path)
end

function commands(args, var)
    FASTA.Reader(open(var["input_path"], "r")) do reader
        records = collect(reader)
        for rec in records
            FASTA.Writer(open(var["output_file"], "a")) do writer
                write(writer, rec)
            end
        end
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()