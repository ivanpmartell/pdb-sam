using ArgParse
using FASTX
using BioSequences
include("../common.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Directory with clusters containing SSPro8 predictions"
            required = true
        "--extension", "-e"
            help = "SSPro8 output files' extension. Default .ss8"
            default = ".ss8"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

function readsspro8(pred_path)
    open(pred_path, "r") do reader
        readline(reader) # ignore first line
        seq = readline(reader)
        pred = readline(reader)
        return seq, pred
    end
end

input_conditions(a,f) = return has_extension(f, a["extension"]) && last(splitdir(dirname(f))) == "sspro8"

function preprocess!(args, var)
    input_dir_out_preprocess!(var, var["input_noext"]; fext="sspfa")
end

function commands(args, var)
    seq, pred_str = readsspro8(var["input_path"])
    FASTA.Writer(open(var["output_file"], "w")) do writer
        write(writer, FASTA.Record("$(var["input_noext"])_sspro8", LongCharSeq(pred_str)))
    end
end

function main()::Cint
    parsed_args = parse_commandline()
    work_on_multiple(parsed_args, commands, 'f'; in_conditions=input_conditions, preprocess=preprocess!)
    return 0
end

main()