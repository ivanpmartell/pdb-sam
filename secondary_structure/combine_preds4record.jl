#For each record in a cluster, combine all sspfa and ssfa files into one
using ArgParse
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

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["dssp_extension"]) || endswith(in_file, parsed_args["pred_extension"])
end

function commands(f_path, f_out)
    FASTA.Reader(open(f_path, "r")) do reader
        records = collect(reader)
        for rec in records
            FASTA.Writer(open(f_out, "a")) do writer
                write(writer, rec)
            end
        end
    end
end

work_at_base_path(parsed_args["input"], parsed_args["output"], input_conditions, "Cluster", "input_filename", "recres", commands, parsed_args["skip_error"])