using ArgParse
using DelimitedFiles
using DataFrames
using FASTX
using BioSequences

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--skip_error", "-k"
            help = "Skip files that have previously failed"
            action = :store_true
        "--input", "-i"
            help = "Directory with clusters containing RaptorX predictions"
            required = true
        "--extension", "-e"
            help = "RaptorX output files' extension. Default .ss8"
            default = ".ss8"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"]) && last(splitdir(in_path)) == "raptorx"
end

function commands(f_path, f_noext, f_out)
    delimited = readdlm(f_path, ' ', comments=true)
    predictions = Matrix{Any}(undef, size(delimited, 1), 11)
    for i in axes(delimited, 1)
        predictions[i, :] = filter(!isempty, delimited[i, :])
    end
    pred_df = DataFrame(predictions, ["idx", "aa", "ss8", "pH", "pG", "pI", "pE", "pB", "pT", "pS", "pC"])
    pred_df[!, "ss8"][pred_df[!, "ss8"] .== "L"] .= "C"
    pred_array = pred_df[:, "ss8"]
    pred_str = join(pred_array)
    #Write fasta file with single record id from filename
    FASTA.Writer(open(f_out, "w")) do writer
        write(writer, FASTA.Record("$(f_noext)_raptorx", LongCharSeq(pred_str)))
    end
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "sspfa", commands, parsed_args["skip_error"])