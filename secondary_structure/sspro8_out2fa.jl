using ArgParse
using FASTX
using BioSequences

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

parsed_args = parse_commandline()

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"]) && last(splitdir(in_path)) == "sspro8"
end

function commands(f_path, f_noext, f_out)
    seq, pred_str = readsspro8(f_path)
    FASTA.Writer(open(f_out, "w")) do writer
        write(writer, FASTA.Record("$(f_noext)_sspro8", LongCharSeq(pred_str)))
    end
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "sspfa", commands, parsed_args["skip_error"])