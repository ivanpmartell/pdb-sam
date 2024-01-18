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
            help = "Directory with clusters containing Spot1D predictions"
            required = true
        "--extension", "-e"
            help = "Spot1D output files' extension. Default .spot1d"
            default = ".spot1d"
        "--output", "-o"
            help = "Output directory where the prediction fasta file will be written. Ignore to use input directory"
    end
    return parse_args(s)
end

parsed_args = parse_commandline()

function input_conditions(in_file, in_path)
    return endswith(in_file, parsed_args["extension"]) && last(splitdir(in_path)) == "spot1d"
end

function commands(f_path, f_noext, f_out)
    data, data_header = readdlm(f_path, '\t', header=true)
    data_cols = lowercase.(vec(data_header))
    data_cols[1] = "idx"
    pred_df = DataFrame(data, data_cols)
    pred_array = pred_df[:, "ss8"]
    pred_str = join(pred_array)
    #Write fasta file with single record id from filename
    FASTA.Writer(open(f_out, "w")) do writer
        write(writer, FASTA.Record("$(f_noext)_spot1d", LongCharSeq(pred_str)))
    end
end

work_on_io_files(parsed_args["input"], parsed_args["output"], input_conditions, "sspfa", commands, parsed_args["skip_error"])